#include "player/MpvVideoItem.h"

#include <QDebug>
#include <QOpenGLContext>
#include <QOpenGLFramebufferObject>
#include <QOpenGLFunctions>
#include <QQuickWindow>
#include <QQuickOpenGLUtils>

#include <functional>
#include <memory>
#include <utility>

#include <mpv/client.h>
#include <mpv/render.h>
#include <mpv/render_gl.h>

#include "player/MpvClient.h"
#include "player/MpvLib.h"

namespace {

// mpv 的 GL 符号解析回调(GL 线程,当前上下文已就绪)
void *getProcAddress(void *, const char *name) {
    QOpenGLContext *context = QOpenGLContext::currentContext();
    if (!context) return nullptr;
    QByteArray byteName(name);
    return reinterpret_cast<void *>(context->getProcAddress(byteName));
}

void onRenderUpdate(void *that) {
    // mpv 渲染线程回调 → 排队触发 QML 重绘
    emit static_cast<MpvRenderNotifier *>(that)->updateRequested();
}

// QQuickFramebufferObject::Renderer 不是 QObject,不能自己当 connect 的接收者。
// 这个哨兵对象只在渲染线程上存在,专门承接 window.frameSwapped 的直连回调
// (信号由渲染线程在真实 swap 之后发出),从而把"真实上屏时刻"报给 mpv。
class SwapSink : public QObject {
   public:
    explicit SwapSink(std::function<void()> callback) : callback_(std::move(callback)) {}
    void notify() {
        if (callback_) callback_();
    }

   private:
    std::function<void()> callback_;
};

// 渲染器:渲染上下文在 render() 中惰性创建(而非仅在 createFramebufferObject),
// 因为 FBO 的创建时机(窗口首帧)通常早于 mpv client 就绪(起播网络解析),
// 只挂在 FBO 创建点会导致"视频 EOF/黑屏但有声";synchronize 跟踪 client 指针
// 变化(内核重建/关窗置空),render 线程内先释放旧上下文再按新 handle 重建,
// mpv_render_context_free 始终在 GL 上下文当前的渲染线程执行。
//
// 展示时序策略(避免"渲染线程被 mpv 拖住"):
//  - 创建上下文时开 MPV_RENDER_PARAM_ADVANCED_CONTROL,并按契约在每次绘制前调用
//    mpv_render_context_update(),用返回的 MPV_RENDER_UPDATE_FRAME 决定是否真的重绘
//    (没有新帧就保留 FBO 上一帧,不擦不闪)。
//  - render 参数传 MPV_RENDER_PARAM_BLOCK_FOR_TARGET_TIME=0,禁止 mpv 在
//    mpv_render_context_render() 内部阻塞等待"该显示这一帧的时刻"。保持默认时它会把
//    Qt Quick 的渲染线程 sleep 到视频帧节奏上(实测 25fps 源每帧阻塞约 38ms),
//    于是整个播放窗口(控制栏淡出/进度条/弹幕/鼠标)都被量化到视频帧率。
//  - 真实 swap 之后(window.frameSwapped,渲染线程)调用
//    mpv_render_context_report_swap(),把真实上屏时刻回报给 mpv 自行修正音画同步与
//    丢帧判断 —— 这正是禁用上述阻塞等待后官方要求的补偿信号。
class MpvRenderer : public QQuickFramebufferObject::Renderer {
   public:
    explicit MpvRenderer(MpvVideoItem *item) : notifier_(item->notifier()) {}
    ~MpvRenderer() override {
        if (frameSwappedConnection_) QObject::disconnect(frameSwappedConnection_);
        sink_.reset();  // 必须在渲染线程析构(其亲和线程)
        freeRenderContext();
    }

    QOpenGLFramebufferObject *createFramebufferObject(const QSize &size) override {
        // 新 FBO 内容未定义:必须画一帧,不能因"当前没有新视频帧"而跳过。
        forceRender_ = true;
        return new QOpenGLFramebufferObject(size);
    }

