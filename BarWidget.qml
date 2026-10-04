// LLM Stats — Bar widget for omarchy shell
// Displays real-time token generation speed from llama.cpp
// Shows combined prompt + decode throughput with emoji

import QtQuick 2.15
import Quickshell 1.0
import Quickshell.Io
import "../Model.js" as Model

// Panel — detail view opened on click
Quickshell.Panel {
    id: panel
    // Panel dimensions and positioning are defined in Panel.qml
}

// Data source — polls collect.py periodically
Process {
    id: statsProcess
    command: [
        "python3",
        Model.fileUrlToPath(%pluginDir%/collect.py),
        "--server-url", settings.serverUrl || "http://localhost:5802"
    ]
    stdout: StdioCollector {
        waitForEnd: true
        onStreamFinished: function(text) {
            var raw = text
            if (!raw.trim()) return

            var snapshot = Model.parseSnapshot(raw)
            if (snapshot && snapshot.ok) {
                barData = snapshot
            } else {
                barData = Model.emptySnapshot()
                barData.error = snapshot?.error || "Server unreachable"
            }
        }
    }

    Timer {
        id: timer
        interval: (Number(settings.refreshIntervalSec) || 2) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            barData = Model.getCompactBarData(barData, settings);
        }
    }
}

// The visible bar widget
Quickshell.BarWidget {
    id: root
    anchors.horizontalCenter: parent?.horizontalCenter ?? undefined

    property var barData: Model.emptySnapshot()

    // Get display data from Model.js
    function getDisplayData() {
        return Model.formatCompactBar(root.barData, {
            showPrompt: settings.showPrompt ?? "On",
            showDecode: settings.showDecode ?? "On",
            compact: settings.compact ?? "On"
        })
    }

    displayText: getDisplayData().text
    tooltipText: getDisplayData().tooltip

    // Click opens detail panel
    onClicked: {
        panel.serverUrl = settings.serverUrl || "http://localhost:5802"
        panel.data = Model.panelData(root.barData, {
            showPrompt: settings.showPrompt ?? "On",
            showDecode: settings.showDecode ?? "On"
        })
        panel.open()
    }

    // Theme-aware colors — follows omarchy accent system
    Label {
        anchors.fill: parent
        text: root.displayText
        font.family: "JetBrainsMono Nerd Font, JetBrainsMono NF"
        font.pixelSize: root.fontSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        // Dynamic color based on state
        color: {
            if (!root.barData.ok || root.barData.error)
                theme.urgent
            else if (root.barData.decode?.per_second !== null &&
                     root.barData.decode.per_second > 40)
                theme.accent
            else
                theme.muted
        }
    }
}
