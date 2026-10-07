import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "flyingpizza.llm-stats"
  ipcTarget: ""
  manageIpc: false

  property var snapshot: Model.emptySnapshot()
  property var bar: null
  property var settings: ({})
  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color foreground: bar ? bar.foreground : Color.popups.text
  readonly property color accent: Color.accent
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Color.muted
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property var barSettings: ({
    showPrompt: Model.isOn(root.settings && root.settings.showPrompt !== undefined ? root.settings.showPrompt : "On", true),
    showDecode: Model.isOn(root.settings && root.settings.showDecode !== undefined ? root.settings.showDecode : "On", true),
    compact: true
  })
  readonly property var rows: Model.panelData(root.snapshot, root.barSettings)

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem ? root.anchorItem : root
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: column
          width: scroll.width
          spacing: Style.space(10)

          Row {
            spacing: Style.space(8)

            Text {
              text: "🤖"
              font.pixelSize: Style.font.title
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              text: "LLM Stats"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          PanelSeparator { foreground: root.foreground }

          Repeater {
            model: root.rows

            Row {
              required property var modelData
              width: parent.width
              spacing: Style.space(10)

              Text {
                text: modelData.label + ":"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: (modelData.emoji ? modelData.emoji + "  " : "") + modelData.value
                color: modelData.label === "Status" && modelData.value === "Offline"
                     ? root.urgent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }

          Text {
            width: parent.width
            text: "Click or press Esc to close"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }
}
