import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "flyingpizza.llm-stats"

  property var snapshot: Model.emptySnapshot()

  readonly property int refreshSec: Math.max(1, parseInt(setting("refreshIntervalSec", 2), 10) || 2)
  readonly property string serverUrl: setting("serverUrl", "http://localhost:5800")
  readonly property bool showPrompt: Model.isOn(setting("showPrompt", "On"), true)
  readonly property bool showDecode: Model.isOn(setting("showDecode", "On"), true)
  readonly property bool compact: Model.isOn(setting("compact", "On"), true)
  readonly property string collector: Model.fileUrlToPath(Qt.resolvedUrl("collect.py"))
  readonly property var barDisplay: Model.formatCompactBar(root.snapshot, {
    showPrompt: root.showPrompt,
    showDecode: root.showDecode,
    compact: root.compact
  })
  readonly property string barTooltip: Model.buildTooltip(root.snapshot, {
    showPrompt: root.showPrompt,
    showDecode: root.showDecode
  })

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("snapshot" in target) target.snapshot = root.snapshot
  }

  function applySnapshot(raw) {
    var next = Model.parseSnapshot(raw)
    if (!next) return
    root.snapshot = next
    if (panelLoader.item && "snapshot" in panelLoader.item)
      panelLoader.item.snapshot = next
  }

  function refresh() {
    if (!collectProc.running) collectProc.running = true
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.open) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  visible: root.barDisplay.text !== ""

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()
  onSnapshotChanged: injectPanel()

  Process {
    id: collectProc
    command: ["python3", root.collector, "--server-url", root.serverUrl, "--interval", String(root.refreshSec)]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applySnapshot(text)
    }
  }

  Timer {
    interval: root.refreshSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "flyingpizza.llm-stats"

    function refresh(): void { root.refresh() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: root.barDisplay.text !== ""
    tooltipText: root.barTooltip
    horizontalMargin: 8.75
    verticalPadding: 8.75
    fixedWidth: root.vertical ? -1 : Math.max(12, statsText.implicitWidth + scaledHorizontalMargin * 2)
    fixedHeight: root.vertical ? Math.max(Style.bar.iconSlot, statsText.implicitHeight) : -1
    useActiveColor: true
    active: root.snapshot.error !== null

    onPressed: function(b) { root.togglePanel() }

    Row {
      id: statsRow
      anchors.centerIn: parent
      spacing: Style.space(4)

      Text {
        id: statsText
        text: root.barDisplay.text
        color: button.active && button.useActiveColor ? button.activeColor : button.foreground
        font.family: button.fontFamily
        font.pixelSize: Style.font.body
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }
}
