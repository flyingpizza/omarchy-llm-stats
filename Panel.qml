// LLM Stats — Detail panel opened on click
// Shows model name, uptime, token counts, and speeds

import QtQuick 2.15
import Quickshell 1.0
import "../Model.js" as Model

Quickshell.Panel {
    id: root
    width: 320
    height: 200
    position: "top"
    alignment: Qt.AlignHCenter

    property var data: []

    Column {
        anchors {
            fill: parent
            margins: 16
            spacing: 12
        }

        // Header
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            Label {
                text: "🤖"
                font.pixelSize: 20
            }
            Label {
                text: "LLM Stats"
                font.bold: true
                font.pixelSize: 14
            }
        }

        Divider { anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 8 } }

        // Model info
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            Label { text: "Model:"; font.bold: true; color: theme.muted }
            Label {
                text: root.data.length > 0 ? root.data[0].value : "—"
                elide: Text.ElideMiddle
                maximumLineCount: 1
            }
        }

        // Status
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            Label { text: "Status:"; font.bold: true; color: theme.muted }
            Label {
                text: (root.data.length > 1 && root.data[1].emoji) ? root.data[1].emoji : ""
                font.pixelSize: 16
            }
            Label {
                text: root.data.length > 1 ? root.data[1].value : "—"
                color: root.data.length > 1 && root.data[1].value === "Active"
                       ? theme.accent : theme.urgent
            }
        }

        // Uptime
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            Label { text: "Uptime:"; font.bold: true; color: theme.muted }
            Label {
                text: root.data.length > 2 ? root.data[2].value : "—"
            }
        }

        Divider { anchors { top: "Uptime".bottom; left: parent.left; right: parent.right; topMargin: 8 } }

        // Prompt stats
        Label {
            text: "Prompt Processing"
            font.bold: true
            font.pixelSize: 12
            color: theme.accent
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            Label { text: "Tokens:"; font.bold: true; color: theme.muted }
            Label {
                text: root.data.length > 3 ? root.data[3].value : "—"
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            Label { text: "Speed:"; font.bold: true; color: theme.muted }
            Label {
                text: root.data.length > 4 ? root.data[4].value : "—"
            }
        }

        Divider { anchors { top: "Speed".bottom; left: parent.left; right: parent.right; topMargin: 8 } }

        // Decode stats
        Label {
            text: "Decoding"
            font.bold: true
            font.pixelSize: 12
            color: theme.accent
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            Label { text: "Tokens:"; font.bold: true; color: theme.muted }
            Label {
                text: root.data.length > 5 ? root.data[5].value : "—"
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            Label { text: "Speed:"; font.bold: true; color: theme.muted }
            Label {
                text: root.data.length > 6 ? root.data[6].value : "—"
            }
        }
    }

    Component.onCompleted: {
        // Data is passed in via onClicked handler on the bar widget
    }
}
