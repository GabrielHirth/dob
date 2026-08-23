// DOB desktop splash — red-bold, animated.
// Derived from art/desktop-splash.svg. Self-contained QtQuick Plasma splash.
// Boot splash stays static blue with subtle red aurora (no red frame at boot).
// Red goes BOLD here, on the live desktop splash.

import QtQuick 2.0

Rectangle {
    id: root
    color: "#21486F"
    anchors.fill: parent

    // Blue glass field gradient (matches desktop-splash.svg "field").
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#A9CFEF" }
            GradientStop { position: 0.55; color: "#3A6EA5" }
            GradientStop { position: 1.0; color: "#21486F" }
        }
    }

    // Animated bold red accent sweep (drives desktop-splash.svg id="accentSweep").
    Rectangle {
        id: accentSweep
        width: parent.width * 0.28
        height: parent.height
        color: "#E63950"
        opacity: 0.0
        rotation: 18
        transformOrigin: Item.Center
        anchors.verticalCenter: parent.verticalCenter
        x: -width

        SequentialAnimation on x {
            running: true
            loops: Animation.Infinite
            PropertyAnimation {
                from: -accentSweep.width
                to: root.width
                duration: 2600
                easing.type: Easing.InOutSine
            }
            PauseAnimation { duration: 700 }
        }
        SequentialAnimation on opacity {
            running: true
            loops: Animation.Infinite
            PropertyAnimation { from: 0.0; to: 0.55; duration: 1300 }
            PropertyAnimation { from: 0.55; to: 0.0; duration: 1300 }
        }
    }

    // Centered logo panel.
    Item {
        id: panel
        width: 512
        height: 160
        anchors.centerIn: parent

        Rectangle {
            anchors.fill: parent
            radius: 26
            color: "#3A6EA5"
            border.color: "#BFE0FF"
            border.width: 1.5
        }

        // Bold red glow behind the wordmark.
        Rectangle {
            width: 340; height: 104
            radius: 52
            color: "#E63950"
            opacity: 0.85
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            y: parent.height * 0.44
        }

        // Red-bold DOB wordmark.
        Text {
            anchors.centerIn: parent
            text: "DOB"
            font.family: "Arial, Helvetica, sans-serif"
            font.weight: Font.Bold
            font.pixelSize: 104
            letterSpacing: 6
            color: "#C0102A"
            style: Text.Raised
            styleColor: "#7A0A1E"
        }
    }
}
