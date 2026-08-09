pragma Singleton
import QtQuick

// Design tokens for the banner-style dark-neon look. FullView pushes the
// system palette + the followSystemTheme config in here at load; every view
// reads only these tokens, never Kirigami colors directly.
QtObject {
    id: t

    // fed by FullView (Kirigami.Theme is context-attached, unavailable here)
    property bool followSystem: false
    property color sysWindow: "#1b1e20"
    property color sysView: "#1b1e20"
    property color sysText: "#fcfcfc"
    property color sysHighlight: "#3daee9"

    // --- custom dark palette (banner) ---
    readonly property color _bg:        "#0a0e1a"
    readonly property color _surface:   "#111827"
    readonly property color _surfaceHi: "#1a2336"
    readonly property color _inputBg:   "#0d1322"
    readonly property color _text:      "#e6ecf7"

    // --- exposed tokens ---
    readonly property color bg:        followSystem ? sysWindow : _bg
    readonly property color surface:   followSystem ? Qt.lighter(sysView, 1.08) : _surface
    readonly property color surfaceHi: followSystem ? Qt.lighter(sysView, 1.18) : _surfaceHi
    readonly property color inputBg:   followSystem ? Qt.darker(sysView, 1.12) : _inputBg
    readonly property color text:      followSystem ? sysText : _text
    readonly property color textDim:   alpha(text, 0.65)
    readonly property color textFaint: alpha(text, 0.40)
    readonly property color border:    alpha(text, 0.08)
    readonly property color borderHi:  alpha(text, 0.18)

    readonly property real radiusS: 6
    readonly property real radiusM: 10
    readonly property real radiusL: 14

    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
}
