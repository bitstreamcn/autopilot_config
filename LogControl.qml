import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    // 字体大小 - 手机显示需要更大的字体
    property int fontSmall: 24
    property int fontNormal: 28
    property int fontLarge: 32

    property int maxLines: 200
    property int currentTab: 0  // 当前tab索引（从Main.qml传入）

    function addLog(text, type) {
        var color = "black"
        if (type === "error") color = "red"
        else if (type === "system") color = "blue"
        else if (type === "warning") color = "goldenrod"
        else if (type === "critical") color = "indianred"

        logModel.append({ text: text, textColor: color })

        if (logModel.count > maxLines) {
            logModel.remove(0, logModel.count - maxLines)
        }

        // 只在日志tab页面时刷新UI（避免其他页面闪烁）
        if (currentTab === 0) {  // 日志tab
            listView.positionViewAtEnd()
        }
    }

    function clearLog() {
        logModel.clear()
    }

    ListModel {
        id: logModel
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        spacing: 0  // 使用明确的margin控制间距

        // 顶部按钮区域 - 固定高度，不随内容变化
        RowLayout {
            id: buttonRow
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            Layout.minimumHeight: 60
            Layout.maximumHeight: 60  // 强制固定高度
            
            // 顶部边距
            Layout.topMargin: 10
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            Layout.bottomMargin: 10  // 底部边距作为与ListView的间距
            
            spacing: 10

            Button {
                text: "清空"
                font.pixelSize: fontLarge
                Layout.preferredHeight: 50
                Layout.preferredWidth: 100
                onClicked: root.clearLog()
            }

            Item { Layout.fillWidth: true }

            Label {
                text: "日志数量: " + logModel.count
                font.pixelSize: fontNormal
                Layout.alignment: Qt.AlignVCenter
            }
        }

        // 日志列表区域 - 填充剩余空间，但受顶部按钮限制
        Rectangle {
            id: logRect
            Layout.fillWidth: true
            Layout.fillHeight: true  // 填充剩余空间
            
            // 明确的边距
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            Layout.bottomMargin: 10
            
            border.color: "#cccccc"
            border.width: 1
            
            // 使用clip确保内容不超出边界
            clip: true  // 关键：启用裁剪，防止内容渲染到外部

            ListView {
                id: listView
                anchors.fill: parent
                anchors.margins: 5
                model: logModel
                
                // 性能优化设置（Qt 6）
                clip: true  // 关键修复：启用裁剪，防止向上滚动时覆盖按钮
                smooth: true  // 平滑滚动
                reuseItems: true  // Qt 6: 复用delegate项
                boundsBehavior: Flickable.StopAtBounds  // 停止在边界，不允许拖出
                
                // 明确的定位，防止向上扩展
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right

                delegate: Text {
                    text: model.text
                    color: model.textColor
                    font.family: "Consolas"
                    font.pixelSize: fontNormal
                    wrapMode: Text.Wrap
                    width: listView.width - 10
                    
                    // 字体渲染优化
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: parent.background = "lightgray"
                        onExited: parent.background = "transparent"
                        onClicked: {
                            // Copy to clipboard (requires Qt 6.4+)
                            if (typeof Clipboard !== 'undefined') {
                                Clipboard.text = model.text
                            }
                        }
                    }

                    property var background: "transparent"
                    Rectangle {
                        anchors.fill: parent
                        color: parent.background
                        z: -1
                    }
                }

                ScrollBar.vertical: ScrollBar { }
            }
        }
    }
}