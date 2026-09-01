import Quickshell
import QtQuick
import QtQuick.Effects

// The visual for one dock cell: highlight plate + application icon.
Item {
    id: root

    required property var entry
    property bool hovered: false
    property bool dragging: false

    // Sources to try in order; advance past any that fail to load.
    readonly property var sources: IconResolver.candidates(entry)
    property int attempt: 0
    readonly property string iconSource: attempt < sources.length ? sources[attempt] : ""

    onSourcesChanged: attempt = 0

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: root.dragging ? Config.dragHighlight
             : root.hovered  ? Config.hoverHighlight
             : "transparent"

        Behavior on color {
            ColorAnimation { duration: 120 }
        }
    }

    Image {
        id: icon

        anchors.centerIn: parent
        width: Config.iconSize
        height: Config.iconSize

        // Render at the magnified size so scaling up stays crisp.
        sourceSize.width: Math.round(Config.iconSize * Config.hoverScale)
        sourceSize.height: Math.round(Config.iconSize * Config.hoverScale)

        asynchronous: true
        fillMode: Image.PreserveAspectFit
        source: root.iconSource

        onStatusChanged: {
            if (status === Image.Error && root.attempt < root.sources.length - 1) root.attempt++;
        }

        scale: Config.hoverMagnify && root.hovered && !root.dragging ? Config.hoverScale : 1.0

        Behavior on scale {
            NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
        }
    }

    // Soft drop shadow while the icon is being carried.
    MultiEffect {
        anchors.fill: icon
        source: icon
        visible: root.dragging
        shadowEnabled: true
        shadowBlur: 0.7
        shadowColor: "#aa000000"
        shadowVerticalOffset: 3
    }
}
