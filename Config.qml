pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    // ---- Geometry ----
    readonly property int iconSize: 44          // icon pixel size
    readonly property int cellPadding: 2        // padding around each icon inside its cell
    readonly property int spacing: 2            // gap between cells
    readonly property int dockPadding: 4        // padding inside the dock background
    readonly property int bottomMargin: 12      // gap between dock and screen edge
    readonly property int radius: 10           // dock background corner radius

    readonly property int cellSize: iconSize + cellPadding * 2

    // ---- Edge corners ----
    // Inverted (concave) corners that flare the dock into the screen edge, so
    // it looks like it grows out of the edge rather than ending in a hard
    // vertical line. Only drawn when the dock is actually flush with the edge,
    // which is what autoHide does; a floating dock has nothing to blend into.
    readonly property bool edgeCorners: true
    readonly property int cornerSize: 12

    // While the dock is only partially shown, the rounded top corner and the
    // edge fillet compete for the same sliver of height. This is the share the
    // fillet may claim; the rounded corner takes the rest. Lower = rounder
    // sliver with a subtler flare, 0 = no flare until it expands. Stops
    // mattering once the dock is fully out and both reach full size.
    readonly property real peekFilletShare: 0.25

    // ---- Source ----
    // "kickoff"     -> the Favorites list in the Application Launcher menu
    // "taskmanager" -> the pinned launchers on the Plasma task manager
    readonly property string source: "kickoff"

    // ---- Auto-hide ----
    // Slide the dock down until only a sliver is left, and bring it back when
    // the pointer reaches the bottom edge.
    readonly property bool autoHide: true
    readonly property int peekHeight: 8         // strip left visible when hidden
    // Pointer-catching strip along the screen edge. Kept at least as tall as
    // peekHeight so the dock isn't fiddly to summon; it's invisible either way.
    readonly property int triggerHeight: 8
    readonly property int hideDelay: 250        // ms of no pointer before hiding
    // Grace period after revealing during which a momentary "nothing hovered"
    // is ignored. Sliding the plate out from under a stationary pointer briefly
    // looks like the pointer left, which would otherwise bounce the dock.
    readonly property int revealGrace: 300
    readonly property int slideDuration: 100

    // ---- Behaviour ----
    // true  -> dock reserves screen space (windows won't go under it)
    // false -> dock floats above windows without reserving space
    readonly property bool reserveSpace: false

    // Magnify icons on hover, like the macOS dock.
    readonly property bool hoverMagnify: true
    readonly property real hoverScale: 1.22

    // ---- Appearance ----
    // Background colour and its opacity, kept separate so you can tune
    // translucency without hand-editing hex alpha.
    readonly property color backgroundColor: "#1c1f26"
    readonly property real backgroundOpacity: 0.8   // 0 = invisible, 1 = solid

    readonly property color background: Qt.rgba(
        backgroundColor.r, backgroundColor.g, backgroundColor.b, backgroundOpacity)

    // Hairline outline traced around the whole dock, fillets included.
    readonly property color border: "#33ffffff"
    readonly property real borderWidth: 1
    readonly property color hoverHighlight: "#22ffffff"
    readonly property color dragHighlight: "#33ffffff"
    readonly property color tooltipBackground: "#f01c1f26"
    readonly property color tooltipText: "#ffffff"
}
