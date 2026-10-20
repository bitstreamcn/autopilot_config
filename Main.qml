import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.VirtualKeyboard
import QtCore

Window {
    id: window
    width: Screen.width
    height: Screen.height
    visible: true
    title: qsTr("飞控调试工具")
    flags: Qt.Window | Qt.FramelessWindowHint

    // 全局字体大小 - 手机显示需要更大的字体
    property int fontSmall: 24
    property int fontNormal: 28
    property int fontLarge: 32

    // Context properties from main.cpp (直接使用注册的实例名)
    // tcpServer, protocolParser, displayProcessor, ipAddressService, packetBuilder, systemService

    // WiFi默认配置（保存值为空时恢复）
    property string defaultWifiSsid: "baicai001"
    property string defaultWifiPassword: "19820824"

    // WiFi配置持久化（输入变化自动保存，启动时自动恢复）
    Settings {
        id: wifiSettings
        property alias wifiSsid: ssidField.text
        property alias wifiPassword: passwordField.text
    }

    // 屏幕右上角浮动显示本机电池电量（未找到电池时隐藏，如开发机）
    Rectangle {
        id: batteryOverlay
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 6
        anchors.rightMargin: 6
        width: batteryRow.implicitWidth + 16
        height: batteryRow.implicitHeight + 8
        radius: 6
        color: "#aa000000"
        z: 999
        visible: batteryService.level >= 0

        Row {
            id: batteryRow
            anchors.centerIn: parent
            spacing: 8

            // 电池图标
            Item {
                width: 34
                height: 16
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {     // 外框
                    anchors.fill: parent
                    radius: 3
                    color: "transparent"
                    border.color: "white"
                    border.width: 1
                }
                Rectangle {     // 正极凸头
                    x: parent.width - 1
                    y: parent.height / 2 - 3
                    width: 4
                    height: 6
                    color: "white"
                }
                Rectangle {     // 电量填充
                    x: 2; y: 2
                    width: Math.max(0, (parent.width - 6) * batteryService.level / 100)
                    height: parent.height - 4
                    color: batteryService.level <= 20 ? "red"
                         : (batteryService.charging ? "limegreen" : "white")
                }
            }

            Label {
                text: batteryService.level + "%"
                color: "white"
                font.pixelSize: 20
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // 侧栏收缩状态
    property bool leftPanelCollapsed: false
    property bool rightPanelCollapsed: false
    property int leftPanelWidth: 280
    property int rightPanelWidth: 400

    property string rollValue: "---"
    property string pitchValue: "---"
    property string yawValue: "---"
    property string throttleValue: "---"
    property string controlThrValue: "---"
    property string controlRollPitchValue: "roll=--- pitch=---"
    property string controlYawValue: "---"
    property string locPosValue: "x=--- y=---"
    property string locVelValue: "vx=--- vy=---"
    property string flowTargetValue: "tx=--- ty=---"
    property string flowPosValue: "x=--- y=---"
    property string imuAccelValue: "ax=--- ay=--- az=---"
    property string imuGyroValue: "gx=--- gy=--- gz=---"
    property string imuAttitudeValue: "roll=--- pitch=--- yaw=---"
    property string imuAltVelValue: "alt=--- v=---"
    property string imuAccelUpValue: "accelup=---"
    property string destAltValue: "---"
    property string currentAltValue: "---"

    // 频率数据
    property string freq200Hz: "---"
    property string freqOnPacketIn: "---"
    property string freqOnRxDone: "---"
    property string freqResponse: "---"
    property string freqOnChannels: "---"
    property string freqLoop: "---"

    // 遥控数据 (来自日志解析)
    property string rcRollValue: "---"
    property string rcPitchValue: "---"
    property string rcYawValue: "---"
    property string rcThrottleValue: "---"

    // GPS数据
    property string gpsFixType: "---"
    property string gpsNumSV: "---"
    property string gpsFLon: "---"
    property string gpsFLat: "---"
    property string gpsHAcc: "---"
    property string gpsDs: "---"
    property string gpsDx: "---"
    property string gpsDy: "---"
    property string gpsHds: "---"
    property string gpsHx: "---"
    property string gpsHy: "---"

    Connections {
        target: tcpServer
        function onClientConnected(ipAddress, port, count) {
            logControl.addLog(displayProcessor.formatClientConnected(ipAddress, port, count), "system")
        }
        function onClientDisconnected(ipAddress, port, reason, count) {
            logControl.addLog(displayProcessor.formatClientDisconnected(ipAddress, port, reason, count), "system")
        }
        function onDataReceived(data, ipAddress, port) {
            // 处理 QVariant 包装的 QByteArray
            protocolParser.processDataFromVariant(data)
        }
        function onDataReceivedHex(hexData, length, ipAddress, port) {
            // 不显示原始十六进制数据，由协议解析器处理
        }
        function onServerStatusChanged(status) {
            logControl.addLog(displayProcessor.formatServerStatus(status), "system")
        }
        function onErrorOccurred(operation, errorMessage) {
            logControl.addLog(displayProcessor.formatError(operation, errorMessage), "error")
        }
    }

    // 脚本输出转发到日志（WiFi切换/连接等）
    Connections {
        target: systemService
        function onScriptOutput(name, line) {
            logControl.addLog("[" + displayProcessor.currentTime() + "] [" + name + "] " + line, "system")
        }
        function onScriptFinished(name, exitCode) {
            if (exitCode === 0) {
                logControl.addLog("[" + displayProcessor.currentTime() + "] [" + name + "] 执行完成", "system")
            } else {
                logControl.addLog("[" + displayProcessor.currentTime() + "] [" + name + "] 执行失败，退出码 " + exitCode, "error")
            }
        }
    }

    // 遥控器串口数据
    Connections {
        target: remoteController
        function onJoystickReceived(roll, pitch, yaw, thr) {
            remoteControl.updateJoystick(roll, pitch, yaw, thr)
        }
        function onBatteryReceived(voltage) {
            remoteControl.updateBattery(voltage)
        }
        function onModeReceived(mode) {
            remoteControl.updateMode(mode)
        }
        function onLightReceived(state) {
            remoteControl.updateLight(state)
        }
        function onRawLinesReceived(lines) {
            remoteControl.appendRawLines(lines)
        }
        function onPortOpened(device) {
            logControl.addLog("[" + displayProcessor.currentTime() + "] 遥控器串口已打开: " + device, "system")
        }
        function onPortError(error) {
            logControl.addLog("[" + displayProcessor.currentTime() + "] 遥控器串口错误: " + error, "error")
        }
        function onShutdownRequested(reason) {
            logControl.addLog("[" + displayProcessor.currentTime() + "] 遥控器: " + reason + "，正在关机...", "error")
        }
    }

    Connections {
        target: protocolParser
        function onImuAccelGyroReceived(ax, ay, az, gx, gy, gz) {
            timeoutManager.updateTimestamp("ImuAccelGyro")
            // 关键优化：只在IMU页面时更新全局property，减少全局渲染
            //if (tabBar.currentIndex === 2) 
            {  // IMU tab
                imuAccelValue = "ax=" + ax.toFixed(2) + " ay=" + ay.toFixed(2) + " az=" + az.toFixed(2)
                imuGyroValue = "gx=" + gx.toFixed(2) + " gy=" + gy.toFixed(2) + " gz=" + gz.toFixed(2)
                imuControl.updateAccelGyro(ax, ay, az, gx, gy, gz)
            }
        }
        function onImuAttitudeReceived(roll, pitch, yaw) {
            timeoutManager.updateTimestamp("ImuAttitude")
            // 关键优化：只在IMU页面时更新全局property
            //if (tabBar.currentIndex === 2) 
            {  // IMU tab
                imuAttitudeValue = "roll=" + roll.toFixed(2) + " pitch=" + pitch.toFixed(2) + " yaw=" + yaw.toFixed(2)
                imuControl.updateAttitude(roll, pitch, yaw)
            }
        }
        function onImuAltVelocityReceived(alt, v, accelUp) {
            timeoutManager.updateTimestamp("ImuAltVel")
            timeoutManager.updateTimestamp("ImuAccelUp")
            // 关键优化：只在IMU页面时更新全局property
            //if (tabBar.currentIndex === 2) 
            {  // IMU tab
                imuAltVelValue = "alt=" + alt.toFixed(2) + " v=" + v.toFixed(2)
                imuAccelUpValue = "accelup=" + accelUp.toFixed(2)
            }
        }
        function onControlThrReceived(thr, ctrlRoll, ctrlPitch, ctrlYaw) {
            timeoutManager.updateTimestamp("ControlThr")
            // 关键优化：只在IMU页面时更新全局property
            //if (tabBar.currentIndex === 2) 
            {  // IMU tab
                controlThrValue = "thr=" + thr.toFixed(2)
                controlRollPitchValue = "roll=" + ctrlRoll.toFixed(2) + " pitch=" + ctrlPitch.toFixed(2)
                controlYawValue = "yaw=" + ctrlYaw.toFixed(2)
            }
        }
        function onLocationDataReceived(x, y, vx, vy) {
            timeoutManager.updateTimestamp("LocationData")
            // 关键优化：只在IMU页面时更新全局property
            //if (tabBar.currentIndex === 2) 
            {  // IMU tab
                locPosValue = "x=" + x.toFixed(2) + " y=" + y.toFixed(2)
                locVelValue = "vx=" + vx.toFixed(2) + " vy=" + vy.toFixed(2)
            }
        }
        function onFlowDataReceived(tx, ty, x, y) {
            timeoutManager.updateTimestamp("FlowData")
            // 关键优化：只在IMU页面时更新全局property
            //if (tabBar.currentIndex === 2) 
            {  // IMU tab
                flowTargetValue = "tx=" + tx.toFixed(2) + " ty=" + ty.toFixed(2)
                flowPosValue = "x=" + x.toFixed(2) + " y=" + y.toFixed(2)
            }
        }
        function onDestAltDataReceived(destAlt, currentAlt) {
            timeoutManager.updateTimestamp("DestAlt")
            // 关键优化：只在IMU页面时更新全局property
            //if (tabBar.currentIndex === 2) 
            {  // IMU tab
                destAltValue = destAlt.toFixed(2)
                currentAltValue = currentAlt.toFixed(2)
            }
        }
        function onConfigDataReceived(name, value, dataType) {
            // dataType: 0 = GetValue响应, 1 = SetConfirm响应, 2 = SaveConfirm响应
            if (dataType === 0) {
                // GetValue响应 - 显示日志并更新参数列表
                displayProcessor.addSystemText("收到配置: " + name + " = " + value)
                // 关键修复：数据处理逻辑（停止Timer、继续下一个）应该总是执行
                // UI更新逻辑已经在ParameterControl.qml中使用缓冲机制控制
                parameterControl.updateParameter(name, value)  // 总是调用，处理数据接收逻辑
            } else if (dataType === 1) {
                // SetConfirm响应 - 参数设置确认
                displayProcessor.addSystemText("参数设置确认: " + name)
                // 关键修复：数据处理逻辑应该总是执行
                parameterControl.handleSetConfirm(name)  // 总是调用，处理保存确认逻辑
            } else if (dataType === 2) {
                // SaveConfirm响应 - 参数保存确认
                displayProcessor.addSystemText("配置保存成功")
                // 关键修复：数据处理逻辑应该总是执行
                parameterControl.handleSaveConfirm()  // 总是调用，处理保存完成逻辑
            }
        }
        function onRcDataReceived(roll, pitch, yaw, throttle) {
            timeoutManager.updateTimestamp("Roll")
            timeoutManager.updateTimestamp("Pitch")
            timeoutManager.updateTimestamp("Yaw")
            timeoutManager.updateTimestamp("Throttle")
            // 关键优化：只在右侧面板展开时更新全局property
            if (!rightPanelCollapsed) {
                rcRollValue = roll.toFixed(2)
                rcPitchValue = pitch.toFixed(2)
                rcYawValue = yaw.toFixed(2)
                rcThrottleValue = throttle.toFixed(2)
            }
        }
        function onFreqDataReceived(name, freq) {
            timeoutManager.updateTimestamp(name)
            // 关键优化：只在右侧面板展开时更新全局property
            if (!rightPanelCollapsed) {
                // freq已经是浮点数（从Stm32ProtocolParser.cpp传递）
                if (name === "200hz") freq200Hz = freq.toFixed(1) + " Hz"
                else if (name === "OnPacketIn") freqOnPacketIn = freq.toFixed(1) + " Hz"
                else if (name === "OnRxDone") freqOnRxDone = freq.toFixed(1) + " Hz"
                else if (name === "Response") freqResponse = freq.toFixed(1) + " Hz"
                else if (name === "OnPacketChannels") freqOnChannels = freq.toFixed(1) + " Hz"
                else if (name === "Application::Loop") freqLoop = freq.toFixed(1) + " Hz"
            }
        }
        function onGpsDataReceived(fixType, numSV, fLon, fLat, hAcc, ds, dx, dy, hds, hx, hy) {
            timeoutManager.updateTimestamp("Gps")
            // 关键优化：只在右侧面板展开时更新全局property
            if (!rightPanelCollapsed) {
                gpsFixType = fixType.toString()
                gpsNumSV = numSV.toString()
                gpsFLon = fLon.toFixed(6)
                gpsFLat = fLat.toFixed(6)
                gpsHAcc = hAcc.toString()
                gpsDs = ds.toFixed(2)
                gpsDx = dx.toFixed(2)
                gpsDy = dy.toFixed(2)
                gpsHds = hds.toFixed(2)
                gpsHx = hx.toFixed(2)
                gpsHy = hy.toFixed(2)
            }
        }
        function onProtocolError(reason, data) {
            // 使用参考程序的格式显示异常数据（包括十六进制和ASCII）
            var displayText = displayProcessor.formatAbnormalData(data, reason)
            logControl.addLog(displayText, "error")
        }
        function onLogFileDataReceived(data) {
            logControl.addLog(data, "system")
        }
        function onDataParsed(data, dataString, parseType) {
            // 使用参考程序的格式显示解析后的数据
            var displayText = displayProcessor.formatReceivedData(dataString, parseType)
            // 根据数据内容判断颜色
            var colorType = "normal"
            if (dataString.startsWith("[E]")) {
                colorType = "error"
            } else if (dataString.startsWith("[W]")) {
                colorType = "warning"
            } else if (dataString.startsWith("[I]")) {
                colorType = "system"
            }
            logControl.addLog(displayText, colorType)
        }
    }

    // 数据超时处理
    Connections {
        target: timeoutManager
        function onDataTimeout(key) {
            // 关键优化：只在对应的页面显示时才清空数据，减少全局渲染
            // 遥控数据和频率数据：只在右侧面板展开时清空
            if (!rightPanelCollapsed) {
                if (key === "Roll") rcRollValue = "---"
                else if (key === "Pitch") rcPitchValue = "---"
                else if (key === "Yaw") rcYawValue = "---"
                else if (key === "Throttle") rcThrottleValue = "---"
                else if (key === "200hz") freq200Hz = "---"
                else if (key === "OnPacketIn") freqOnPacketIn = "---"
                else if (key === "OnRxDone") freqOnRxDone = "---"
                else if (key === "Response") freqResponse = "---"
                else if (key === "OnPacketChannels") freqOnChannels = "---"
                else if (key === "Application::Loop") freqLoop = "---"
                else if (key === "Gps") {
                    gpsFixType = "---"
                    gpsNumSV = "---"
                    gpsFLon = "---"
                    gpsFLat = "---"
                    gpsHAcc = "---"
                    gpsDs = "---"
                    gpsDx = "---"
                    gpsDy = "---"
                    gpsHds = "---"
                    gpsHx = "---"
                    gpsHy = "---"
                }
            }

            // IMU页面数据：只在IMU页面时清空
            //if (tabBar.currentIndex === 2) 
            {  // IMU tab
                if (key === "ControlThr") {
                    controlThrValue = "---"
                    controlRollPitchValue = "roll=--- pitch=---"
                    controlYawValue = "---"
                }
                else if (key === "LocationData") {
                    locPosValue = "x=--- y=---"
                    locVelValue = "vx=--- vy=---"
                }
                else if (key === "FlowData") {
                    flowTargetValue = "tx=--- ty=---"
                    flowPosValue = "x=--- y=---"
                }
                else if (key === "ImuAccelGyro") {
                    imuAccelValue = "ax=--- ay=--- az=---"
                    imuGyroValue = "gx=--- gy=--- gz=---"
                }
                else if (key === "ImuAttitude") {
                    imuAttitudeValue = "roll=--- pitch=--- yaw=---"
                }
                else if (key === "ImuAltVel") {
                    imuAltVelValue = "alt=--- v=---"
                }
                else if (key === "ImuAccelUp") {
                    imuAccelUpValue = "accelup=---"
                }
                else if (key === "DestAlt") {
                    destAltValue = "---"
                    currentAltValue = "---"
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            id: mainRowLayout
            Layout.fillWidth: true
            Layout.preferredHeight: parent.height - (Qt.inputMethod.visible ? 300 : 0) - (numericKeyboard.visible ? 300 : 0)
            Layout.fillHeight: true
            spacing: 10

            // Left panel - IP list (可收缩)
            Rectangle {
                id: leftPanel
                Layout.preferredWidth: leftPanelCollapsed ? 40 : leftPanelWidth
                Layout.minimumWidth: 40
                Layout.fillHeight: true
                color: "#f0f0f0"
                border.color: "#cccccc"
                border.width: 1

                // 收缩按钮
                Rectangle {
                    id: leftCollapseBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    height: 80
                    color: leftCollapseBtnArea.pressed ? "#cccccc" : "#e0e0e0"
                    border.color: "#999999"
                    border.width: 1
                    z: 10

                    Text {
                        anchors.centerIn: parent
                        text: leftPanelCollapsed ? ">" : "<"
                        font.pixelSize: fontNormal
                        font.bold: true
                    }

                    MouseArea {
                        id: leftCollapseBtnArea
                        anchors.fill: parent
                        onClicked: {
                            leftPanelCollapsed = !leftPanelCollapsed
                        }
                    }
                }

                // 底部按钮：重启 + 关机 + 关闭显示器（图标按钮，固定在窗口底部）
                RowLayout {
                    id: bottomButtons
                    anchors.left: parent.left
                    anchors.leftMargin: leftPanelCollapsed ? 0 : 15
                    anchors.right: parent.right
                    anchors.rightMargin: leftPanelCollapsed ? 0 : 40
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: leftPanelCollapsed ? 0 : 15
                    height: 60
                    spacing: 10
                    visible: !leftPanelCollapsed

                    // 重启按钮（环形箭头图标，功能不变）
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60
                        color: rebootMouseArea.pressed ? "#666666" : "#888888"
                        border.color: "#555555"
                        border.width: 2
                        radius: 5

                        Canvas {
                            anchors.centerIn: parent
                            width: 36; height: 36
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                ctx.strokeStyle = "white"
                                ctx.fillStyle = "white"
                                ctx.lineWidth = 4
                                ctx.lineCap = "round"
                                // 环形箭头（缺口在右上方）
                                var cx = 18, cy = 18, r = 11
                                var a0 = -Math.PI / 4
                                var a1 = a0 + Math.PI * 1.6
                                ctx.beginPath()
                                ctx.arc(cx, cy, r, a0, a1)
                                ctx.stroke()
                                // 箭头（弧终点沿切线方向）
                                var ex = cx + r * Math.cos(a1)
                                var ey = cy + r * Math.sin(a1)
                                var tx = Math.cos(a1 + Math.PI / 2)
                                var ty = Math.sin(a1 + Math.PI / 2)
                                var px = -ty, py = tx
                                ctx.beginPath()
                                ctx.moveTo(ex + tx * 9, ey + ty * 9)
                                ctx.lineTo(ex + px * 5, ey + py * 5)
                                ctx.lineTo(ex - px * 5, ey - py * 5)
                                ctx.closePath()
                                ctx.fill()
                            }
                        }

                        MouseArea {
                            id: rebootMouseArea
                            anchors.fill: parent
                            onClicked: {
                                Qt.quit()
                            }
                        }
                    }

                    // 关机按钮（电源图标）
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60
                        color: shutdownMouseArea.pressed ? "#cc3333" : "#ff4444"
                        border.color: "#cc0000"
                        border.width: 2
                        radius: 5

                        Canvas {
                            anchors.centerIn: parent
                            width: 36; height: 36
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                ctx.strokeStyle = "white"
                                ctx.lineWidth = 4
                                ctx.lineCap = "round"
                                // 圆弧（顶部开口）
                                ctx.beginPath()
                                ctx.arc(18, 20, 10, -Math.PI * 0.3, Math.PI * 1.3)
                                ctx.stroke()
                                // 竖线
                                ctx.beginPath()
                                ctx.moveTo(18, 5)
                                ctx.lineTo(18, 16)
                                ctx.stroke()
                            }
                        }

                        MouseArea {
                            id: shutdownMouseArea
                            anchors.fill: parent
                            onClicked: {
                                shutdownDialog.open()
                            }
                        }
                    }

                    // 关闭显示器按钮（显示器图标）
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60
                        color: displayOffMouseArea.pressed ? "#336699" : "#4477aa"
                        border.color: "#225588"
                        border.width: 2
                        radius: 5

                        Item {
                            anchors.centerIn: parent
                            width: 34
                            height: 30

                            Rectangle {     // 屏幕
                                x: 2; y: 0
                                width: 30; height: 20
                                color: "transparent"
                                border.color: "white"
                                border.width: 2
                                radius: 2
                            }
                            Rectangle {     // 支柱
                                x: 15; y: 20
                                width: 4; height: 6
                                color: "white"
                            }
                            Rectangle {     // 底座
                                x: 8; y: 26
                                width: 18; height: 3
                                radius: 1
                                color: "white"
                            }
                        }

                        MouseArea {
                            id: displayOffMouseArea
                            anchors.fill: parent
                            onClicked: {
                                systemService.executeScript("display_off",
                                    "xset dpms force off")
                            }
                        }
                    }
                }

                // 中间内容区域（ScrollView）
                ScrollView {
                    anchors.top: parent.top
                    anchors.topMargin: leftPanelCollapsed ? 0 : 15
                    anchors.left: parent.left
                    anchors.leftMargin: leftPanelCollapsed ? 0 : 15
                    anchors.right: parent.right
                    anchors.rightMargin: leftPanelCollapsed ? 0 : 40
                    anchors.bottom: bottomButtons.top
                    anchors.bottomMargin: leftPanelCollapsed ? 0 : 15
                    visible: !leftPanelCollapsed
                    clip: false  // 禁用裁剪，提升性能

                    ColumnLayout {
                        width: parent.width - 30
                        spacing: 8

                        Label {
                            text: "可用IP地址"
                            font.bold: true
                            font.pixelSize: fontNormal
                            Layout.alignment: Qt.AlignHCenter
                        }

                        ListView {
                            id: ipList
                            Layout.fillWidth: true
                            Layout.preferredHeight: 120
                            Layout.maximumHeight: 120
                            model: ipAddressService.allIPs
                            
                            // 性能优化（Qt 6）
                            clip: false
                            smooth: true
                            reuseItems: true
                            
                            delegate: Rectangle {
                                id: ipDelegate
                                required property int index
                                required property var modelData
                                width: ipList.width
                                height: 40
                                color: ipList.currentIndex === index ? "lightblue" : "transparent"

                                Text {
                                    text: ipDelegate.modelData
                                    font.pixelSize: fontSmall
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    
                                    // 字体渲染优化
                                    renderType: Text.NativeRendering
                                    font.hintingPreference: Font.PreferFullHinting
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        ipList.currentIndex = ipDelegate.index
                                    }
                                }
                            }
                        }

                        Label {
                            text: "端口"
                            font.bold: true
                            font.pixelSize: fontNormal
                        }

                        Label {
                            text: "26413"
                            font.pixelSize: fontNormal
                        }

                        Button {
                            id: startButton
                            text: tcpServer.isRunning ? "停止服务" : "启动服务"
                            font.pixelSize: fontNormal
                            Layout.fillWidth: true
                            Layout.preferredHeight: 60
                            onClicked: {
                                if (tcpServer.isRunning) {
                                    tcpServer.stopServer()
                                } else {
                                    tcpServer.startServer()
                                }
                            }
                        }

                        // 切换上网/AP模式按钮
                        Button {
                            id: wifiModeButton
                            property bool inApMode: true
                            text: inApMode ? "切换到上网" : "切换到AP"
                            font.pixelSize: fontSmall
                            leftPadding: 0
                            rightPadding: 0
                            Layout.fillWidth: true
                            Layout.preferredHeight: 60
                            onClicked: {
                                if (inApMode) {
                                    switchToWifi()
                                    inApMode = false
                                } else {
                                    returnToApMode()
                                    inApMode = true
                                }
                            }
                        }

                        // WiFi名称输入（仅上网模式显示）
                        TextField {
                            id:ssidField
                            visible: !wifiModeButton.inApMode
                            text: defaultWifiSsid
                            placeholderText: "WiFi名称"
                            font.pixelSize: fontSmall
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                        }

                        // WiFi密码输入（仅上网模式显示）
                        TextField {
                            id: passwordField
                            visible: !wifiModeButton.inApMode
                            text: defaultWifiPassword
                            placeholderText: "WiFi密码"
                            echoMode: TextInput.Password
                            font.pixelSize: fontSmall
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                        }

                        // 连接WIFI按钮（仅上网模式显示）
                        Button {
                            visible: !wifiModeButton.inApMode
                            text: "连接WIFI"
                            font.pixelSize: fontSmall
                            leftPadding: 0
                            rightPadding: 0
                            Layout.fillWidth: true
                            Layout.preferredHeight: 60
                            onClicked: connWifi()
                        }
                    }
                }
            }

            // Center panel - Tab content area
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 5

                // Top Tab bar (horizontal)
                RowLayout {
                    id: tabBar
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    Layout.maximumHeight: 80
                    spacing: 5

                    property int currentIndex: 0

                    Repeater {
                        model: ["日志", "参数", "IMU", "遥控器"]

                        Button {
                            required property int index
                            required property string modelData
                            text: modelData
                            font.pixelSize: fontNormal
                            Layout.preferredWidth: 150
                            Layout.preferredHeight: 80
                            checked: tabBar.currentIndex === index
                            onClicked: tabBar.currentIndex = index
                            background: Rectangle {
                                color: parent.checked ? "#ffffff" : "#e0e0e0"
                                border.color: "#cccccc"
                                border.width: 1
                            }
                        }
                    }
                }

                // Tab content
                StackLayout {
                    id: tabContent
                    currentIndex: tabBar.currentIndex
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    LogControl { 
                        id: logControl
                        currentTab: tabBar.currentIndex  // 传递当前tab索引，避免其他页面刷新
                    }
                    ParameterControl {
                        id: parameterControl
                        visible: tabBar.currentIndex === 1
                        // 不需要显式传递tcpServer和packetBuilder，它们作为全局context properties可以直接访问
                        onShowKeyboard: function(inputField) {
                            numericKeyboard.show(inputField)
                        }
                        onHideKeyboard: {
                            numericKeyboard.hide()
                        }
                    }
                    ImuControl {
                        id: imuControl
                        currentTab: tabBar.currentIndex  // 传入当前tab索引，用于条件刷新优化
                    }
                    RemoteControl {
                        id: remoteControl
                        currentTab: tabBar.currentIndex
                    }
                }
            }

            // Right panel - Data display (可收缩)
            Rectangle {
                id: rightPanel
                Layout.preferredWidth: rightPanelCollapsed ? 40 : rightPanelWidth
                Layout.minimumWidth: 40
                Layout.fillHeight: true
                color: "#f0f0f0"
                border.color: "#cccccc"
                border.width: 1

                // 收缩按钮
                Rectangle {
                    id: rightCollapseBtn
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    height: 80
                    color: rightCollapseBtnArea.pressed ? "#cccccc" : "#e0e0e0"
                    border.color: "#999999"
                    border.width: 1
                    z: 10

                    Text {
                        anchors.centerIn: parent
                        text: rightPanelCollapsed ? "<" : ">"
                        font.pixelSize: fontNormal
                        font.bold: true
                    }

                    MouseArea {
                        id: rightCollapseBtnArea
                        anchors.fill: parent
                        onClicked: {
                            rightPanelCollapsed = !rightPanelCollapsed
                        }
                    }
                }

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: rightPanelCollapsed ? 0 : 15
                    anchors.leftMargin: 40  // 为收缩按钮留空间
                    anchors.rightMargin: rightPanelCollapsed ? 0 : 15
                    visible: !rightPanelCollapsed
                    
                    // 性能优化设置（修复闪烁问题）
                    clip: false  // 禁用裁剪避免闪烁
                    smooth: true  // 整体平滑设置
                    layer.enabled: false  // 禁用分层渲染

                    ColumnLayout {
                        width: rightPanel.width - 70
                        spacing: 8

                        // RC Data (遥控数据)
                        Label { text: "遥控数据"; font.bold: true; font.pixelSize: fontNormal; color: "blue"; Layout.alignment: Qt.AlignHCenter }
                        Text { 
                            text: "Roll: " + rcRollValue
                            font.family: "Consolas"
                            font.pixelSize: fontSmall
                            // 字体渲染优化（修复闪烁和文字消失问题）
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                        }
                        Text { 
                            text: "Pitch: " + rcPitchValue
                            font.family: "Consolas"
                            font.pixelSize: fontSmall
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                        }
                        Text { 
                            text: "Yaw: " + rcYawValue
                            font.family: "Consolas"
                            font.pixelSize: fontSmall
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                        }
                        Text { 
                            text: "Throttle: " + rcThrottleValue
                            font.family: "Consolas"
                            font.pixelSize: fontSmall
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                        }

                        Separator {}

                        // Frequency Data (频率数据)
                        Label { text: "频率数据"; font.bold: true; font.pixelSize: fontNormal; color: "blue"; Layout.alignment: Qt.AlignHCenter }
                        Text { 
                            text: "200Hz: " + freq200Hz
                            font.family: "Consolas"
                            font.pixelSize: fontSmall
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                        }
                        Text { 
                            text: "OnPacketIn: " + freqOnPacketIn
                            font.family: "Consolas"
                            font.pixelSize: fontSmall
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                        }
                        Text { 
                            text: "OnRxDone: " + freqOnRxDone
                            font.family: "Consolas"
                            font.pixelSize: fontSmall
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                        }
                        Text { 
                            text: "Response: " + freqResponse
                            font.family: "Consolas"
                            font.pixelSize: fontSmall
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                        }
                        Text { 
                            text: "OnChannels: " + freqOnChannels
                            font.family: "Consolas"
                            font.pixelSize: fontSmall
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                        }
                        Text { 
                            text: "Loop: " + freqLoop
                            font.family: "Consolas"
                            font.pixelSize: fontSmall
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                        }

                        Separator {}

                        // Control data
                        Label { text: "控制数据"; font.bold: true; font.pixelSize: fontNormal; color: "purple"; Layout.alignment: Qt.AlignHCenter }
                        Text { 
                            text: controlThrValue
                            font.family: "Consolas"
                            font.pixelSize: fontSmall
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                        }
                        Text { 
                            text: controlRollPitchValue
                            font.family: "Consolas"
                            font.pixelSize: fontSmall
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                        }
                        Text { 
                            text: controlYawValue
                            font.family: "Consolas"
                            font.pixelSize: fontSmall
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                        }

                        Separator {}

                        // Location data
                        Label { text: "位置数据"; font.bold: true; font.pixelSize: fontNormal; color: "darkorange"; Layout.alignment: Qt.AlignHCenter }
                        Text { 
                            text: locPosValue
                            font.family: "Consolas"
                            font.pixelSize: fontSmall
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                        }
                        Text { 
                            text: locVelValue
                            font.family: "Consolas"
                            font.pixelSize: fontSmall
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                        }

                        Separator {}

                        // Flow data
                        Label { text: "光流数据"; font.bold: true; font.pixelSize: fontNormal; color: "teal"; Layout.alignment: Qt.AlignHCenter }
                        Text { 
                            text: flowTargetValue
                            font.family: "Consolas"
                            font.pixelSize: fontSmall
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                        }
                        Text { 
                            text: flowPosValue
                            font.family: "Consolas"
                            font.pixelSize: fontSmall
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                        }

                        Separator {}

                        // IMU data
                        Label { text: "IMU数据"; font.bold: true; font.pixelSize: fontNormal; color: "green"; Layout.alignment: Qt.AlignHCenter }
                        Text { 
                            text: imuAccelValue
                            font.family: "Consolas"
                            font.pixelSize: fontSmall
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                        }
                        Text { 
                            text: imuGyroValue
                            font.family: "Consolas"
                            font.pixelSize: fontSmall
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                        }
                        Text { 
                            text: imuAttitudeValue
                            font.family: "Consolas"
                            font.pixelSize: fontSmall
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                        }
                        Text { 
                            text: imuAltVelValue
                            font.family: "Consolas"
                            font.pixelSize: fontSmall
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                        }
                        Text { 
                            text: imuAccelUpValue
                            font.family: "Consolas"
                            font.pixelSize: fontSmall
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                        }

                        Separator {}

                        // Alt target
                        Label { text: "高度目标"; font.bold: true; font.pixelSize: fontNormal; color: "darkcyan"; Layout.alignment: Qt.AlignHCenter }
                        Text { 
                            text: "dest_alt=" + destAltValue
                            font.family: "Consolas"
                            font.pixelSize: fontSmall
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                        }
                        Text {
                            text: "current_alt=" + currentAltValue
                            font.family: "Consolas"
                            font.pixelSize: fontSmall
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                        }

                        Separator {}

                        // GPS Data
                        Label { text: "GPS数据"; font.bold: true; font.pixelSize: fontNormal; color: "darkmagenta"; Layout.alignment: Qt.AlignHCenter }
                        Text {
                            text: "fixType=" + gpsFixType + " numSV=" + gpsNumSV
                            font.family: "Consolas"
                            font.pixelSize: fontSmall
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                        }
                        Text {
                            text: "fLon=" + gpsFLon
                            font.family: "Consolas"
                            font.pixelSize: fontSmall
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                        }
                        Text {
                            text: "fLat=" + gpsFLat
                            font.family: "Consolas"
                            font.pixelSize: fontSmall
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                        }
                        Text {
                            text: "hAcc=" + gpsHAcc
                            font.family: "Consolas"
                            font.pixelSize: fontSmall
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                        }
                        Text {
                            text: "ds=" + gpsDs + " dx=" + gpsDx + " dy=" + gpsDy
                            font.family: "Consolas"
                            font.pixelSize: fontSmall
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                        }
                        Text {
                            text: "hds=" + gpsHds + " hx=" + gpsHx + " hy=" + gpsHy
                            font.family: "Consolas"
                            font.pixelSize: fontSmall
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                        }
                    }
                }
            }
        }

        // Virtual Keyboard (Qt VirtualKeyboard)
        InputPanel {
            id: inputPanel
            z: 9999  // 关键修复：确保系统虚拟键盘显示在所有对话框之上（包括FileDialog）
            Layout.fillWidth: true
            Layout.preferredHeight: Qt.inputMethod.visible ? 300 : 0
            visible: Qt.inputMethod.visible
        }

        // Custom Numeric Keyboard (备用)
        NumericKeyboard {
            id: numericKeyboard
            z: 1000  // 关键修复：确保键盘显示在所有对话框之上
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 300 : 0
            Layout.maximumHeight: 300
        }
    }

    // 关机确认对话框
    Dialog {
        id: shutdownDialog
        title: "确认关机"
        modal: true
        anchors.centerIn: parent
        width: 400
        height: 200

        background: Rectangle {
            color: "#f5f5f5"
            border.color: "#cccccc"
            border.width: 2
            radius: 10
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 20

            Text {
                text: "确定要关机吗？"
                font.pixelSize: fontLarge
                font.bold: true
                color: "#333333"
                Layout.alignment: Qt.AlignHCenter
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 20

                Button {
                    text: "取消"
                    font.pixelSize: fontNormal
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 50
                    onClicked: {
                        shutdownDialog.close()
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 50
                    color: confirmShutdownMouseArea.pressed ? "#cc3333" : "#ff4444"
                    border.color: "#cc0000"
                    border.width: 2
                    radius: 5

                    Text {
                        anchors.centerIn: parent
                        text: "确认关机"
                        font.pixelSize: fontNormal
                        font.bold: true
                        color: "white"
                    }

                    MouseArea {
                        id: confirmShutdownMouseArea
                        anchors.fill: parent
                        onClicked: {
                            shutdownDialog.close()
                            systemService.shutdown()
                        }
                    }
                }
            }
        }
    }

    // 切换到上网模式（关闭AP，wlan0交给wpa_supplicant管理）
    function switchToWifi() {
        logControl.addLog("[" + displayProcessor.currentTime() + "] 正在切换到上网模式...", "system")

        // 创建脚本内容（set -x 回显每条命令，输出转发到日志）
        var scriptContent = `#!/bin/sh
set -x

# 1. 停止 AP 模式相关进程（绕过 OpenRC 服务管理，防止连锁反应）
killall hostapd dnsmasq


rc-service hostapd stop
rc-service dnsmasq stop
rm -f /etc/NetworkManager/conf.d/99-unmanaged-wlan.conf
rc-service networkmanager stop
rc-service networkmanager start


# 2. 让后台的 NetworkManager 放弃管理 wlan0（关键！防止它干扰底层）
nmcli device set wlan0 managed no

# 3. 重置网卡并修复高通驱动底层 Bug（解决 ARP 失败问题）
ip link set wlan0 down
sleep 1
ip link set wlan0 up
ip link set wlan0 promisc on
ip link set wlan0 allmulticast on
iw dev wlan0 set power_save off
`

        // 写入脚本文件并执行
        systemService.executeScript("wifi_switch", scriptContent)
    }

    // 连接WiFi（使用输入框中的SSID和密码）
    function connWifi() {
        var ssid = ssidField.text.trim()
        var password = passwordField.text.trim()
        if (ssid.length === 0 || password.length === 0) {
            logControl.addLog("[" + displayProcessor.currentTime() + "] 错误：WiFi名称和密码不能为空", "error")
            return
        }

        // 创建脚本内容（set -x 回显每条命令，输出转发到日志；密码行附近关闭回显）
        var scriptContent = `#!/bin/sh

# 4. 生成 WiFi 配置并连接（请替换为实际的 WiFi 名和密码）
set +x
wpa_passphrase "${ssid}" "${password}" > /tmp/wpa.conf
set -x
killall wpa_supplicant 2>/dev/null
wpa_supplicant -B -i wlan0 -c /tmp/wpa.conf

# 5. 获取 IP 与路由
# 尝试通过 DHCP 获取 IP
killall udhcpc 2>/dev/null
udhcpc -i wlan0

# 6. 修复 DNS 解析与 IPv6 卡死问题（解决 wget bad address）
# 写入公共 DNS 并加锁，防止被 udhcpc 偷偷改回光猫地址
printf "nameserver 223.5.5.5\\nnameserver 114.114.114.114\\n" > /etc/resolv.conf
chattr +i /etc/resolv.conf

# 临时关闭 IPv6，强制应用走 IPv4（解决 musl libc 优先走 IPv6 导致超时）
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.wlan0.disable_ipv6=1

ping -c 4 www.baidu.com
`

        // 写入脚本文件并执行
        systemService.executeScript("wifi_conn", scriptContent)
    }

    // 返回AP模式
    function returnToApMode() {
        logControl.addLog("[" + displayProcessor.currentTime() + "] 正在返回AP模式...", "system")

        // 创建返回AP模式的脚本（set -x 回显每条命令，输出转发到日志）
        var scriptContent = `#!/bin/sh
set -x

# 停止WiFi相关进程
killall wpa_supplicant udhcpc

# 解锁DNS配置
chattr -i /etc/resolv.conf

# 重新启用IPv6
sysctl -w net.ipv6.conf.all.disable_ipv6=0
sysctl -w net.ipv6.conf.wlan0.disable_ipv6=0

# 重启网络服务

echo -e '[keyfile]\nunmanaged-devices=interface-name:wlan0' | sudo tee /etc/NetworkManager/conf.d/99-unmanaged-wlan.conf > /dev/null
rc-service networkmanager restart

rc-service networking restart || true

# 启动AP模式服务
ip link set wlan0 up
ip addr add 192.168.4.1/24 dev wlan0
rc-service hostapd stop || true
rc-service dnsmasq stop || true
sleep 2
rc-service hostapd start || true
rc-service dnsmasq start || true
`

        // 写入脚本文件并执行
        systemService.executeScript("ap_switch", scriptContent)
    }

    Component.onCompleted: {
        // 检查保存的WiFi配置，为空则恢复默认值
        if (ssidField.text.trim().length === 0) {
            ssidField.text = defaultWifiSsid
        }
        if (passwordField.text.trim().length === 0) {
            passwordField.text = defaultWifiPassword
        }

        // 显示启动日志
        logControl.addLog("[" + displayProcessor.currentTime() + "] 飞控调试工具已启动", "system")
        logControl.addLog("[" + displayProcessor.currentTime() + "] TCP端口: 26413", "system")
        // 自动启动服务
        tcpServer.startServer()
    }

    component Separator: Rectangle {
        Layout.fillWidth: true
        height: 2
        color: "#cccccc"
        Layout.topMargin: 15
        Layout.bottomMargin: 15
    }
}