import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: keyboard
    visible: false
    height: 300
    color: "#f0f0f0"
    border.color: "#cccccc"
    border.width: 1
    
    // 性能优化设置（修复闪烁和文字消失问题）
    clip: false  // 禁用裁剪避免闪烁
    layer.enabled: false  // 禁用分层渲染减少GPU负担
    
    // 整体平滑设置
    smooth: true

    property var targetInput: null

    function show(inputField) {
        targetInput = inputField
        visible = true
    }

    function hide() {
        visible = false
        if (targetInput) {
            targetInput.focus = false
        }
        targetInput = null
    }

    function appendText(str) {
        if (targetInput) {
            // 关键修复：在光标位置插入字符，而不是在末尾追加
            var cursorPos = targetInput.cursorPosition
            var text = targetInput.text
            targetInput.text = text.substring(0, cursorPos) + str + text.substring(cursorPos)
            // 移动光标到插入字符之后
            targetInput.cursorPosition = cursorPos + str.length
        }
    }

    function deleteLastChar() {
        if (targetInput && targetInput.text.length > 0) {
            // 关键修复：从光标位置删除字符，而不是从末尾删除
            var cursorPos = targetInput.cursorPosition
            
            if (cursorPos > 0) {
                var text = targetInput.text
                // 删除光标前的一个字符（符合标准的删除键行为）
                targetInput.text = text.substring(0, cursorPos - 1) + text.substring(cursorPos)
                // 移动光标向前一个位置
                targetInput.cursorPosition = cursorPos - 1
            }
        }
    }

    function clearText() {
        if (targetInput) {
            targetInput.text = ""
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 5

        // 第一行：7 8 9
        RowLayout {
            Layout.fillWidth: true
            spacing: 5

            Repeater {
                model: ["7", "8", "9"]
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45
                    color: mouseArea.pressed ? "#d0d0d0" : "#ffffff"
                    border.color: "#cccccc"
                    border.width: 1
                    radius: 5

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        font.pixelSize: 28
                        font.bold: true
                        
                        // 字体渲染优化（修复闪烁和文字消失问题）
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        onClicked: {
                            keyboard.appendText(modelData)
                        }
                    }
                }
            }
        }

        // 第二行：4 5 6
        RowLayout {
            Layout.fillWidth: true
            spacing: 5

            Repeater {
                model: ["4", "5", "6"]
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45
                    color: mouseArea.pressed ? "#d0d0d0" : "#ffffff"
                    border.color: "#cccccc"
                    border.width: 1
                    radius: 5

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        font.pixelSize: 28
                        font.bold: true
                        
                        // 字体渲染优化（修复闪烁和文字消失问题）
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        onClicked: {
                            keyboard.appendText(modelData)
                        }
                    }
                }
            }
        }

        // 第三行：1 2 3
        RowLayout {
            Layout.fillWidth: true
            spacing: 5

            Repeater {
                model: ["1", "2", "3"]
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45
                    color: mouseArea.pressed ? "#d0d0d0" : "#ffffff"
                    border.color: "#cccccc"
                    border.width: 1
                    radius: 5

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        font.pixelSize: 28
                        font.bold: true
                        
                        // 字体渲染优化（修复闪烁和文字消失问题）
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        onClicked: {
                            keyboard.appendText(modelData)
                        }
                    }
                }
            }
        }

        // 第四行：. 0 - 删除
        RowLayout {
            Layout.fillWidth: true
            spacing: 5

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 45
                color: dotMouseArea.pressed ? "#d0d0d0" : "#ffffff"
                border.color: "#cccccc"
                border.width: 1
                radius: 5

                Text {
                    anchors.centerIn: parent
                    text: "."
                    font.pixelSize: 28
                    font.bold: true
                    
                    // 字体渲染优化（修复闪烁和文字消失问题）
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                }

                MouseArea {
                    id: dotMouseArea
                    anchors.fill: parent
                    onClicked: {
                        if (targetInput && !targetInput.text.includes(".")) {
                            keyboard.appendText(".")
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 45
                color: zeroMouseArea.pressed ? "#d0d0d0" : "#ffffff"
                border.color: "#cccccc"
                border.width: 1
                radius: 5

                Text {
                    anchors.centerIn: parent
                    text: "0"
                    font.pixelSize: 28
                    font.bold: true
                    
                    // 字体渲染优化（修复闪烁和文字消失问题）
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                }

                MouseArea {
                    id: zeroMouseArea
                    anchors.fill: parent
                    onClicked: {
                        keyboard.appendText("0")
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 45
                color: minusMouseArea.pressed ? "#d0d0d0" : "#ffffff"
                border.color: "#cccccc"
                border.width: 1
                radius: 5

                Text {
                    anchors.centerIn: parent
                    text: "-"
                    font.pixelSize: 28
                    font.bold: true
                    
                    // 字体渲染优化（修复闪烁和文字消失问题）
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                }

                MouseArea {
                    id: minusMouseArea
                    anchors.fill: parent
                    onClicked: {
                        if (targetInput) {
                            var text = targetInput.text

                            // 关键修复：智能处理负号输入
                            if (text.includes("-")) {
                                // 如果已经有负号，不能再次输入
                                return
                            }

                            // 如果没有负号，自动在开头插入负号
                            // 不管光标在哪里，负号都应该在最前面
                            targetInput.text = "-" + text
                            // 光标保持在相对位置（负号后面）
                            targetInput.cursorPosition = targetInput.cursorPosition + 1
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 45
                color: delMouseArea.pressed ? "#d0d0d0" : "#ffcccc"
                border.color: "#cccccc"
                border.width: 1
                radius: 5

                Text {
                    anchors.centerIn: parent
                    text: "删除"
                    font.pixelSize: 24
                    font.bold: true
                    
                    // 字体渲染优化（修复闪烁和文字消失问题）
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                }

                MouseArea {
                    id: delMouseArea
                    anchors.fill: parent
                    onClicked: {
                        keyboard.deleteLastChar()
                    }
                }
            }
        }

        // 第五行：清除 完成
        RowLayout {
            Layout.fillWidth: true
            spacing: 5

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 45
                color: clearMouseArea.pressed ? "#d0d0d0" : "#ffaaaa"
                border.color: "#cccccc"
                border.width: 1
                radius: 5

                Text {
                    anchors.centerIn: parent
                    text: "清空"
                    font.pixelSize: 24
                    font.bold: true
                    
                    // 字体渲染优化（修复闪烁和文字消失问题）
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                }

                MouseArea {
                    id: clearMouseArea
                    anchors.fill: parent
                    onClicked: {
                        keyboard.clearText()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 45
                color: doneMouseArea.pressed ? "#3d8b40" : "#4CAF50"
                border.color: "#2d6a30"
                border.width: 1
                radius: 5

                Text {
                    anchors.centerIn: parent
                    text: "完成"
                    font.pixelSize: 24
                    font.bold: true
                    color: "white"
                    
                    // 字体渲染优化（修复闪烁和文字消失问题）
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                }

                MouseArea {
                    id: doneMouseArea
                    anchors.fill: parent
                    onClicked: {
                        keyboard.hide()
                    }
                }
            }
        }
    }
}