    void synchronize(QQuickFramebufferObject *item) override {
        // 主线程 → 渲染线程同步点:抓取最新 client 指针
        auto *videoItem = static_cast<MpvVideoItem *>(item);
        if (videoItem && !window_) {
            // synchronize 期间主线程已阻塞,读取 item 的窗口指针是安全的。
            window_ = videoItem->window();
            if (window_) {
                sink_ = std::make_unique<SwapSink>([this] { reportSwap(); });
                frameSwappedConnection_ = QObject::connect(
                        window_, &QQuickWindow::frameSwapped, sink_.get(),
                        [this] { sink_->notify(); }, Qt::DirectConnection);
            }
        }
        MpvClient *client = videoItem ? videoItem->client() : nullptr;
        auto handle = client ? client->sharedHandle() : std::shared_ptr<mpv_handle>{};
        if (handle != pendingHandle_ || videoItem->clientRevision() != clientRevision_) {
            pendingHandle_ = std::move(handle);
            clientRevision_ = videoItem->clientRevision();
            clientDirty_ = true;
        }
    }

    void render() override {
        MpvLib *lib = MpvLib::instance();
        QOpenGLFramebufferObject *fbo = framebufferObject();

        if (clientDirty_) {
            freeRenderContext();
            renderHandle_ = pendingHandle_;
            createFailed_ = false;
            renderFailed_ = false;
            clientDirty_ = false;
            forceRender_ = true;
        }
        if (!renderContext_ && !createFailed_ && renderHandle_ &&
            lib->available()) {
            mpv_opengl_init_params glInit{};
            glInit.get_proc_address = getProcAddress;
            glInit.get_proc_address_ctx = nullptr;
            int advancedControl = 1;
            mpv_render_param params[] = {
                    {MPV_RENDER_PARAM_API_TYPE,
                     const_cast<char *>(MPV_RENDER_API_TYPE_OPENGL)},
                    {MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, &glInit},
                    {MPV_RENDER_PARAM_ADVANCED_CONTROL, &advancedControl},
                    {MPV_RENDER_PARAM_INVALID, nullptr}};
            const int result = lib->renderContextCreate(&renderContext_, renderHandle_.get(), params);
            if (result < 0) {
                renderContext_ = nullptr;
                createFailed_ = true;
                const QString message = QString::fromUtf8(lib->errorString(result));
                qWarning() << "mpv render context create failed:" << message;
                emit notifier_->failed(clientRevision_, message);
            } else {
                lib->renderContextSetUpdateCallback(renderContext_, onRenderUpdate,
                                                    notifier_.get());
                // ADVANCED_CONTROL 的契约要求:创建后必须尽快调用一次 update(),
                // 否则内核会一直等我们,手柄握手不完成。
                lib->renderContextUpdate(renderContext_);
                forceRender_ = true;
                emit notifier_->initialized(clientRevision_);
            }
        }

        if (renderContext_) {
            // 契约:每次 update 回调后都要调用 update();返回值说明是否真有新帧。
            const quint64 flags = lib->renderContextUpdate(renderContext_);
            const bool newFrame = (flags & MPV_RENDER_UPDATE_FRAME) != 0;
            if ((newFrame || forceRender_) && fbo && lib->renderContextRender) {
                forceRender_ = false;
                mpv_opengl_fbo mpvFbo{static_cast<int>(fbo->handle()), fbo->size().width(),
                                      fbo->size().height(), 0};
                // 输出到 Qt Quick 采样的离屏纹理，不是 OpenGL 默认帧缓冲。
                // 此处额外翻转会使最终视频上下颠倒；Qt 项保持 mirrorVertically=false。
                int flipY = 0;
                // 0 = 不在 render() 内部等待目标显示时刻(时序由 report_swap 回调修正)
                int blockForTargetTime = 0;
                mpv_render_param params[] = {
                        {MPV_RENDER_PARAM_OPENGL_FBO, &mpvFbo},
                        {MPV_RENDER_PARAM_FLIP_Y, &flipY},
                        {MPV_RENDER_PARAM_BLOCK_FOR_TARGET_TIME, &blockForTargetTime},
                        {MPV_RENDER_PARAM_INVALID, nullptr}};
                const int result = lib->renderContextRender(renderContext_, params);
                if (result < 0) {
                    if (!renderFailed_) {
                        renderFailed_ = true;
                        emit notifier_->failed(clientRevision_,
                                               QString::fromUtf8(lib->errorString(result)));
                    }
                } else {
                    // 真正的上屏发生在 window.frameSwapped,那里再回报给 mpv。
                    pendingSwap_ = true;
                }
            }
            // 没有新帧:什么都不做,FBO 里保留上一帧(不擦不闪)。
        } else {
            // 无内核/未装载:黑底
            if (fbo) fbo->bind();
            if (QOpenGLContext *ctx = QOpenGLContext::currentContext()) {
                ctx->functions()->glDisable(GL_SCISSOR_TEST);
                ctx->functions()->glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
                ctx->functions()->glClearColor(0.f, 0.f, 0.f, 1.f);
                ctx->functions()->glClear(GL_COLOR_BUFFER_BIT);
            }
        }
        QQuickOpenGLUtils::resetOpenGLState();
    }

