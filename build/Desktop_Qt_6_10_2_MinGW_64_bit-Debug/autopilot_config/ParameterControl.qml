import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs  // 用于FileDialog

ColumnLayout {
    id: paramRoot
    spacing: 10

    // 字体大小 - 手机显示需要更大的字体
    property int paramFontSmall: 24
    property int paramFontNormal: 28
    property int paramFontLarge: 32

    // 参数配置列表（参考H743PilotX-Tcp）
    property var paramConfigNames: [
        "pid_in_roll_p", "pid_in_roll_i", "pid_in_roll_d", "pid_in_roll_il",
        "pid_ou_roll_p", "pid_ou_roll_i", "pid_ou_roll_d", "pid_ou_roll_il",
        "pid_in_pitch_p", "pid_in_pitch_i", "pid_in_pitch_d", "pid_in_pitch_il",
        "pid_ou_pitch_p", "pid_ou_pitch_i", "pid_ou_pitch_d", "pid_ou_pitch_il",
        "pid_yaw_p", "pid_yaw_i", "pid_yaw_d", "pid_yaw_il",
        "pid_yaw_rate_p", "pid_yaw_rate_i", "pid_yaw_rate_d", "pid_yaw_rate_il",
        "pid_in_thr_p", "pid_in_thr_i", "pid_in_thr_d", "pid_in_thr_il",
        "pid_ou_thr_p", "pid_ou_thr_i", "pid_ou_thr_d", "pid_ou_thr_il",
        "pid_pmw_p", "pid_pmw_i", "pid_pmw_d", "pid_pmw_il",
        "pid_gps_p", "pid_gps_i", "pid_gps_d", "pid_gps_il",
        "alt_hover_thr","alt_thr_lp",
        "sys_fly_mode",
        "imu_docal", "cal_roll", "cal_pitch", "cal_yaw"
    ]

    property var paramConfigDescs: [
        "内环Roll P", "内环Roll I", "内环Roll D", "内环Roll积分限幅",
        "外环Roll P", "外环Roll I", "外环Roll D", "外环Roll积分限幅",
        "内环Pitch P", "内环Pitch I", "内环Pitch D", "内环Pitch积分限幅",
        "外环Pitch P", "外环Pitch I", "外环Pitch D", "外环Pitch积分限幅",
        "Yaw P", "Yaw I", "Yaw D", "Yaw积分限幅",
        "Yaw Rate P", "Yaw Rate I", "Yaw Rate D", "Yaw Rate积分限幅",
        "内环油门 P", "内环油门 I", "内环油门 D", "内环油门积分限幅",
        "外环油门 P", "外环油门 I", "外环油门 D", "外环油门积分限幅",
        "光流 P", "光流 I", "光流 D", "光流积分限幅",
        "GPS P", "GPS I", "GPS D", "GPS积分限幅",
        "悬停油门","油门滤波系数",
        "飞行模式(0=手动,1=悬停)",
        "IMU校准", "Roll校准", "Pitch校准", "Yaw校准"
    ]

    // 参数数据模型
    ListModel {
        id: paramModel
        Component.onCompleted: {
            // 初始化参数列表
            for (var i = 0; i < paramConfigNames.length; i++) {
                append({
                    name: paramConfigNames[i],
                    description: paramConfigDescs[i],
                    value: ""
                })
            }
        }
    }

    // 内部状态属性 - 使用param前缀避免冲突
    property bool paramIsReading: false
    property bool paramIsSaving: false
    property int paramIndex: 0
    property bool paramWaiting: false
    property var paramRecvMap: ({})  // 记录哪些参数已收到响应
    property var paramBuffer: ({})  // 参数值缓冲区（避免频繁刷新UI）
    property var paramRetryCount: ({})  // 记录每个参数的重试次数
    property var paramSaveConfirmed: ({})  // 记录哪些参数已保存确认
    property var paramSaveRetryCount: ({})  // 记录保存参数的重试次数
    property bool paramWaitingForSaveConfirm: false  // 等待保存确认
    property int paramSaveIndex: 0  // 当前保存的参数索引
    property var userInputValues: ({})  // 关键修复：保存用户输入的值（避免滚动后丢失）

    // 保存参数的状态
    property bool paramSaveConfigSent: false  // 是否已发送保存配置命令
    property bool paramSaveConfigConfirmed: false  // 保存配置命令是否已确认

    // 键盘信号
    signal showKeyboard(var inputField)
    signal hideKeyboard()

    // 错误提示对话框
    Dialog {
        id: errorDialog
        title: "错误"
        modal: true
        x: Math.round((paramRoot.Window.width - width) / 2)
        y: Math.round((paramRoot.Window.height - height) / 2)
        width: 400
        height: 200
        
        background: Rectangle {
            color: "#f5f5f5"
            border.color: "#cc0000"
            border.width: 2
            radius: 10
        }

        property string errorMessage: ""

        contentItem: ColumnLayout {
            spacing: 20

            Text {
                text: errorDialog.errorMessage
                Layout.alignment: Qt.AlignHCenter
                font.pixelSize: paramFontNormal
                color: "red"
                wrapMode: Text.WordWrap
            }

            Button {
                text: "确定"
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 120
                Layout.preferredHeight: 50
                font.pixelSize: paramFontNormal
                onClicked: errorDialog.close()
            }
        }
    }

    // 完成提示对话框
    Dialog {
        id: paramCompleteDialog
        title: ""
        modal: true
        
        x: Math.round((paramRoot.Window.width - width) / 2)
        y: Math.round((paramRoot.Window.height - height) / 2)
        
        width: 400
        height: 300
        
        background: Rectangle {
            color: "#f5f5f5"
            border.color: "#3366cc"
            border.width: 3
            radius: 15
            
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 50
                color: "#3366cc"
                radius: 15
                
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 15
                    color: "#3366cc"
                }
                
                Text {
                    text: "参数操作完成"
                    anchors.centerIn: parent
                    font.pixelSize: paramFontLarge
                    font.bold: true
                    color: "white"
                }
            }
        }
        
        contentItem: ColumnLayout {
            spacing: 20
            
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 80
                height: 80
                color: "#4CAF50"
                radius: 40
                
                Text {
                    anchors.centerIn: parent
                    text: "✓"
                    font.pixelSize: paramFontLarge
                    font.bold: true
                    color: "white"
                }
            }
            
            Text {
                id: messageText
                text: paramCompleteDialog.messageText
                Layout.alignment: Qt.AlignHCenter
                font.pixelSize: paramFontNormal
                font.bold: true
                color: "#333333"
            }
            
            Button {
                text: "确定"
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 150
                Layout.preferredHeight: 50
                font.pixelSize: paramFontLarge
                
                background: Rectangle {
                    color: parent.down ? "#1a5490" : (parent.hovered ? "#2855a4" : "#3366cc")
                    radius: 10
                    border.color: "#2855a4"
                    border.width: 2
                }
                
                contentItem: Text {
                    text: parent.text
                    font.pixelSize: parent.font.pixelSize
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    paramCompleteDialog.close()
                }
            }
        }
        
        property string messageText: ""
    }
    
    // 关键优化：单独的参数输入对话框（避免delegate中有TextField）
    Dialog {
        id: paramInputDialog
        title: "修改参数值"
        modal: false  // 关键修复：设为非模态，允许小键盘接收点击事件
        
        // 关键修复：设置closePolicy，防止点击外部（小键盘）时关闭对话框
        // Popup.NoAutoClose: 不自动关闭，只能通过按钮关闭
        // Popup.CloseOnEscape: 只在按ESC时关闭
        closePolicy: Popup.NoAutoClose
        
        // 关键修复：调整对话框位置，向上移动，避开底部小键盘区域
        // 小键盘高度约300px，对话框需要在其上方显示
        x: Math.round((paramRoot.Window.width - width) / 2)
        y: Math.round((paramRoot.Window.height - height - 350) / 2)  // 向上移动350px，避开小键盘
        width: 500
        height: 200
        
        background: Rectangle {
            color: "#f5f5f5"
            border.color: "#3366cc"
            border.width: 2
            radius: 10
        }
        
        property string paramName: ""
        property string paramValue: ""  // 关键修复：保存当前参数值
        
        contentItem: ColumnLayout {
            spacing: 20
            
            Text {
                text: "参数: " + paramInputDialog.paramName
                font.pixelSize: paramFontNormal
                color: "gray"
                Layout.alignment: Qt.AlignHCenter
                
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
            }
            
            TextField {
                id: dialogInputField
                Layout.fillWidth: true
                font.family: "Consolas"
                font.pixelSize: paramFontNormal
                horizontalAlignment: TextInput.AlignRight
                
                font.hintingPreference: Font.PreferFullHinting
                
                background: Rectangle {
                    color: "white"
                    border.color: dialogInputField.activeFocus ? "blue" : "#cccccc"
                    border.width: 2
                    radius: 5
                }
                
                onPressed: {
                    paramRoot.showKeyboard(dialogInputField)
                }
                
                onActiveFocusChanged: {
                    if (activeFocus) {
                        paramRoot.showKeyboard(dialogInputField)
                    }
                }
            }
        }
        
        standardButtons: Dialog.Ok | Dialog.Cancel
        
        onOpened: {
            // 关键修复：对话框打开时，设置初始值（优先显示用户输入的值，如果没有则显示当前参数值）
            dialogInputField.text = userInputValues[paramName] || paramValue || ""
            dialogInputField.focus = true
            paramRoot.showKeyboard(dialogInputField)
        }
        
        onAccepted: {
            // 保存用户输入的值到userInputValues
            userInputValues[paramInputDialog.paramName] = dialogInputField.text

            // 关键修复：同时更新model.value，确保UI立即刷新显示
            for (var i = 0; i < paramModel.count; i++) {
                if (paramModel.get(i).name === paramInputDialog.paramName) {
                    paramModel.setProperty(i, "value", dialogInputField.text)
                    break
                }
            }

            // 关键修复：手动关闭对话框（因为closePolicy为NoAutoClose，不会自动关闭）
            paramInputDialog.close()

            paramRoot.hideKeyboard()
        }
        
        onRejected: {
            // 取消输入，不保存
            paramRoot.hideKeyboard()
        }
        
        onClosed: {
            // 关闭对话框时，隐藏键盘
            paramRoot.hideKeyboard()
        }
    }

    // 文件对话框 - 加载参数
    FileDialog {
        id: loadParamFileDialog
        title: "从文件加载参数"
        nameFilters: ["参数文件 (*.param *.txt)", "所有文件 (*)"]
        fileMode: FileDialog.OpenFile
        // 关键修复：设置默认目录，使用file:/// URL格式
        currentFolder: "file:///home/bitstream/autopilot_config/"
        onAccepted: {
            loadParametersFromFile(selectedFile)
        }
    }

    // 文件对话框 - 保存参数
    FileDialog {
        id: saveParamFileDialog
        title: "保存参数到文件"
        nameFilters: ["参数文件 (*.param)", "文本文件 (*.txt)"]
        fileMode: FileDialog.SaveFile
        defaultSuffix: ".param"
        // 关键修复：设置默认目录，使用file:/// URL格式
        currentFolder: "file:///home/bitstream/autopilot_config/"
        onAccepted: {
            saveParametersToFile(selectedFile)
        }
    }

    // 固定的控制按钮区域 - 不随列表滚动
    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        // 占位Item - 让按钮右对齐
        Item {
            Layout.fillWidth: true
        }

        Button {
            id: paramReadBtn
            text: "读取参数"
            font.pixelSize: paramFontLarge
            Layout.preferredHeight: 60
            onClicked: {
                // 检查前置条件并显示明确的错误提示
                if (typeof tcpServer === 'undefined' || tcpServer === null) {
                    errorDialog.errorMessage = "TCP服务器未初始化"
                    errorDialog.open()
                    return
                }
                
                if (!tcpServer.isRunning) {
                    errorDialog.errorMessage = "TCP服务未运行，请先启动服务"
                    errorDialog.open()
                    return
                }

                if (typeof packetBuilder === 'undefined' || packetBuilder === null) {
                    errorDialog.errorMessage = "packetBuilder未初始化"
                    errorDialog.open()
                    return
                }

                if (paramIsReading) {
                    paramIsReading = false
                    paramWaiting = false
                    text = "读取参数"
                    paramRequestTimer.stop()
                    if (typeof displayProcessor !== 'undefined' && displayProcessor !== null) {
                        displayProcessor.addSystemText("停止读取参数")
                    }
                } else {
                    paramIsReading = true
                    paramIndex = 0
                    paramWaiting = false
                    text = "停止读取"

                    // 清空参数列表和状态
                    for (var i = 0; i < paramModel.count; i++) {
                        paramModel.setProperty(i, "value", "")
                    }
                    for (var i = 0; i < paramConfigNames.length; i++) {
                        paramRecvMap[paramConfigNames[i]] = false
                        paramRetryCount[paramConfigNames[i]] = 0
                        paramBuffer[paramConfigNames[i]] = ""
                        userInputValues[paramConfigNames[i]] = ""
                    }

                    if (typeof displayProcessor !== 'undefined' && displayProcessor !== null) {
                        displayProcessor.addSystemText("开始读取参数...")
                    }

                    sendNextRequest()
                }
            }
        }

        Button {
            id: paramSaveBtn
            text: "保存参数"
            font.pixelSize: paramFontLarge
            Layout.preferredHeight: 60
            onClicked: {
                if (!tcpServer || !tcpServer.isRunning) {
                    return
                }
                if (paramModel.count === 0) {
                    return
                }
                if (paramIsSaving) {
                    paramIsSaving = false
                    text = "保存参数"
                    paramSaveTimer.stop()
                } else {
                    paramIsSaving = true
                    text = "停止保存"

                    paramSaveIndex = 0
                    paramSaveConfigSent = false
                    paramSaveConfigConfirmed = false
                    paramWaitingForSaveConfirm = false
                    for (var i = 0; i < paramModel.count; i++) {
                        paramSaveConfirmed[paramModel.get(i).name] = false
                        paramSaveRetryCount[paramModel.get(i).name] = 0
                    }

                    if (typeof displayProcessor !== 'undefined' && displayProcessor !== null) {
                        displayProcessor.addSystemText("开始保存参数...")
                    }

                    sendNextSaveRequest()
                }
            }
        }

        Button {
            id: loadFromFileBtn
            text: "从文件加载"
            font.pixelSize: paramFontNormal
            Layout.preferredHeight: 60
            onClicked: {
                loadParamFileDialog.open()
            }
        }

        Button {
            id: saveToFileBtn
            text: "保存到文件"
            font.pixelSize: paramFontNormal
            Layout.preferredHeight: 60
            onClicked: {
                // 自动生成文件名（使用当前时间）
                var now = new Date()
                var year = now.getFullYear()
                var month = (now.getMonth() + 1).toString().padStart(2, '0')
                var day = now.getDate().toString().padStart(2, '0')
                var hour = now.getHours().toString().padStart(2, '0')
                var minute = now.getMinutes().toString().padStart(2, '0')
                var second = now.getSeconds().toString().padStart(2, '0')
                var fileName = "config_" + year + month + day + "_" + hour + minute + second + ".param"
                
                // 关键修复：使用实际路径而不是~符号（QFile不会自动展开~）
                // 在postmarketOS上，使用/home/bitstream作为home目录
                var homeDir = "/home/bitstream"
                var fullPath = homeDir + "/autopilot_config/" + fileName
                
                // 直接保存到文件
                saveParametersToFile(fullPath)
            }
        }
    }

    // 可滚动的参数列表区域
    ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true

        ListView {
            id: paramListView
            width: paramRoot.width
            model: paramModel
            // 关键优化：性能配置
            clip: false
            smooth: true
            reuseItems: true
            cacheBuffer: 5000
            
            // 关键优化：最简化的delegate结构（完全无TextField）
            delegate: Rectangle {
                id: paramDelegate
                width: paramListView.width
                height: 80
                // 关键优化：移除border和radius，使用最简单的纯色背景
                color: "white"

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 15
                    anchors.rightMargin: 15
                    anchors.topMargin: 15
                    anchors.bottomMargin: 15
                    spacing: 20

                    // 描述文本
                    Text {
                        width: parent.width * 0.35
                        height: parent.height
                        text: model.description
                        font.pixelSize: paramFontNormal
                        color: "gray"
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter

                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                    }

                    // 参数名文本
                    Text {
                        width: parent.width * 0.35
                        height: parent.height
                        text: model.name
                        font.family: "Consolas"
                        font.pixelSize: paramFontNormal
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter

                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                    }

                    // 关键优化：参数值显示（纯Text，无TextField）
                    // 使用model.value而不是userInputValues[model.name]来避免频繁的JavaScript对象访问
                    Text {
                        id: paramValueText
                        width: parent.width * 0.25
                        height: parent.height
                        text: model.value || "未设置"
                        font.family: "Consolas"
                        font.pixelSize: paramFontNormal
                        color: model.value ? "darkgreen" : "gray"
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter

                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                // 关键优化：点击后弹出单独的输入对话框
                                paramInputDialog.paramName = model.name
                                paramInputDialog.paramValue = model.value  // 传入当前参数值
                                paramInputDialog.open()
                            }
                        }
                    }
                }

                // 使用简单的分隔线替代border
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: "#cccccc"
                }
            }
        }
    }

    // 超时计时器 - 读取参数
    Timer {
        id: paramRequestTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (!paramIsReading) return

            if (paramIndex < paramConfigNames.length) {
                var configName = paramConfigNames[paramIndex]
                paramRetryCount[configName] = (paramRetryCount[configName] || 0) + 1

                if (typeof displayProcessor !== 'undefined' && displayProcessor !== null) {
                    displayProcessor.addSystemText("超时重试: " + configName + " (第 " + paramRetryCount[configName] + " 次)")
                }

                // 关键修改：超时后重新发送当前参数请求，而不是跳过
                // 这样确保每个参数都读取成功
                if (typeof packetBuilder !== 'undefined' && packetBuilder !== null) {
                    var packet = packetBuilder.buildGetConfigPacket(configName)
                    if (typeof tcpServer !== 'undefined' && tcpServer !== null) {
                        tcpServer.sendDataToAll(packet)
                    }
                }
                paramRequestTimer.start()  // 重新启动超时计时器，无限重试
            }
        }
    }

    // 超时计时器 - 保存参数
    Timer {
        id: paramSaveTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (!paramIsSaving) return

            if (paramSaveConfigSent && !paramSaveConfigConfirmed) {
                // 保存配置命令超时，重新发送
                if (typeof displayProcessor !== 'undefined' && displayProcessor !== null) {
                    displayProcessor.addSystemText("保存配置命令超时，重试...")
                }
                // 关键修改：重新发送保存配置命令，保持paramSaveConfigSent状态
                if (typeof packetBuilder !== 'undefined' && packetBuilder !== null) {
                    var packet = packetBuilder.buildSaveConfigPacket()
                    if (typeof tcpServer !== 'undefined' && tcpServer !== null) {
                        tcpServer.sendDataToAll(packet)
                    }
                }
                paramSaveTimer.start()  // 重新启动超时计时器，无限重试
            } else if (paramWaitingForSaveConfirm) {
                // 参数发送超时，重新发送当前参数
                var paramItem = paramModel.get(paramSaveIndex)
                var paramName = paramItem.name

                // 关键修复：优先从userInputValues读取用户输入的值
                var paramValue = userInputValues[paramName]
                if (paramValue === undefined || paramValue === "") {
                    paramValue = paramItem.value
                }

                paramSaveRetryCount[paramName]++

                if (typeof displayProcessor !== 'undefined' && displayProcessor !== null) {
                    displayProcessor.addSystemText("参数保存超时重试: " + paramName + " (第 " + paramSaveRetryCount[paramName] + " 次)")
                }

                // 关键修改：超时后重新发送当前参数请求，而不是跳过
                // 这样确保每个参数都保存成功
                sendSetConfigRequest(paramName, paramValue)
                paramSaveTimer.start()  // 重新启动超时计时器，无限重试
            }
        }
    }

    // 发送下一个读取请求
    function sendNextRequest() {
        if (!paramIsReading || paramIndex >= paramConfigNames.length) {
            if (paramIsReading && paramIndex >= paramConfigNames.length) {
                // 批量更新UI（避免闪烁）
                for (var i = 0; i < paramModel.count; i++) {
                    var name = paramModel.get(i).name
                    if (paramBuffer[name] !== undefined && paramBuffer[name] !== "") {
                        paramModel.setProperty(i, "value", paramBuffer[name])
                    }
                }
                
                paramIsReading = false
                paramWaiting = false
                paramReadBtn.text = "读取参数"
                
                paramCompleteDialog.messageText = "参数读取完成"
                paramCompleteDialog.open()
                
                if (typeof displayProcessor !== 'undefined' && displayProcessor !== null) {
                    displayProcessor.addSystemText("参数读取完成")
                }
            }
            return
        }

        if (paramWaiting) return

        var configName = paramConfigNames[paramIndex]
        
        if (typeof packetBuilder !== 'undefined' && packetBuilder !== null) {
            var packet = packetBuilder.buildGetConfigPacket(configName)
            if (typeof tcpServer !== 'undefined' && tcpServer !== null) {
                tcpServer.sendDataToAll(packet)  // 关键修复：使用正确的方法名
                if (typeof displayProcessor !== 'undefined' && displayProcessor !== null) {
                    displayProcessor.addSystemText("发送读取请求: " + configName)
                }
            }
        }

        paramWaiting = true
        paramRequestTimer.start()
    }

    // 发送下一个保存请求
    function sendNextSaveRequest() {
        // 关键修复：找到下一个未确认的参数
        while (paramSaveIndex < paramModel.count && paramSaveConfirmed[paramModel.get(paramSaveIndex).name]) {
            paramSaveIndex++
        }

        // 检查是否所有参数都已发送完成
        if (paramSaveIndex >= paramModel.count) {
            // 所有个参数都已确认，发送保存配置命令
            if (!paramSaveConfigSent) {
                sendSaveConfigRequest()
                paramSaveConfigSent = true
                paramWaitingForSaveConfirm = true
                paramSaveTimer.start()

                if (typeof displayProcessor !== 'undefined' && displayProcessor !== null) {
                    displayProcessor.addSystemText("发送保存配置命令...")
                }
            }
            return
        }

        var paramItem = paramModel.get(paramSaveIndex)
        var paramName = paramItem.name

        // 关键修复：优先从userInputValues读取用户输入的值
        var paramValue = userInputValues[paramName]
        if (paramValue === undefined || paramValue === "") {
            paramValue = paramItem.value
        }

        if (paramValue === "") {
            // 值为空，跳过这个参数，标记为已确认
            paramSaveConfirmed[paramName] = true
            paramSaveIndex++
            sendNextSaveRequest()
            return
        }

        if (typeof displayProcessor !== 'undefined' && displayProcessor !== null) {
            displayProcessor.addSystemText("发送参数: " + paramName + " = " + paramValue)
        }

        sendSetConfigRequest(paramName, paramValue)
        paramWaitingForSaveConfirm = true
        paramSaveTimer.start()
    }

    // 发送设置配置请求
    function sendSetConfigRequest(paramName, paramValue) {
        if (typeof packetBuilder !== 'undefined' && packetBuilder !== null) {
            var packet = packetBuilder.buildSetConfigPacket(paramName, paramValue)
            if (typeof tcpServer !== 'undefined' && tcpServer !== null) {
                tcpServer.sendDataToAll(packet)  // 关键修复：使用正确的方法名
            }
        }
    }

    // 发送保存配置命令
    function sendSaveConfigRequest() {
        // 关键修复：移除paramSaveConfigSent检查，允许超时重试时再次发送
        if (typeof packetBuilder !== 'undefined' && packetBuilder !== null) {
            var packet = packetBuilder.buildSaveConfigPacket()
            if (typeof tcpServer !== 'undefined' && tcpServer !== null) {
                tcpServer.sendDataToAll(packet)
            }
        }
    }

    // 更新参数（由Main.qml调用）
    function updateParameter(name, value) {
        paramRecvMap[name] = true
        paramBuffer[name] = value.toString()  // 只缓存，不立即更新UI
        
        // 清空用户输入（因为收到了飞控的值）
        userInputValues[name] = ""

        if (paramIsReading && paramWaiting) {
            paramWaiting = false
            paramRequestTimer.stop()
            paramIndex++
            sendNextRequest()
        }
    }

    // 处理参数保存确认（由Main.qml调用）
    function handleSaveConfirm() {
        if (paramIsSaving && paramSaveConfigSent && !paramSaveConfigConfirmed) {
            paramSaveConfigConfirmed = true
            paramSaveTimer.stop()
            paramWaitingForSaveConfirm = false
            
            if (typeof displayProcessor !== 'undefined' && displayProcessor !== null) {
                displayProcessor.addSystemText("保存配置命令已确认")
            }
            
            // 关键修复：保存命令确认后，直接显示"参数保存完成"，不需要调用sendNextSaveRequest
            paramIsSaving = false
            paramSaveBtn.text = "保存参数"
            paramSaveConfigSent = false
            
            paramCompleteDialog.messageText = "参数保存完成"
            paramCompleteDialog.open()
            
            if (typeof displayProcessor !== 'undefined' && displayProcessor !== null) {
                displayProcessor.addSystemText("参数保存完成")
            }
        }
    }

    // 处理参数设置确认（由Main.qml调用）
    function handleSetConfirm(name) {
        if (paramIsSaving && paramWaitingForSaveConfirm) {
            paramSaveTimer.stop()
            paramWaitingForSaveConfirm = false
            paramSaveConfirmed[name] = true

            if (typeof displayProcessor !== 'undefined' && displayProcessor !== null) {
                displayProcessor.addSystemText("参数设置成功: " + name)
            }

            // 关键修复：收到确认后，直接调用sendNextSaveRequest继续下一个参数
            // sendNextSaveRequest会自动检查是否所有参数都已确认，并调用sendSaveConfigRequest
            sendNextSaveRequest()
        }
    }

    // 从文件加载参数
    function loadParametersFromFile(filePath) {
        // 关键修复：正确转换URL路径为本地文件路径
        // file:///home/bitstream/... -> /home/bitstream/...
        var localPath = filePath.toString()
        if (localPath.startsWith("file://")) {
            localPath = localPath.substring(7)  // 移除 "file://"，保留 "/"
        }

        if (typeof paramFileManager !== 'undefined' && paramFileManager !== null) {
            var result = paramFileManager.loadParameters(localPath, paramConfigNames)
            
            if (result.length >= 4) {
                var loadedNames = result[0]
                var loadedValues = result[1]
                var loadedCount = result[2]
                var skippedCount = result[3]
                
                // 更新参数列表
                for (var i = 0; i < loadedNames.length; i++) {
                    var name = loadedNames[i]
                    var value = loadedValues[i]
                    
                    // 保存到userInputValues（用户手动加载的值）
                    userInputValues[name] = value
                    
                    // 更新model
                    for (var j = 0; j < paramModel.count; j++) {
                        if (paramModel.get(j).name === name) {
                            paramModel.setProperty(j, "value", value)
                            break
                        }
                    }
                }
                
                paramCompleteDialog.messageText = "从文件加载完成: 加载 " + loadedCount + " 个, 跳过 " + skippedCount + " 个未知参数"
                paramCompleteDialog.open()
                
                if (typeof displayProcessor !== 'undefined' && displayProcessor !== null) {
                    displayProcessor.addSystemText("从文件加载参数完成: 加载 " + loadedCount + " 个, 跳过 " + skippedCount + " 个未知参数")
                }
            }
        }
    }

    // 保存参数到文件
    function saveParametersToFile(filePath) {
        // 关键修复：正确转换URL路径为本地文件路径
        // file:///home/bitstream/... -> /home/bitstream/...
        var localPath = filePath.toString()
        if (localPath.startsWith("file://")) {
            localPath = localPath.substring(7)  // 移除 "file://"，保留 "/"
        }

        // 收集参数名和参数值
        var paramNames = []
        var paramValues = []

        for (var i = 0; i < paramModel.count; i++) {
            var name = paramModel.get(i).name

            // 关键修复：优先从userInputValues读取用户输入的值
            var value = userInputValues[name]
            if (value === undefined || value === "") {
                value = paramModel.get(i).value
            }

            // 关键修复：只保存有值的参数，跳过空值参数
            if (value !== undefined && value !== "") {
                paramNames.push(name)
                paramValues.push(value)
            }
        }

        if (paramNames.length === 0) {
            // 没有可保存的参数
            paramCompleteDialog.messageText = "没有可保存的参数"
            paramCompleteDialog.open()
            return
        }

        if (typeof paramFileManager !== 'undefined' && paramFileManager !== null) {
            var success = paramFileManager.saveParameters(localPath, paramNames, paramValues)

            if (success) {
                paramCompleteDialog.messageText = "参数已保存到文件"
                paramCompleteDialog.open()

                if (typeof displayProcessor !== 'undefined' && displayProcessor !== null) {
                    displayProcessor.addSystemText("参数已保存到文件: " + localPath + " (" + paramNames.length + " 个参数)")
                }
            } else {
                if (typeof displayProcessor !== 'undefined' && displayProcessor !== null) {
                    displayProcessor.addSystemText("保存文件失败")
                }
            }
        }
    }

    Component.onCompleted: {
        // 初始化已收到状态和重试计数
        for (var i = 0; i < paramConfigNames.length; i++) {
            paramRecvMap[paramConfigNames[i]] = false
            paramRetryCount[paramConfigNames[i]] = 0
            paramBuffer[paramConfigNames[i]] = ""
            userInputValues[paramConfigNames[i]] = ""
            paramSaveConfirmed[paramConfigNames[i]] = false
            paramSaveRetryCount[paramConfigNames[i]] = 0
        }
    }
}
