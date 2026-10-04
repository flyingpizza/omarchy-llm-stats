// LLM Stats — Detail panel opened on click
// Shows model name, uptime, token counts, and speeds

import QtQuick 2.15
import Quickshell 1.0
import Quickshell.Io
import "../Model.js" as Model

Quickshell.Panel {
    id: root
    width: 320
    height: 200
    position: "top"
    alignment: Qt.AlignHCenter

    property var data: []
    property string serverUrl: "http://localhost:5802"

    // Properties to display current/maximum speed from the collect.py process
    property number currentValue: 0
    property number maximumValue: 1
    property string showPrompt: "On"
    property string showDecode: "On"

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

        Divider { anchors.left: parent.left; anchors.right: parent.right; anchors.topMargin: 8 }

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

        Divider { anchors.left: parent.left; anchors.right: parent.right; anchors.topMargin: 8 }

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

        Divider { anchors.left: parent.left; anchors.right: parent.right; anchors.topMargin: 8 }

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

// Process to run collect.py and poll its JSON output
Process {
    id: statsProcess
    command: [
        "python3",
        Model.fileUrlToPath(%pluginDir%/collect.py),
        "--server-url", root.serverUrl || "http://localhost:5802"
    ]
    stdout: StdioCollector {
        waitForEnd: true
        onStreamFinished: function(text) {
            var raw = text
            if (!raw.trim()) return

            var data = JSON.parse(raw)
            root.data = Model.panelData(data, {
                showPrompt: root.showPrompt || "On",
                showDecode: root.showDecode || "On"
            })
            if (data.prompt_speed !== undefined && data.prompt_speed >= 0) {
                currentValue = data.prompt_speed
                if (currentValue > maximumValue) {
                    maximumValue = currentValue
                }
            } else if (data.decode_speed !== undefined && data.decode_speed >= 0) {
                currentValue = data.decode_speed
                if (currentValue > maximumValue) {
                    maximumValue = currentValue
                }
            }
        }
    }

    Timer {
        id: timer
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            statsProcess.start()
        }
    }
}