   private:
    // 渲染线程回调:紧跟在真实 swap 之后,把上屏时刻回报给 mpv。
    void reportSwap() {
        if (!pendingSwap_) return;
        pendingSwap_ = false;
        MpvLib *lib = MpvLib::instance();
        if (renderContext_ && lib->renderContextReportSwap)
            lib->renderContextReportSwap(renderContext_);
    }

    void freeRenderContext() {
        MpvLib *lib = MpvLib::instance();
        if (renderContext_ && lib->renderContextFree) {
            lib->renderContextSetUpdateCallback(renderContext_, nullptr, nullptr);
            lib->renderContextFree(renderContext_);
        }
        renderContext_ = nullptr;
        pendingSwap_ = false;
        renderHandle_.reset();
    }

    std::shared_ptr<MpvRenderNotifier> notifier_;
    std::shared_ptr<mpv_handle> pendingHandle_;
    std::shared_ptr<mpv_handle> renderHandle_;
    std::unique_ptr<SwapSink> sink_;
    QPointer<QQuickWindow> window_;
    QMetaObject::Connection frameSwappedConnection_;
    bool createFailed_ = false;
    bool renderFailed_ = false;
    bool clientDirty_ = false;
    bool forceRender_ = false;
    bool pendingSwap_ = false;
    quint64 clientRevision_ = 0;
    mpv_render_context *renderContext_ = nullptr;
};

}  // namespace

MpvVideoItem::MpvVideoItem(QQuickItem *parent) : QQuickFramebufferObject(parent) {
    notifier_ = std::shared_ptr<MpvRenderNotifier>(new MpvRenderNotifier,
        [](MpvRenderNotifier *value) { value->deleteLater(); });
    connect(notifier_.get(), &MpvRenderNotifier::updateRequested, this,
            &MpvVideoItem::update, Qt::QueuedConnection);
    connect(notifier_.get(), &MpvRenderNotifier::initialized, this, [this](quint64 revision) {
        if (!client_ || revision != clientRevision_ || renderReady_) return;
        renderReady_ = true;
        emit renderReadyChanged();
    }, Qt::QueuedConnection);
    connect(notifier_.get(), &MpvRenderNotifier::failed, this,
            [this](quint64 revision, const QString &message) {
        if (!client_ || revision != clientRevision_) return;
        renderReady_ = false;
        emit renderReadyChanged();
        emit renderError(message);
    }, Qt::QueuedConnection);
    setMirrorVertically(false);
}

MpvVideoItem::~MpvVideoItem() = default;

void MpvVideoItem::setClient(MpvClient *client) {
    if (client_ == client) return;
    disconnect(destroyedConnection_);
    client_ = client;
    ++clientRevision_;
    renderReady_ = false;
    if (client) destroyedConnection_ = connect(client, &QObject::destroyed, this, [this] {
        client_ = nullptr;
        ++clientRevision_;
        renderReady_ = false;
        emit renderReadyChanged();
        emit clientChanged();
        update();
    });
    emit renderReadyChanged();
    emit clientChanged();
    update();
}

QQuickFramebufferObject::Renderer *MpvVideoItem::createRenderer() const {
    return new MpvRenderer(const_cast<MpvVideoItem *>(this));
}
