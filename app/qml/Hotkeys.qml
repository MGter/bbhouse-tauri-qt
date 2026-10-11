pragma Singleton
import QtQuick

// 快捷键(hotkeys):可改键的动作目录 + 相关行为参数,播放器/列表页/设置页三方共享。
//
// 为什么集中在一个单例里:设置页要写、播放器与主窗口要读,单例是唯一的共享点。
// QML 不能按字符串动态取 Qt.Key_* 枚举,所以「键名 ↔ 键码」用显式字面表,
// 改键只允许落在表内的按键上(表外按键不会被录入)。
//
// 持久化:整块 JSON 存进 AppPreferences 的通用键值口(ini 里的 "hotkeys" 一项),
// 一次读、一次写,新增动作不必改 C++。
QtObject {
    id: root

    readonly property string storageKey: "hotkeys"

    // ---- 行为参数默认值 ----
    readonly property int defaultSeekStepSeconds: 5
    readonly property int defaultVolumeStepPercent: 5
    readonly property real defaultHoldSpeed: 2.0
    readonly property int defaultHoldDelayMs: 350

    // ---- 动作目录:scope 用于分组展示与冲突判定(同组内同一按键只应出现一次) ----
    readonly property var catalog: [
        { id: "player.volumeUp", scope: "player", label: qsTr("音量 +"),
          key: Qt.Key_Up, mods: Qt.NoModifier,
          description: qsTr("音量增大一档；滚轮上滚等效") },
        { id: "player.volumeDown", scope: "player", label: qsTr("音量 −"),
          key: Qt.Key_Down, mods: Qt.NoModifier,
          description: qsTr("音量减小一档；滚轮下滚等效") },
        { id: "player.seekBack", scope: "player", label: qsTr("快退"),
          key: Qt.Key_Left, mods: Qt.NoModifier,
          description: qsTr("向后跳一段（步长见下方设置）") },
        { id: "player.seekForward", scope: "player", label: qsTr("快进 / 长按倍速"),
          key: Qt.Key_Right, mods: Qt.NoModifier,
          description: qsTr("短按快进一段；按住不放切换到倍速播放，松开恢复原速") },
        { id: "player.playPause", scope: "player", label: qsTr("播放 / 暂停"),
          key: Qt.Key_Space, mods: Qt.NoModifier,
          description: qsTr("切换播放与暂停") },
        { id: "player.fullscreen", scope: "player", label: qsTr("全屏切换"),
          key: Qt.Key_F, mods: Qt.NoModifier,
          description: qsTr("在全屏与窗口之间切换") },
        { id: "player.mute", scope: "player", label: qsTr("静音切换"),
          key: Qt.Key_M, mods: Qt.NoModifier,
          description: qsTr("静音 / 取消静音") },
        { id: "player.danmaku", scope: "player", label: qsTr("弹幕开关"),
          key: Qt.Key_D, mods: Qt.NoModifier,
          description: qsTr("显示或隐藏弹幕") },
        { id: "player.subtitle", scope: "player", label: qsTr("字幕开关"),
          key: Qt.Key_S, mods: Qt.NoModifier,
          description: qsTr("切换字幕轨") },
        { id: "player.next", scope: "player", label: qsTr("播放下一集"),
          key: Qt.Key_N, mods: Qt.ShiftModifier,
          description: qsTr("跳到播放列表的下一个") },
        { id: "list.focusSearch", scope: "list", label: qsTr("聚焦搜索框"),
          key: Qt.Key_F, mods: Qt.ControlModifier,
          description: qsTr("光标直接落到当前页面标题栏的搜索框") },
        { id: "list.prevPage", scope: "list", label: qsTr("上一页"),
          key: Qt.Key_K, mods: Qt.NoModifier,
          description: qsTr("上一页；已在首页时不动") },
        { id: "list.nextPage", scope: "list", label: qsTr("下一页"),
          key: Qt.Key_J, mods: Qt.NoModifier,
          description: qsTr("下一页；已在末页时不动") },
        { id: "list.scrollUp", scope: "list", label: qsTr("列表上翻一屏"),
          key: Qt.Key_U, mods: Qt.NoModifier,
          description: qsTr("当前列表向上滚动一屏") },
        { id: "list.scrollDown", scope: "list", label: qsTr("列表下翻一屏"),
          key: Qt.Key_D, mods: Qt.NoModifier,
          description: qsTr("当前列表向下滚动一屏") },
    ]

    readonly property var scopes: [
        { key: "player", title: qsTr("播放器") },
        { key: "list", title: qsTr("列表页（仅有分页的页面）") }
    ]

    // ---- 可分配的按键:键名 ↔ Qt 键码 ----
    readonly property var nameToCode: ({
        "Up": Qt.Key_Up,
        "Down": Qt.Key_Down,
        "Left": Qt.Key_Left,
        "Right": Qt.Key_Right,
        "Space": Qt.Key_Space,
        "Enter": Qt.Key_Return,
        "Tab": Qt.Key_Tab,
        "Backspace": Qt.Key_Backspace,
        "Insert": Qt.Key_Insert,
        "Delete": Qt.Key_Delete,
        "Home": Qt.Key_Home,
        "End": Qt.Key_End,
        "PageUp": Qt.Key_PageUp,
        "PageDown": Qt.Key_PageDown,
        "Minus": Qt.Key_Minus,
        "Equal": Qt.Key_Equal,
        "BracketLeft": Qt.Key_BracketLeft,
        "BracketRight": Qt.Key_BracketRight,
        "Semicolon": Qt.Key_Semicolon,
        "Apostrophe": Qt.Key_Apostrophe,
        "Comma": Qt.Key_Comma,
        "Period": Qt.Key_Period,
        "Slash": Qt.Key_Slash,
        "Backquote": Qt.Key_QuoteLeft,
        "Backslash": Qt.Key_Backslash,
        "F1": Qt.Key_F1,
        "F2": Qt.Key_F2,
        "F3": Qt.Key_F3,
        "F4": Qt.Key_F4,
        "F5": Qt.Key_F5,
        "F6": Qt.Key_F6,
        "F7": Qt.Key_F7,
        "F8": Qt.Key_F8,
        "F9": Qt.Key_F9,
        "F10": Qt.Key_F10,
        "F11": Qt.Key_F11,
        "F12": Qt.Key_F12,
        "A": Qt.Key_A,
        "B": Qt.Key_B,
        "C": Qt.Key_C,
        "D": Qt.Key_D,
        "E": Qt.Key_E,
        "F": Qt.Key_F,
        "G": Qt.Key_G,
        "H": Qt.Key_H,
        "I": Qt.Key_I,
        "J": Qt.Key_J,
        "K": Qt.Key_K,
        "L": Qt.Key_L,
        "M": Qt.Key_M,
        "N": Qt.Key_N,
        "O": Qt.Key_O,
        "P": Qt.Key_P,
        "Q": Qt.Key_Q,
        "R": Qt.Key_R,
        "S": Qt.Key_S,
        "T": Qt.Key_T,
        "U": Qt.Key_U,
        "V": Qt.Key_V,
        "W": Qt.Key_W,
        "X": Qt.Key_X,
        "Y": Qt.Key_Y,
        "Z": Qt.Key_Z,
        "0": Qt.Key_0,
        "1": Qt.Key_1,
        "2": Qt.Key_2,
        "3": Qt.Key_3,
        "4": Qt.Key_4,
        "5": Qt.Key_5,
        "6": Qt.Key_6,
        "7": Qt.Key_7,
        "8": Qt.Key_8,
        "9": Qt.Key_9,
    })

    readonly property var codeToName: {
        var map = {}
        for (var name in root.nameToCode)
            map[root.nameToCode[name]] = name
        return map
    }

    readonly property var modifierTable: [
        { mask: Qt.ShiftModifier, name: "Shift" },
        { mask: Qt.ControlModifier, name: "Ctrl" },
        { mask: Qt.AltModifier, name: "Alt" },
        { mask: Qt.MetaModifier, name: "Meta" }
    ]
    readonly property int modifierMask: Qt.ShiftModifier | Qt.ControlModifier
                                         | Qt.AltModifier | Qt.MetaModifier

    // ---- 生效状态:overrides 只记录被改过的动作(id → "Ctrl+F") ----
    property var overrides: ({})
    property int seekStepSeconds: defaultSeekStepSeconds
    property int volumeStepPercent: defaultVolumeStepPercent
    property real holdSpeed: defaultHoldSpeed
    property int holdDelayMs: defaultHoldDelayMs
    property bool wheelVolumeAdjust: true
    property bool loaded: false

    Component.onCompleted: root.load()

    // ---- 读写 ----

    function load() {
        var stored = null
        try {
            var raw = AppPreferences.value(root.storageKey, "")
            if (raw !== undefined && raw !== null && String(raw) !== "")
                stored = JSON.parse(String(raw))
        } catch (error) {
            stored = null
        }
        if (stored && typeof stored === "object") {
            root.overrides = stored.map ? stored.map : ({})
            if (stored.seekStepSeconds !== undefined)
                root.seekStepSeconds = Math.round(Number(stored.seekStepSeconds))
            if (stored.volumeStepPercent !== undefined)
                root.volumeStepPercent = Math.round(Number(stored.volumeStepPercent))
            if (stored.holdSpeed !== undefined)
                root.holdSpeed = Number(stored.holdSpeed)
            if (stored.holdDelayMs !== undefined)
                root.holdDelayMs = Math.round(Number(stored.holdDelayMs))
            if (stored.wheelVolumeAdjust !== undefined)
                root.wheelVolumeAdjust = Boolean(stored.wheelVolumeAdjust)
        }
        root.loaded = true
    }

    function persist() {
        try {
            AppPreferences.setValue(root.storageKey, JSON.stringify({
                map: root.overrides,
                seekStepSeconds: root.seekStepSeconds,
                volumeStepPercent: root.volumeStepPercent,
                holdSpeed: root.holdSpeed,
                holdDelayMs: root.holdDelayMs,
                wheelVolumeAdjust: root.wheelVolumeAdjust
            }))
        } catch (error) {
            // 偏好写入失败不影响本次运行,静默降级
        }
    }

    // ---- 键名 / 键码 / 组合键字符串 ----

    // "Ctrl+Shift+F" → { key: 键码, mods: 修饰键掩码 };不可解析返回 null
    function parse(text) {
        var parts = String(text === undefined || text === null ? "" : text).split("+")
        if (parts.length === 0) return null
        var code = root.nameToCode[parts[parts.length - 1]]
        if (code === undefined) return null
        var mods = 0
        for (var i = 0; i < parts.length - 1; i++) {
            var token = parts[i].trim()
            for (var j = 0; j < root.modifierTable.length; j++)
                if (root.modifierTable[j].name === token) mods |= root.modifierTable[j].mask
        }
        return { key: code, mods: mods }
    }

    function sequenceOf(code, mods) {
        var parts = []
        for (var i = 0; i < root.modifierTable.length; i++)
            if (mods & root.modifierTable[i].mask) parts.push(root.modifierTable[i].name)
        parts.push(root.codeToName[code] || "")
        return parts.join("+")
    }

    // ---- 动作查询 ----

    function entry(id) {
        for (var i = 0; i < root.catalog.length; i++)
            if (root.catalog[i].id === id) return root.catalog[i]
        return null
    }

    // 设置页按组取行
    function entriesOf(scope) {
        var result = []
        for (var i = 0; i < root.catalog.length; i++)
            if (root.catalog[i].scope === scope) result.push(root.catalog[i])
        return result
    }

    // 是否改过任意键(用于"全部恢复默认"的可用态)
    readonly property bool customized: {
        var count = 0
        for (var key in root.overrides) count++
        return count > 0
    }

    function defaultSequence(id) {
        var item = root.entry(id)
        return item ? root.sequenceOf(item.key, item.mods) : ""
    }

    // 生效中的组合键字符串(默认 或 用户改过的)
    function sequence(id) {
        var custom = root.overrides[id]
        if (custom !== undefined && root.parse(custom) !== null) return String(custom)
        return root.defaultSequence(id)
    }

    function keyCode(id) {
        var parsed = root.parse(root.sequence(id))
        return parsed ? parsed.key : 0
    }

    function modifiers(id) {
        var parsed = root.parse(root.sequence(id))
        return parsed ? parsed.mods : 0
    }

    // 展示用文案:"Ctrl + F"
    function label(id) {
        return String(root.sequence(id)).split("+").join(" + ")
    }

    function isDefault(id) {
        return root.sequence(id) === root.defaultSequence(id)
    }

    // 同组内是否与别的动作撞键(撞了仍然可用,但按目录顺序只有第一个生效)
    function conflictId(id) {
        var item = root.entry(id)
        if (!item) return ""
        var text = root.sequence(id)
        for (var i = 0; i < root.catalog.length; i++) {
            var other = root.catalog[i]
            if (other.id === id || other.scope !== item.scope) continue
            if (root.sequence(other.id) === text) return other.id
        }
        return ""
    }

    // 命中判定:scope 内哪个动作绑了这个按键+修饰键组合
    function match(scope, code, mods) {
        var masked = mods & root.modifierMask
        for (var i = 0; i < root.catalog.length; i++) {
            var item = root.catalog[i]
            if (item.scope !== scope) continue
            if (root.keyCode(item.id) === code
                    && (root.modifiers(item.id) & root.modifierMask) === masked)
                return item.id
        }
        return ""
    }

    // ---- 改键 ----

    // 改键成功返回 "";按键不在可分配表内返回 "unsupported"。
    function assign(id, code, mods) {
        if (!root.entry(id)) return "unsupported"
        if (root.codeToName[code] === undefined) return "unsupported"
        var next = {}
        for (var key in root.overrides) next[key] = root.overrides[key]
        next[id] = root.sequenceOf(code, mods)
        root.overrides = next
        root.persist()
        return ""
    }

    function reset(id) {
        var next = {}
        for (var key in root.overrides)
            if (key !== id) next[key] = root.overrides[key]
        root.overrides = next
        root.persist()
    }

    function resetAll() {
        root.overrides = ({})
        root.persist()
    }

    // ---- 行为参数写入(带持久化) ----

    function setSeekStepSeconds(value) {
        root.seekStepSeconds = Math.max(1, Math.round(Number(value)))
        root.persist()
    }
    function setVolumeStepPercent(value) {
        root.volumeStepPercent = Math.max(1, Math.round(Number(value)))
        root.persist()
    }
    function setHoldSpeed(value) {
        root.holdSpeed = Number(value)
        root.persist()
    }
    function setHoldDelayMs(value) {
        root.holdDelayMs = Math.max(120, Math.round(Number(value)))
        root.persist()
    }
    function setWheelVolumeAdjust(value) {
        root.wheelVolumeAdjust = Boolean(value)
        root.persist()
    }

    // ---- 便捷动作:按当前步长调整音量 / 进度 ----
    // 播放器与直播播放器共用同一套步长与范围钳制(0–100)。
    function volumeBy(current, dir) {
        return Math.max(0, Math.min(100, Math.round(current) + dir * root.volumeStepPercent))
    }
}
