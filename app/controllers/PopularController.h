#ifndef POPULAR_CONTROLLER_H
#define POPULAR_CONTROLLER_H

#include <QHash>
#include <QObject>
#include <QVariantList>

#include "core/PopularApi.h"

// 每种榜单和每周期数独立缓存；切换选择会使旧请求失效。
class PopularController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList pool READ pool NOTIFY stateChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY stateChanged)
    Q_PROPERTY(bool loaded READ loaded NOTIFY stateChanged)
    Q_PROPERTY(bool hasMore READ hasMore NOTIFY stateChanged)
    Q_PROPERTY(QString error READ error NOTIFY stateChanged)
    Q_PROPERTY(QString description READ description NOTIFY stateChanged)
    Q_PROPERTY(QString activeTab READ activeTab NOTIFY stateChanged)
    Q_PROPERTY(int rankingRid READ rankingRid NOTIFY stateChanged)
    Q_PROPERTY(int weeklyNumber READ weeklyNumber NOTIFY stateChanged)
    Q_PROPERTY(QVariantList weeklyPeriods READ weeklyPeriods NOTIFY stateChanged)
    Q_PROPERTY(bool periodsBusy READ periodsBusy NOTIFY stateChanged)
    Q_PROPERTY(QString periodsError READ periodsError NOTIFY stateChanged)
    Q_PROPERTY(bool periodsLoaded READ periodsLoaded NOTIFY stateChanged)
    // 搜索词记忆(渲染释放时保留,重建后回显)
    Q_PROPERTY(QString searchText READ searchText WRITE setSearchText NOTIFY searchTextChanged)
    // 滚动位置记忆(渲染释放时保留,重建后回显;规格明确要求恢复)
    Q_PROPERTY(double scrollOffset READ scrollOffset WRITE setScrollOffset NOTIFY scrollOffsetChanged)
    Q_PROPERTY(int pageIndex READ pageIndex WRITE setPageIndex NOTIFY pageIndexChanged)
    // 综合热门档的榜单页码(翻页只在 popular 档生效;其余档位由 QML 本地分页)
    Q_PROPERTY(int popularPage READ popularPage NOTIFY pageInfoChanged)
    Q_PROPERTY(bool canPrevPopularPage READ canPrevPopularPage NOTIFY pageInfoChanged)
    Q_PROPERTY(bool canNextPopularPage READ canNextPopularPage NOTIFY pageInfoChanged)
public:
    explicit PopularController(QObject *parent = nullptr);
    Q_INVOKABLE void releasePageCache();
    QVariantList pool() const { return state().items; }
    bool busy() const { return state().busy; }
    bool loaded() const { return state().loaded; }
    bool hasMore() const { return activeTab_ == "popular" && state().hasMore; }
    QString error() const { return state().error; }
    QString description() const { return state().description; }
    QString activeTab() const { return activeTab_; }
    int rankingRid() const { return rankingRid_; }
    int weeklyNumber() const { return weeklyNumber_; }
    QVariantList weeklyPeriods() const { return weeklyPeriods_; }
    bool periodsBusy() const { return periodsBusy_; }
    QString periodsError() const { return periodsError_; }
    bool periodsLoaded() const { return periodsLoaded_; }
    QString searchText() const { return searchText_; }
    void setSearchText(const QString &value);
    double scrollOffset() const { return scrollOffset_; }
    void setScrollOffset(double value);
    int pageIndex() const { return pageIndex_; }
    void setPageIndex(int value);
    int popularPage() const { return state().page; }
    bool canPrevPopularPage() const;
    bool canNextPopularPage() const;

    Q_INVOKABLE void ensureLoaded();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void loadMore();
    Q_INVOKABLE void nextPopularPage();
    Q_INVOKABLE void prevPopularPage();
    Q_INVOKABLE void selectTab(const QString &tab);
    Q_INVOKABLE void selectRanking(int rid);
    Q_INVOKABLE void selectWeek(int number);
    Q_INVOKABLE void refreshPeriods();
signals:
    void stateChanged();
    void searchTextChanged();
    void scrollOffsetChanged();
    void pageIndexChanged();
    // 综合热门榜单页码或其可用性变化(含边界探测结果)
    void pageInfoChanged();
    // 翻页边界等一次性提示(QML 经 InfoBar 呈现)
    void pageNotice(QString message);
private:
    friend class PopularControllerTest;
    struct State {
        QVariantList items;
        QString error;
        QString description;
        bool busy = false;
        bool loaded = false;
        bool hasMore = true;
        int nextPage = 1;
        int page = 1;  // 当前呈现的榜单页码(仅综合热门有意义)
    };
    // 取数目的:整页替换(刷新/翻页)、尾部累加(加载更多)、用户指定页码
    enum class FetchMode { Replace, Append, PageJump };
    static constexpr int kMaxPagesPerOperation = 100;
    static constexpr int kMaxPoolSize = 2000;
    QString key() const;
    const State &state() const;
    void invalidateFetch();
    void beginFetch(bool replace);
    void beginPageFetch(int page);
    virtual void startFetch(quint64 generation, const QString &selectionKey, int page);
    virtual void startPeriodsFetch(quint64 generation);
    void finishFetch(quint64 generation, const QString &selectionKey, int page,
                     const PopularPage &result, const QString &error);
    void finishPeriodsFetch(quint64 generation, const QVariantList &periods, const QString &error);

    QHash<QString, State> cache_;
    QStringList cacheUse_;
    QString activeTab_ = QStringLiteral("popular");
    int rankingRid_ = 0;
    int weeklyNumber_ = 0;
    QVariantList weeklyPeriods_;
    bool periodsBusy_ = false;
    bool periodsLoaded_ = false;
    QString periodsError_;
    quint64 generation_ = 0;
    quint64 periodsGeneration_ = 0;
    FetchMode mode_ = FetchMode::Replace;
    int pendingPage_ = 1;
    int scannedPages_ = 0;
    // 已探到的热门末页;0 = 尚未探到(此时允许继续往后翻)
    int popularMaxPage_ = 0;
    QString searchText_;      // 主线程,纯 UI 状态(渲染释放前记忆用)
    double scrollOffset_ = 0; // 主线程,纯 UI 状态(渲染释放前记忆用)
    int pageIndex_ = 1;
};

#endif
