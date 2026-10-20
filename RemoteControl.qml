import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

ScrollView {
    id: root

    // 字体大小 - 手机显示需要更大的字体
    property int fontSmall: 24
    property int fontNormal: 28
    property int fontLarge: 32

    // 当前tab索引（从Main.qml传入）
    property int currentTab: 3

    // 摇杆数据
    property real joyRoll: 0
    property real joyPitch: 0
    property real joyYaw: 0
    property real joyThr: 0

    // 状态数据
    property string voltageText: "---"
    property string modeText: "---"

    // 同步远端模式时置true，避免控件onToggled反向发送命令
    property bool syncingMode: false
    // 点击返航/灯光后2秒内不根据远端数据更新对应状态
    property bool returnHomeHold: false
    property bool lightHold: false

    Timer {
        id: returnHomeHoldTimer
        interval: 2000
        onTriggered: root.returnHomeHold = false
    }

    Timer {
        id: lightHoldTimer
        interval: 2000
        onTriggered: root.lightHold = false
    }

    // ===== 固件刷机流程: 发命令 → 选文件 → 等2秒 → dfu-util刷机 → MCU自动重启 =====
    property bool flashInProgress: false

    FileDialog {
        id: firmwareDialog
        title: "选择固件文件"
        nameFilters: ["固件文件 (*.bin *.dfu *.hex *.img *.elf)", "所有文件 (*)"]
        currentFolder: "file:///home/bitstream/"
        onAccepted: {
            appendLocalLog("已选择固件: " + firmwareDialog.selectedFile)
            // 等待MCU进入DFU模式后再开始刷机
            flashWaitTimer.start()
        }
        onRejected: {
            root.flashInProgress = false
            // 用户取消选择，恢复30秒无数据关机看门狗
            remoteController.resumeWatchdog()
        }
    }

    Timer {
        id: flashWaitTimer
        interval: 2000
        onTriggered: {
            var localPath = firmwareDialog.selectedFile.toString()
            if (localPath.startsWith("file://")) {
                localPath = localPath.substring(7)  // 移除 "file://"，保留 "/"
            }
            remoteController.flashFirmware(localPath)
        }
    }

    Connections {
        target: remoteController
        function onFirmwareFlashOutput(line) {
            appendLocalLog("[dfu-util] " + line)
        }
        function onFirmwareFlashFinished(success, message) {
            root.flashInProgress = false
            appendLocalLog(success ? ("[dfu-util] " + message)
                                   : ("[dfu-util] 刷机失败: " + message))
        }
    }

    // 原始数据日志（节流批量刷新，避免高频数据压垮UI）
    property int maxRawLines: 100
    property var pendingLines: []

    Timer {
        id: logFlushTimer
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            if (root.pendingLines.length === 0) return
            var lines = root.pendingLines
            root.pendingLines = []
            for (var i = 0; i < lines.length; i++) {
                rawLogModel.append({ lineText: lines[i] })
            }
            if (rawLogModel.count > root.maxRawLines) {
                rawLogModel.remove(0, rawLogModel.count - root.maxRawLines)
            }
            // 每批只滚动一次到最新数据
            rawLogView.positionViewAtEnd()
        }
    }

    function updateJoystick(roll, pitch, yaw, thr) {
        joyRoll = roll
        joyPitch = pitch
        joyYaw = yaw
        joyThr = thr
    }

    function updateBattery(voltage) {
        voltageText = voltage.toFixed(2)
    }

    function updateMode(mode) {
        var raw = mode.trim()
        var rawLower = raw.toLowerCase()

        // 数字协议: 1=遥控车, 2=飞机, 3=返航；同时兼容英文模式名
        var m
        if (raw === "1" || rawLower === "car") {
            m = "遥控车"
        } else if (raw === "2" || rawLower === "plane" || rawLower === "aircraft") {
            m = "飞机"
        } else if (raw === "3" || rawLower === "rth" || rawLower === "home") {
            m = "返航"
        } else {
            m = raw
        }
        modeText = m

        // 返航状态同步checkbox（不触发发送）；点击后2秒内忽略远端状态
        syncingMode = true
        if (!returnHomeHold) {
            returnHomeBox.checked = (m === "返航")
        }
        syncingMode = false
    }

    function updateLight(state) {
        var s = state.toLowerCase()
        // 点击后2秒内忽略远端状态
        if (lightHold) return
        syncingMode = true
        if (s === "1" || s === "on" || s === "true" || s === "open") {
            lightBox.checked = true
        } else if (s === "0" || s === "off" || s === "false" || s === "close") {
            lightBox.checked = false
        }
        syncingMode = false
    }

    function appendRawLines(lines) {
        pendingLines = pendingLines.concat(lines)
    }

    function appendLocalLog(text) {
        appendRawLines([text])
    }

    Component.onCompleted: {
        // 自动打开串口
        remoteController.openPort()
    }

    contentWidth: availableWidth
    // 页面内容不足一屏时撑满，超过一屏时可滚动
    contentHeight: Math.max(contentColumn.height, availableHeight)

    ColumnLayout {
        id: contentColumn
        width: root.availableWidth
        // 内容不足一屏时撑满屏幕高度，让日志框占据剩余空间
        height: Math.max(implicitHeight, root.availableHeight)
        spacing: 10

        // 串口连接状态行
        RowLayout {
            Layout.fillWidth: true
            spacing: 15

            Rectangle {
                width: 24
                height: 24
                radius: 12
                color: remoteController.connected ? "#44cc44" : "#cc4444"
            }

            Label {
                text: remoteController.connected ? "串口已连接 (/dev/ttyGS0)" : "串口未连接（自动重试中）"
                font.pixelSize: fontSmall
                font.bold: true
                color: remoteController.connected ? "darkgreen" : "darkred"
            }

            Item { Layout.fillWidth: true }
        }

        // 状态显示行: 电压 / 模式 / 灯光(checkbox)
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Label {
                text: "电压: " + voltageText + "V"
                font.pixelSize: fontNormal
                font.bold: true
                color: "darkorange"
                Layout.fillWidth: true
            }

            Label {
                text: "模式: " + modeText
                font.pixelSize: fontNormal
                font.bold: true
                color: "darkblue"
                Layout.fillWidth: true
            }

            CheckBox {
                id: lightBox
                text: "灯光"
                font.pixelSize: fontNormal
                Layout.rightMargin: 20
                onToggled: if (!syncingMode) {
                    remoteController.setLight(checked)
                    appendLocalLog("设置灯光: " + (checked ? "开" : "关"))
                    // 点击后2秒内不更新灯光状态
                    lightHold = true
                    lightHoldTimer.restart()
                }
            }
        }

        // 命令行: 切换模式 + 返航 + 更新固件
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Button {
                id: changeModeButton
                text: "切换模式"
                font.pixelSize: fontSmall
                Layout.preferredHeight: 60
                Layout.leftMargin: 20

                background: Rectangle {
                    radius: 4
                    border.color: changeModeButton.enabled ? "#666666" : "#aa6622"
                    // 点击后变橙色并禁用，2秒后恢复
                    color: changeModeButton.enabled ? "#e0e0e0" : "#ff9944"
                }

                onClicked: {
                    remoteController.changeMode()
                    appendLocalLog("发送切换模式命令")
                    enabled = false
                    recoverTimer.restart()
                }

                Timer {
                    id: recoverTimer
                    interval: 2000
                    onTriggered: changeModeButton.enabled = true
                }
            }

            CheckBox {
                id: returnHomeBox
                text: "返航"
                font.pixelSize: fontSmall
                onToggled: if (!syncingMode) {
                    if (checked) {
                        remoteController.returnHome()
                        appendLocalLog("发送返航命令")
                    } else {
                        remoteController.cancelReturnHome()
                        appendLocalLog("发送取消返航命令")
                    }
                    // 点击后2秒内不更新返航状态
                    returnHomeHold = true
                    returnHomeHoldTimer.restart()
                }
            }

            Item { Layout.fillWidth: true }

            Button {
                text: root.flashInProgress ? "刷机中..." : "更新固件"
                enabled: !root.flashInProgress
                font.pixelSize: fontSmall
                Layout.preferredHeight: 60
                Layout.rightMargin: 20
                onClicked: {
                    root.flashInProgress = true
                    // 先发送进入刷机模式命令，再选择固件文件
                    remoteController.updateFirmware()
                    appendLocalLog("发送固件更新命令，请选择固件文件")
                    firmwareDialog.open()
                }
            }
        }

        // 攀爬模式力度: 0-100
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Label {
                text: "攀爬力度:"
                font.pixelSize: fontSmall
            }

            Label {
                text: climbSlider.value.toFixed(0)
                font.pixelSize: fontSmall
                font.bold: true
                color: "darkorange"
            }

            Slider {
                id: climbSlider
                from: 0
                to: 100
                value: 0
                stepSize: 1
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                // 松开手指时发送（部分Qt版本Slider无released信号，用pressedChanged实现）
                onPressedChanged: if (!pressed) {
                    remoteController.setClimbPower(value)
                    appendLocalLog("设置攀爬力度: " + value.toFixed(0))
                }
            }
        }

        // 摇杆数值（文本显示）
        Label {
            Layout.fillWidth: true
            text: "Roll: " + joyRoll.toFixed(1) +
                  "   Pitch: " + joyPitch.toFixed(1) +
                  "   Yaw: " + joyYaw.toFixed(1) +
                  "   Thr: " + joyThr.toFixed(1)
            font.pixelSize: fontSmall
            color: "#555555"
        }

        Separator {}

        // 原始数据日志
        Label {
            text: "串口原始数据"
            font.bold: true
            font.pixelSize: fontSmall
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true  // 占据页面剩余空间，不超出屏幕
            Layout.minimumHeight: 120
            color: "#ffffff"
            border.color: "#cccccc"
            border.width: 1
            clip: true

            ListModel { id: rawLogModel }

            ListView {
                id: rawLogView
                anchors.fill: parent
                anchors.margins: 5
                model: rawLogModel
                clip: true
                reuseItems: true
                boundsBehavior: Flickable.StopAtBounds

                delegate: Text {
                    text: model.lineText
                    font.family: "Consolas"
                    font.pixelSize: 18
                    wrapMode: Text.Wrap
                    width: rawLogView.width - 10
                    color: "#333333"
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                }

                ScrollBar.vertical: ScrollBar { }
            }
        }
    }

    component Separator: Rectangle {
        Layout.fillWidth: true
        height: 2
        color: "#cccccc"
        Layout.topMargin: 5
        Layout.bottomMargin: 5
    }
}
