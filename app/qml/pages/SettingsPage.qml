import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import FluentUI
import bbhouse

// 设置页(settings-ui):冻结大标题 + 可滚动卡片流;外观与行为区(主题即时
// 生效/语言重启生效)，末尾提供重新登录入口。
// 本页自身不发起任何网络请求(用户点按超链接打开浏览器除外)。
FluPage {
    id: page
    // 页面自行管理 24px 外边距，抵消 FluPage 默认的额外 5px padding。
    padding: 0

    // ---- 改键录入 ----
    // 点按某行的按键框进入录入态,随后按下的第一个键即为新键位;Esc 取消。
    // 录入态由一个零尺寸但可见的 Item 抢焦点:隐藏的 Item 拿不到焦点,
    // 零尺寸又不会挡住页面交互。点击别处会自然失去焦点并静默退出录入态。
    property string capturingId: ""

    function beginCapture(actionId) {
        capturingId = actionId
        key_capture.forceActiveFocus()
    }
    function cancelCapture() {
        if (capturingId === "") return
        capturingId = ""
        info_bar.showInfo(qsTr("已取消改键"), 1800)
    }
    function completeCapture(key, modifiers) {
        var actionId = capturingId
        capturingId = ""
        if (actionId === "") return
        if (Hotkeys.assign(actionId, key, modifiers) === "unsupported") {
            info_bar.showWarning(qsTr("这个按键不能用作快捷键，请换一个（支持字母、数字、方向键、F1–F12 与常用符号）。"), 5000)
            return
        }
        var conflict = Hotkeys.conflictId(actionId)
        if (conflict !== "") {
            var other = Hotkeys.entry(conflict)
            info_bar.showWarning(qsTr("已改为 %1，但与「%2」重复，实际只有目录中靠前的那个生效。")
                                 .arg(Hotkeys.label(actionId)).arg(other ? other.label : ""), 6000)
            return
        }
        info_bar.showSuccess(qsTr("已保存：%1").arg(Hotkeys.label(actionId)), 2500)
    }
    function themeIndex(theme) {
        // 三档顺序:亮(0)/暗(1)/跟随系统(2)
        return theme === "dark" ? 1 : theme === "light" ? 0 : 2
    }
    function languageIndex(lang) {
        // 三档顺序:跟随系统(0)/简体中文(1)/English(2)
        return lang === "zh_CN" ? 1 : lang === "en_US" ? 2 : 0
    }

    // 初始绑定求值(-1→0)也会触发 onCurrentIndexChanged,
    // 守卫避免页面创建时误写偏好/弹提示
    property bool interactionsReady: false

    function resetProxyDraft() {
        proxy_type.currentIndex = ["http", "socks5", "none"].indexOf(AppPreferences.proxyType)
        proxy_host.text = AppPreferences.proxyHost
        proxy_port.text = String(AppPreferences.proxyPort)
        proxy_username.text = AppPreferences.proxyUsername
        proxy_password.text = AppPreferences.proxyPassword
    }

    Component.onCompleted: {
        resetProxyDraft()
        interactionsReady = true
    }

    FluInfoBar {
        id: info_bar

        root: page
    }

    // 改键捕获:只在录入态抢焦点,吃下录入期间的第一个按键。
    Item {
        id: key_capture

        width: 0
        height: 0
        anchors {
            left: parent.left
            top: parent.top
        }
        onActiveFocusChanged: {
            // 点了别处就静默退出录入,避免"看着在录入其实按键没人收"
            if (!activeFocus && page.capturingId !== "") page.capturingId = ""
        }
        Keys.onPressed: function (event) {
            if (page.capturingId === "") return
            event.accepted = true
            if (event.key === Qt.Key_Escape) {
                page.cancelCapture()
                return
            }
            if (event.isAutoRepeat) return
            page.completeCapture(event.key, event.modifiers)
        }
    }

    FluContentDialog {
        id: dialog_language

        title: qsTr("提示")
        message: qsTr("语言将在下次启动后生效")
        buttonFlags: FluContentDialogType.PositiveButton
        positiveText: qsTr("知道了")
    }

    FolderDialog {
        id: download_folder
        title: qsTr("选择下载位置")
        onAccepted: DownloadController.downloadDirectory = selectedFolder.toString()
    }

    // 冻结标题带(高 56 / 边距 24 / 垂直居中,三页统一规格)
    Item {
        id: title_band

        height: 56
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            leftMargin: 24
            rightMargin: 24
        }
        FluText {
            text: qsTr("设置")
            font: FluTextStyle.Title
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
        }
    }

    // 可滚动内容区:标题带冻结,内容(卡片流)滚动
    Flickable {
        id: scroll_view

        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: width
        contentHeight: layout_cards.height + 16
        anchors {
            top: title_band.bottom
            topMargin: 8
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: 24
            rightMargin: 24
        }

        Column {
            id: layout_cards

            spacing: 12
            width: scroll_view.width

            // 外观与行为卡
            FluFrame {
                width: parent.width
                height: layout_appearance.implicitHeight + 24
                Column {
                    id: layout_appearance

                    spacing: 16
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        topMargin: 12
                        leftMargin: 16
                        rightMargin: 16
                    }
                    FluText {
                        text: qsTr("外观与行为")
                        font: FluTextStyle.BodyStrong
                    }
                    Flow {
                        width: parent.width
                        spacing: 16
                        FluText {
                            text: qsTr("主题")
                            width: 80
                            height: 32
                            verticalAlignment: Text.AlignVCenter
                        }
                        FluRadioButtons {
                            id: radio_theme

                            orientation: Qt.Horizontal
                            currentIndex: page.themeIndex(AppController.theme)
                            onCurrentIndexChanged: {
                                if (!page.interactionsReady || currentIndex < 0) return
                                // 写穿偏好并经 MainWindow 的 FluTheme.darkMode 绑定即时生效
                                AppController.applyTheme(["light", "dark", "system"][currentIndex])
                            }
                            FluRadioButton {
                                text: qsTr("亮色")
                            }
                            FluRadioButton {
                                text: qsTr("暗色")
                            }
                            FluRadioButton {
                                text: qsTr("跟随系统")
                            }
                        }
                    }
                    Flow {
                        width: parent.width
                        spacing: 16
                        FluText {
                            text: qsTr("语言")
                            width: 80
                            height: 32
                            verticalAlignment: Text.AlignVCenter
                        }
                        FluRadioButtons {
                            id: radio_language

                            orientation: Qt.Horizontal
                            currentIndex: page.languageIndex(AppController.language)
                            onCurrentIndexChanged: {
                                if (!page.interactionsReady || currentIndex < 0) return
                                // 语言切换重启生效(ui-localization 规约),运行时仅持久化
                                AppController.language = ["system", "zh_CN", "en_US"][currentIndex]
                                dialog_language.open()
                            }
                            FluRadioButton {
                                text: qsTr("跟随系统")
                            }
                            FluRadioButton {
                                text: qsTr("简体中文")
                            }
                            FluRadioButton {
                                text: qsTr("English")
                            }
                        }
                    }
                }
            }

            FluFrame {
                width: parent.width
                height: memory_settings.implicitHeight + 24
                Column {
                    id: memory_settings
                    anchors { left: parent.left; right: parent.right; top: parent.top;
                        leftMargin: 16; rightMargin: 16; topMargin: 12 }
                    spacing: 12
                    FluText { text: qsTr("后台页面保留时间"); font: FluTextStyle.BodyStrong }
                    FluComboBox {
                        width: 180
                        model: [qsTr("1 分钟"), qsTr("5 分钟"), qsTr("10 分钟"), qsTr("30 分钟")]
                        currentIndex: [1, 5, 10, 30].indexOf(AppPreferences.pageCacheMinutes)
                        onActivated: AppPreferences.pageCacheMinutes = [1, 5, 10, 30][currentIndex]
                    }
                    FluText {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: qsTr("离开页面后超时释放内存，返回时重新加载。下载、历史同步和播放继续运行。")
                    }
                }
            }

            FluExpander {
                id: download_settings
                objectName: "downloadSettings"
                width: parent.width
                headerText: qsTr("下载设置")
                contentHeight: download_fields.implicitHeight + 32
                Column {
                    id: download_fields
                    anchors { left: parent.left; right: parent.right; top: parent.top;
                        leftMargin: 16; rightMargin: 16; topMargin: 16 }
                    spacing: 14
                    FluText {
                        width: parent.width
                        text: qsTr("下载位置")
                        font: FluTextStyle.BodyStrong
                    }
                    RowLayout {
                        width: parent.width
                        FluTextBox {
                            Layout.fillWidth: true
                            text: DownloadController.downloadDirectory
                            Accessible.name: qsTr("下载位置")
                            onCommit: function(value) { DownloadController.downloadDirectory = value }
                        }
                        FluButton {
                            text: qsTr("选择文件夹")
                            onClicked: download_folder.open()
                        }
                    }
                    FluText {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: qsTr("默认保存到当前用户的下载文件夹。更改位置仅影响新建任务。")
                        textColor: FluTheme.fontSecondaryColor
                    }
                    FluText { text: qsTr("默认下载内容"); font: FluTextStyle.BodyStrong }
                    Flow {
                        width: parent.width
                        spacing: 20
                        FluCheckBox {
                            text: qsTr("视频")
                            checked: DownloadController.downloadVideo
                            clickListener: function() { DownloadController.downloadVideo = !DownloadController.downloadVideo }
                        }
                        FluCheckBox {
                            text: qsTr("仅音频")
                            checked: DownloadController.downloadAudio
                            clickListener: function() { DownloadController.downloadAudio = !DownloadController.downloadAudio }
                        }
                        FluCheckBox {
                            text: qsTr("弹幕")
                            checked: DownloadController.downloadDanmaku
                            clickListener: function() { DownloadController.downloadDanmaku = !DownloadController.downloadDanmaku }
                        }
                        FluCheckBox {
                            text: qsTr("字幕")
                            checked: DownloadController.downloadSubtitles
                            clickListener: function() { DownloadController.downloadSubtitles = !DownloadController.downloadSubtitles }
                        }
                    }
                    RowLayout {
                        width: parent.width
                        FluText { text: qsTr("优先画质") }
                        FluComboBox {
                            Layout.fillWidth: true
                            model: [qsTr("最高可用"), "1080P", "720P", "480P", "360P"]
                            currentIndex: Math.max(0, [127, 80, 64, 32, 16].indexOf(DownloadController.preferredQn))
                            onActivated: DownloadController.preferredQn = [127, 80, 64, 32, 16][currentIndex]
                        }
                    }
                    FluText {
                        width: parent.width
                        text: qsTr("工具路径")
                        font: FluTextStyle.BodyStrong
                    }
                    GridLayout {
                        width: parent.width
                        columns: width >= 540 ? 2 : 1
                        columnSpacing: 20
                        rowSpacing: 12
                        FluText { text: "aria2c" }
                        FluTextBox {
                            Layout.fillWidth: true
                            text: DownloadController.aria2Path
                            placeholderText: qsTr("自动检测，或填写可执行文件完整路径")
                            Accessible.name: "aria2c"
                            onCommit: function(value) { DownloadController.aria2Path = value }
                        }
                        FluText { text: "FFmpeg" }
                        FluTextBox {
                            Layout.fillWidth: true
                            text: DownloadController.ffmpegPath
                            placeholderText: qsTr("自动检测，或填写可执行文件完整路径")
                            Accessible.name: "FFmpeg"
                            onCommit: function(value) { DownloadController.ffmpegPath = value }
                        }
                    }
                    FluText {
                        width: parent.width
                        text: DownloadController.toolStatus
                        wrapMode: Text.Wrap
                        textColor: FluTheme.fontSecondaryColor
                    }
                    FluButton {
                        text: qsTr("重新检测下载工具")
                        onClicked: DownloadController.refreshTools()
                    }
                    FluText {
                        width: parent.width
                        text: qsTr("媒体由 aria2 下载、FFmpeg 合并；弹幕与字幕使用 curl 下载。媒体库播放时自动加载同目录同名 XML 弹幕。")
                        wrapMode: Text.Wrap
                        textColor: FluTheme.fontSecondaryColor
                    }
                }
            }

            FluExpander {
                id: proxy_settings
                objectName: "regionalProxySettings"
                width: parent.width
                headerText: qsTr("代理设置")
                contentHeight: proxy_fields.implicitHeight + 32
                Column {
                    id: proxy_fields
                    anchors { left: parent.left; right: parent.right; top: parent.top
                        leftMargin: 16; rightMargin: 16; topMargin: 16 }
                    spacing: 12
                    FluText {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: qsTr("仅用于港澳台番剧的 API 请求；视频和音频直连，其他页面不使用此代理。")
                        textColor: FluTheme.fontSecondaryColor
                    }
                    GridLayout {
                        width: parent.width
                        columns: width >= 540 ? 2 : 1
                        columnSpacing: 20
                        rowSpacing: 12
                        FluText { text: qsTr("类型") }
                        FluComboBox {
                            id: proxy_type
                            Layout.fillWidth: true
                            model: [qsTr("HTTP"), qsTr("SOCKS5"), qsTr("不使用代理")]
                            Accessible.name: qsTr("代理类型")
                        }
                        FluText { text: qsTr("主机") }
                        FluTextBox {
                            id: proxy_host
                            Layout.fillWidth: true
                            enabled: proxy_type.currentIndex !== 2
                            placeholderText: "localhost"
                            maximumLength: 253
                            Accessible.name: qsTr("代理主机")
                        }
                        FluText { text: qsTr("端口") }
                        FluTextBox {
                            id: proxy_port
                            Layout.fillWidth: true
                            enabled: proxy_type.currentIndex !== 2
                            placeholderText: "7890"
                            inputMethodHints: Qt.ImhDigitsOnly
                            maximumLength: 5
                            validator: IntValidator { bottom: 1; top: 65535 }
                            Accessible.name: qsTr("代理端口")
                        }
                        FluText { text: qsTr("用户名（可选）") }
                        FluTextBox {
                            id: proxy_username
                            Layout.fillWidth: true
                            enabled: proxy_type.currentIndex !== 2
                            maximumLength: 256
                            Accessible.name: qsTr("代理用户名")
                        }
                        FluText { text: qsTr("密码（可选）") }
                        FluPasswordBox {
                            id: proxy_password
                            Layout.fillWidth: true
                            enabled: proxy_type.currentIndex !== 2
                            maximumLength: 1024
                            Accessible.name: qsTr("代理密码")
                        }
                    }
                    FluText {
                        width: parent.width
                        wrapMode: Text.Wrap
                        font: FluTextStyle.Caption
                        textColor: FluTheme.fontSecondaryColor
                        text: qsTr("认证信息可留空。密码仅本次运行有效，重启后需重新填写。")
                    }
                    Flow {
                        width: parent.width
                        spacing: 12
                        FluFilledButton {
                            text: qsTr("保存代理设置")
                            onClicked: {
                                const port = Number(proxy_port.text)
                                if (!proxy_port.acceptableInput || !AppPreferences.saveProxySettings(
                                        ["http", "socks5", "none"][proxy_type.currentIndex],
                                        proxy_host.text, port, proxy_username.text, proxy_password.text)) {
                                    info_bar.showError(qsTr("保存失败：请输入有效主机、1–65535 的端口；填写密码时必须填写用户名。"), 5000)
                                    return
                                }
                                page.resetProxyDraft()
                                info_bar.showSuccess(qsTr("代理设置已保存，将用于下一次港澳台番剧请求。"), 3000)
                            }
                        }
                        FluButton {
                            text: qsTr("还原未保存的修改")
                            onClicked: page.resetProxyDraft()
                        }
                    }
                }
            }

            FluFrame {
                width: parent.width
                height: playback_settings.implicitHeight + 24
                Column {
                    id: playback_settings
                    anchors { left: parent.left; right: parent.right; top: parent.top
                        leftMargin: 16; rightMargin: 16; topMargin: 12 }
                    spacing: 12
                    FluText { text: qsTr("播放与弹幕"); font: FluTextStyle.BodyStrong }
                    GridLayout {
                        width: parent.width
                        columns: width >= 540 ? 2 : 1
                        columnSpacing: 20
                        rowSpacing: 12

                        FluText {
                            text: qsTr("默认弹幕状态")
                            Layout.fillWidth: parent.columns === 1
                            wrapMode: Text.Wrap
                        }
                        Item {
                            Layout.fillWidth: true
                            implicitHeight: 32
                            FluToggleSwitch {
                                objectName: "danmakuEnabledSwitch"
                                anchors.verticalCenter: parent.verticalCenter
                                checked: AppPreferences.danmakuEnabled
                                Accessible.role: Accessible.CheckBox
                                Accessible.name: qsTr("默认弹幕状态")
                                Accessible.checked: checked
                                contentDescription: qsTr("与播放器弹幕开关同步，记住最后一次选择。")
                                clickListener: function() { AppPreferences.danmakuEnabled = !AppPreferences.danmakuEnabled }
                            }
                        }

                        FluText { text: qsTr("弹幕不透明度") }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            FluSlider {
                                objectName: "danmakuOpacitySlider"
                                Layout.fillWidth: true
                                from: 0; to: 100; stepSize: 1
                                value: AppPreferences.danmakuOpacity
                                text: qsTr("%1%").arg(Math.round(value))
                                Accessible.name: qsTr("弹幕不透明度")
                                onMoved: AppPreferences.danmakuOpacity = Math.round(value)
                            }
                            FluText {
                                Layout.preferredWidth: 44
                                horizontalAlignment: Text.AlignRight
                                text: qsTr("%1%").arg(AppPreferences.danmakuOpacity)
                            }
                        }

                        FluText { text: qsTr("弹幕字号") }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            FluSlider {
                                objectName: "danmakuFontSizeSlider"
                                Layout.fillWidth: true
                                from: 12; to: 48; stepSize: 1
                                value: AppPreferences.danmakuFontSize
                                text: String(Math.round(value))
                                Accessible.name: qsTr("弹幕字号")
                                onMoved: AppPreferences.danmakuFontSize = Math.round(value)
                            }
                            FluText {
                                Layout.preferredWidth: 44
                                horizontalAlignment: Text.AlignRight
                                text: String(AppPreferences.danmakuFontSize)
                            }
                        }

                        FluText { text: qsTr("弹幕显示区域") }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 16
                            FluRadioButton {
                                objectName: "danmakuAreaQuarter"
                                text: qsTr("顶部 1/4")
                                checked: AppPreferences.danmakuArea === 25
                                Accessible.role: Accessible.RadioButton
                                Accessible.checked: checked
                                clickListener: function() { AppPreferences.danmakuArea = 25 }
                            }
                            FluRadioButton {
                                objectName: "danmakuAreaHalf"
                                text: qsTr("半屏")
                                checked: AppPreferences.danmakuArea === 50
                                Accessible.role: Accessible.RadioButton
                                Accessible.checked: checked
                                clickListener: function() { AppPreferences.danmakuArea = 50 }
                            }
                            FluRadioButton {
                                objectName: "danmakuAreaFull"
                                text: qsTr("全屏")
                                checked: AppPreferences.danmakuArea === 100
                                Accessible.role: Accessible.RadioButton
                                Accessible.checked: checked
                                clickListener: function() { AppPreferences.danmakuArea = 100 }
                            }
                        }

                        FluText { text: qsTr("弹幕密度上限") }
                        FluComboBox {
                            objectName: "danmakuDensityCombo"
                            Layout.fillWidth: true
                            model: [qsTr("不限制"), qsTr("同时最多 20 条"), qsTr("同时最多 40 条"),
                                    qsTr("同时最多 60 条"), qsTr("同时最多 80 条"), qsTr("同时最多 100 条")]
                            currentIndex: AppPreferences.danmakuDensity / 20
                            Accessible.name: qsTr("弹幕密度上限")
                            onActivated: AppPreferences.danmakuDensity = currentIndex * 20
                        }

                        FluText { text: qsTr("合并相似弹幕") }
                        Item {
                            Layout.fillWidth: true
                            implicitHeight: 32
                            FluToggleSwitch {
                                objectName: "danmakuMergeSimilarSwitch"
                                anchors.verticalCenter: parent.verticalCenter
                                checked: AppPreferences.danmakuMergeSimilar
                                Accessible.role: Accessible.CheckBox
                                Accessible.name: qsTr("合并相似弹幕")
                                Accessible.checked: checked
                                clickListener: function() { AppPreferences.danmakuMergeSimilar = !AppPreferences.danmakuMergeSimilar }
                            }
                        }
                    }
                    FluText {
                        width: parent.width
                        wrapMode: Text.Wrap
                        textColor: FluTheme.fontSecondaryColor
                        text: qsTr("刷屏的重复或近似弹幕只显示一条，并标注合并数量。")
                    }

                    Flow {
                        width: parent.width
                        spacing: 16
                        FluText {
                            text: qsTr("弹幕实现")
                            width: 80; height: 36
                            verticalAlignment: Text.AlignVCenter
                        }
                        FluComboBox {
                            objectName: "danmakuImplementationCombo"
                            width: Math.min(280, playback_settings.width)
                            model: [qsTr("场景图文字"), qsTr("预缓存图像")]
                            currentIndex: AppPreferences.danmakuImplementation === "sprite" ? 1 : 0
                            onActivated: AppPreferences.danmakuImplementation = currentIndex === 1 ? "sprite" : "scene"
                        }
                    }
                    FluText {
                        width: parent.width
                        wrapMode: Text.Wrap
                        textColor: FluTheme.fontSecondaryColor
                        text: AppPreferences.danmakuImplementation === "sprite"
                              ? qsTr("提前准备弹幕图像。跳转后从目标位置重新显示，不补播之前的弹幕。")
                              : qsTr("使用场景图文字绘制，保留现有弹幕显示方式。")
                    }
                    FluText {
                        width: parent.width
                        wrapMode: Text.Wrap
                        textColor: FluTheme.fontSecondaryColor
                        text: qsTr("设置立即生效并自动保存。默认弹幕状态与播放器开关同步，记住最后一次选择。")
                    }
                }
            }

            // ---- 快捷键卡(hotkeys):目录来自 Hotkeys 单例,点右侧按键框录入新键 ----
            FluFrame {
                id: hotkey_settings

                width: parent.width
                height: hotkey_fields.implicitHeight + 24
                Column {
                    id: hotkey_fields

                    anchors { left: parent.left; right: parent.right; top: parent.top;
                        leftMargin: 16; rightMargin: 16; topMargin: 12 }
                    spacing: 10
                    FluText { text: qsTr("快捷键"); font: FluTextStyle.BodyStrong }
                    FluText {
                        width: parent.width
                        wrapMode: Text.Wrap
                        textColor: FluTheme.fontSecondaryColor
                        text: qsTr("点按右侧的按键框后，直接按下想用的键即可改键（Esc 取消）。改完立即生效并保存。")
                    }

                    Repeater {
                        model: Hotkeys.scopes

                        delegate: Column {
                            id: scope_block

                            required property var modelData

                            width: hotkey_fields.width
                            spacing: 6
                            FluText {
                                text: scope_block.modelData.title
                                font: FluTextStyle.BodyStrong
                                textColor: FluTheme.fontSecondaryColor
                            }
                            Repeater {
                                model: Hotkeys.entriesOf(scope_block.modelData.key)

                                delegate: RowLayout {
                                    id: hotkey_row

                                    required property var modelData

                                    width: hotkey_fields.width
                                    spacing: 8
                                    FluText {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        wrapMode: Text.Wrap
                                        text: hotkey_row.modelData.label
                                    }
                                    FluText {
                                        visible: Hotkeys.conflictId(hotkey_row.modelData.id) !== ""
                                        text: qsTr("与其它快捷键重复")
                                        textColor: FluTheme.primaryColor
                                    }
                                    FluButton {
                                        Layout.preferredWidth: 156
                                        text: page.capturingId === hotkey_row.modelData.id
                                              ? qsTr("请按新键…")
                                              : Hotkeys.label(hotkey_row.modelData.id)
                                        Accessible.name: qsTr("修改「%1」的按键").arg(hotkey_row.modelData.label)
                                        onClicked: page.beginCapture(hotkey_row.modelData.id)
                                    }
                                    FluButton {
                                        Layout.preferredWidth: 64
                                        text: qsTr("重置")
                                        enabled: !Hotkeys.isDefault(hotkey_row.modelData.id)
                                        Accessible.name: qsTr("恢复「%1」的默认按键").arg(hotkey_row.modelData.label)
                                        onClicked: {
                                            Hotkeys.reset(hotkey_row.modelData.id)
                                            info_bar.showSuccess(qsTr("已恢复默认：%1")
                                                                 .arg(Hotkeys.label(hotkey_row.modelData.id)), 2000)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    FluText {
                        text: qsTr("按键行为")
                        font: FluTextStyle.BodyStrong
                        textColor: FluTheme.fontSecondaryColor
                        topPadding: 6
                    }
                    GridLayout {
                        width: hotkey_fields.width
                        columns: hotkey_fields.width >= 540 ? 2 : 1
                        columnSpacing: 20
                        rowSpacing: 10

                        FluText {
                            text: qsTr("快进 / 快退步长")
                            Layout.fillWidth: hotkey_fields.width < 540
                            wrapMode: Text.Wrap
                        }
                        FluComboBox {
                            objectName: "hotkeySeekStepCombo"
                            Layout.fillWidth: true
                            model: [qsTr("3 秒"), qsTr("5 秒"), qsTr("10 秒"), qsTr("15 秒"), qsTr("30 秒")]
                            currentIndex: Math.max(0, [3, 5, 10, 15, 30].indexOf(Hotkeys.seekStepSeconds))
                            Accessible.name: qsTr("快进 / 快退步长")
                            onActivated: Hotkeys.setSeekStepSeconds([3, 5, 10, 15, 30][currentIndex])
                        }

                        FluText {
                            text: qsTr("音量步长")
                            Layout.fillWidth: hotkey_fields.width < 540
                            wrapMode: Text.Wrap
                        }
                        FluComboBox {
                            objectName: "hotkeyVolumeStepCombo"
                            Layout.fillWidth: true
                            model: [qsTr("2%"), qsTr("5%"), qsTr("10%"), qsTr("15%")]
                            currentIndex: Math.max(0, [2, 5, 10, 15].indexOf(Hotkeys.volumeStepPercent))
                            Accessible.name: qsTr("音量步长")
                            onActivated: Hotkeys.setVolumeStepPercent([2, 5, 10, 15][currentIndex])
                        }

                        FluText {
                            text: qsTr("长按倍速")
                            Layout.fillWidth: hotkey_fields.width < 540
                            wrapMode: Text.Wrap
                        }
                        FluComboBox {
                            objectName: "hotkeyHoldSpeedCombo"
                            Layout.fillWidth: true
                            model: ["1.25×", "1.5×", "2.0×", "3.0×"]
                            currentIndex: Math.max(0, [1.25, 1.5, 2, 3].indexOf(Hotkeys.holdSpeed))
                            Accessible.name: qsTr("长按倍速")
                            onActivated: Hotkeys.setHoldSpeed([1.25, 1.5, 2, 3][currentIndex])
                        }

                        FluText {
                            text: qsTr("长按判定时间")
                            Layout.fillWidth: hotkey_fields.width < 540
                            wrapMode: Text.Wrap
                        }
                        FluComboBox {
                            objectName: "hotkeyHoldDelayCombo"
                            Layout.fillWidth: true
                            model: [qsTr("0.2 秒"), qsTr("0.35 秒"), qsTr("0.5 秒"), qsTr("0.8 秒")]
                            currentIndex: Math.max(0, [200, 350, 500, 800].indexOf(Hotkeys.holdDelayMs))
                            Accessible.name: qsTr("长按判定时间")
                            onActivated: Hotkeys.setHoldDelayMs([200, 350, 500, 800][currentIndex])
                        }

                        FluText {
                            text: qsTr("滚轮调音量")
                            Layout.fillWidth: hotkey_fields.width < 540
                            wrapMode: Text.Wrap
                        }
                        Item {
                            Layout.fillWidth: true
                            implicitHeight: 32
                            FluToggleSwitch {
                                objectName: "hotkeyWheelVolumeSwitch"
                                anchors.verticalCenter: parent.verticalCenter
                                checked: Hotkeys.wheelVolumeAdjust
                                Accessible.role: Accessible.CheckBox
                                Accessible.name: qsTr("滚轮调音量")
                                Accessible.checked: checked
                                clickListener: function() {
                                    Hotkeys.setWheelVolumeAdjust(!Hotkeys.wheelVolumeAdjust)
                                }
                            }
                        }
                    }
                    FluText {
                        width: parent.width
                        wrapMode: Text.Wrap
                        textColor: FluTheme.fontSecondaryColor
                        text: qsTr("播放画面区滚轮上滚加大音量、下滚减小音量，直播窗口同样适用。")
                    }
                    FluText {
                        width: parent.width
                        wrapMode: Text.Wrap
                        textColor: FluTheme.fontSecondaryColor
                        text: qsTr("列表页快捷键只在带分页的页面生效：流行、番剧、特别关注、稍后再看、本地历史、下载管理。")
                    }
                    FluText {
                        width: parent.width
                        wrapMode: Text.Wrap
                        textColor: FluTheme.fontSecondaryColor
                        font: FluTextStyle.Caption
                        text: qsTr("Esc 固定用于逐级退出，不能改键。")
                    }
                    Flow {
                        width: parent.width
                        spacing: 12
                        FluButton {
                            objectName: "hotkeyResetAllButton"
                            text: qsTr("全部恢复默认")
                            enabled: Hotkeys.customized
                            onClicked: {
                                page.cancelCapture()
                                Hotkeys.resetAll()
                                info_bar.showSuccess(qsTr("已恢复全部默认快捷键"), 2500)
                            }
                        }
                    }
                }
            }

            FluFrame {
                width: parent.width
                height: login_row.implicitHeight + 32
                RowLayout {
                    id: login_row
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 16
                    ColumnLayout {
                        Layout.fillWidth: true
                        FluText { text: qsTr("账号登录"); font: FluTextStyle.BodyStrong }
                        FluText {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            text: qsTr("通过导入 Cookie 更新登录状态。")
                            textColor: FluTheme.fontSecondaryColor
                        }
                    }
                    FluButton {
                        text: qsTr("重新登录")
                        onClicked: LoginController.open()
                    }
                }
            }
        }

        ScrollBar.vertical: FluScrollBar {}
    }
}
