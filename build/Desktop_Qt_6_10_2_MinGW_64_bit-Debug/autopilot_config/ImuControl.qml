import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ScrollView {
    id: root

    // 字体大小 - 手机显示需要更大的字体
    property int fontSmall: 24
    property int fontNormal: 28
    property int fontLarge: 32

    // 当前tab索引（从Main.qml传入）
    property int currentTab: 0

    property real roll: 0
    property real pitch: 0
    property real yaw: 0

    property var axHistory: []
    property var ayHistory: []
    property var azHistory: []
    property var gxHistory: []
    property var gyHistory: []
    property var gzHistory: []

    property int maxPoints: 200

    function updateAccelGyro(ax, ay, az, gx, gy, gz) {
        // 数据总是保存到history数组（确保切换tab后能看到历史数据）
        axHistory.push(ax)
        ayHistory.push(ay)
        azHistory.push(az)
        gxHistory.push(gx)
        gyHistory.push(gy)
        gzHistory.push(gz)

        if (axHistory.length > maxPoints) {
            axHistory.shift()
            ayHistory.shift()
            azHistory.shift()
            gxHistory.shift()
            gyHistory.shift()
            gzHistory.shift()
        }

        // 关键修复：只在IMU tab页面时才触发Canvas重绘（避免其他页面闪烁）
        if (currentTab === 2) {
            accelCanvas.requestPaint()
            gyroCanvas.requestPaint()
        }
    }

    function updateAttitude(r, p, y) {
        // 数据总是保存（确保切换tab后能看到历史数据）
        roll = r
        pitch = p
        yaw = y
        
        // 关键修复：只在IMU tab页面时才触发Canvas重绘（避免其他页面闪烁）
        if (currentTab === 2) {
            rollCanvas.requestPaint()
            pitchCanvas.requestPaint()
            yawCanvas.requestPaint()
        }
    }

    contentWidth: availableWidth
    contentHeight: contentColumn.height

    ColumnLayout {
        id: contentColumn
        width: root.availableWidth
        spacing: 10

        // Attitude indicators (top) - 横向排列 Roll/Pitch/Yaw
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 150  // 固定高度，不再使用比例
            Layout.maximumHeight: 150
            spacing: 10

            // Roll indicator
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 5

                Label { text: "Roll: " + roll.toFixed(1) + "°"; font.bold: true; font.pixelSize: fontLarge; color: "darkblue"; Layout.alignment: Qt.AlignHCenter }

                Canvas {
                    id: rollCanvas
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)

                        var centerX = width / 2
                        var centerY = height / 2
                        var lineLength = Math.min(width, height) * 0.35

                        // Draw crosshair
                        ctx.strokeStyle = "gray"
                        ctx.lineWidth = 1
                        ctx.beginPath()
                        ctx.moveTo(10, centerY)
                        ctx.lineTo(width - 10, centerY)
                        ctx.moveTo(centerX, 10)
                        ctx.lineTo(centerX, height - 10)
                        ctx.stroke()

                        // Draw roll indicator
                        var rollRad = roll * Math.PI / 180
                        ctx.strokeStyle = "darkblue"
                        ctx.lineWidth = 3
                        ctx.beginPath()
                        ctx.moveTo(centerX - lineLength * Math.cos(rollRad), centerY - lineLength * Math.sin(rollRad))
                        ctx.lineTo(centerX + lineLength * Math.cos(rollRad), centerY + lineLength * Math.sin(rollRad))
                        ctx.stroke()

                        // Draw circles at ends
                        ctx.fillStyle = "darkblue"
                        ctx.beginPath()
                        ctx.arc(centerX - lineLength * Math.cos(rollRad), centerY - lineLength * Math.sin(rollRad), 5, 0, 2 * Math.PI)
                        ctx.fill()
                        ctx.beginPath()
                        ctx.arc(centerX + lineLength * Math.cos(rollRad), centerY + lineLength * Math.sin(rollRad), 5, 0, 2 * Math.PI)
                        ctx.fill()
                    }
                }
            }

            // Pitch indicator
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 5

                Label { text: "Pitch: " + pitch.toFixed(1) + "°"; font.bold: true; font.pixelSize: fontLarge; color: "darkgreen"; Layout.alignment: Qt.AlignHCenter }

                Canvas {
                    id: pitchCanvas
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)

                        var centerX = width / 2
                        var centerY = height / 2

                        // Draw crosshair
                        ctx.strokeStyle = "gray"
                        ctx.lineWidth = 1
                        ctx.beginPath()
                        ctx.moveTo(10, centerY)
                        ctx.lineTo(width - 10, centerY)
                        ctx.moveTo(centerX, 10)
                        ctx.lineTo(centerX, height - 10)
                        ctx.stroke()

                        // Draw horizon line
                        ctx.strokeStyle = "gray"
                        ctx.lineWidth = 2
                        ctx.setLineDash([5, 3])
                        ctx.beginPath()
                        ctx.moveTo(20, centerY)
                        ctx.lineTo(width - 20, centerY)
                        ctx.stroke()
                        ctx.setLineDash([])

                        // Draw pitch indicator (3D perspective triangle)
                        // 参考程序的3D透视投影逻辑
                        var triangleWidth = width * 0.35
                        var triangleDepth = height * 0.45
                        var pitchRad = pitch * Math.PI / 180

                        var cosP = Math.cos(pitchRad)
                        var sinP = Math.sin(pitchRad)

                        // 3D coordinates (Z: depth, negative = into screen)
                        // Tip points into screen (negative Z)
                        var tipX3D = 0
                        var tipY3D = 0
                        var tipZ3D = -triangleDepth

                        // Base points point out of screen (positive Z)
                        var baseLeftX3D = -triangleWidth / 2
                        var baseLeftY3D = 0
                        var baseLeftZ3D = triangleDepth * 0.3

                        var baseRightX3D = triangleWidth / 2
                        var baseRightY3D = 0
                        var baseRightZ3D = triangleDepth * 0.3

                        // Apply pitch rotation (rotate around X-axis)
                        // Y_rotated = Y * cos(pitch) - Z * sin(pitch)
                        // Z_rotated = Y * sin(pitch) + Z * cos(pitch)
                        var tipYRotated = tipY3D * cosP - tipZ3D * sinP
                        var baseLeftYRotated = baseLeftY3D * cosP - baseLeftZ3D * sinP
                        var baseRightYRotated = baseRightY3D * cosP - baseRightZ3D * sinP

                        // Project to 2D (Y_screen = -Y_rotated because screen Y is inverted)
                        var tipY2D = -tipYRotated
                        var tipX2D = tipX3D

                        var baseLeftY2D = -baseLeftYRotated
                        var baseLeftX2D = baseLeftX3D

                        var baseRightY2D = -baseRightYRotated
                        var baseRightX2D = baseRightX3D

                        // Convert to screen coordinates
                        var tipScreenX = centerX + tipX2D
                        var tipScreenY = centerY + tipY2D

                        var baseLeftScreenX = centerX + baseLeftX2D
                        var baseLeftScreenY = centerY + baseLeftY2D

                        var baseRightScreenX = centerX + baseRightX2D
                        var baseRightScreenY = centerY + baseRightY2D

                        // Draw triangle
                        ctx.fillStyle = "green"
                        ctx.strokeStyle = "darkgreen"
                        ctx.lineWidth = 2
                        ctx.beginPath()
                        ctx.moveTo(tipScreenX, tipScreenY)
                        ctx.lineTo(baseLeftScreenX, baseLeftScreenY)
                        ctx.lineTo(baseRightScreenX, baseRightScreenY)
                        ctx.closePath()
                        ctx.fill()
                        ctx.stroke()
                    }
                }
            }

            // Yaw indicator
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 5

                Label { text: "Yaw: " + yaw.toFixed(1) + "°"; font.bold: true; font.pixelSize: fontLarge; color: "orangered"; Layout.alignment: Qt.AlignHCenter }

                Canvas {
                    id: yawCanvas
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)

                        var centerX = width / 2
                        var centerY = height / 2
                        var radius = Math.min(width, height) * 0.35

                        // Draw circle
                        ctx.strokeStyle = "gray"
                        ctx.lineWidth = 1
                        ctx.beginPath()
                        ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI)
                        ctx.stroke()

                        // Draw tick marks
                        for (var i = 0; i < 8; i++) {
                            var angle = i * 45 * Math.PI / 180
                            ctx.beginPath()
                            ctx.moveTo(centerX + radius * 0.9 * Math.sin(angle), centerY - radius * 0.9 * Math.cos(angle))
                            ctx.lineTo(centerX + radius * Math.sin(angle), centerY - radius * Math.cos(angle))
                            ctx.stroke()
                        }

                        // Draw yaw arrow
                        var yawRad = yaw * Math.PI / 180
                        var arrowLength = radius * 0.8
                        var arrowX = centerX + arrowLength * Math.sin(yawRad)
                        var arrowY = centerY - arrowLength * Math.cos(yawRad)

                        ctx.strokeStyle = "orangered"
                        ctx.lineWidth = 3
                        ctx.beginPath()
                        ctx.moveTo(centerX, centerY)
                        ctx.lineTo(arrowX, arrowY)
                        ctx.stroke()

                        // Arrow head
                        var arrowAngle = Math.atan2(arrowY - centerY, arrowX - centerX)
                        ctx.fillStyle = "orangered"
                        ctx.beginPath()
                        ctx.moveTo(arrowX, arrowY)
                        ctx.lineTo(arrowX - 10 * Math.cos(arrowAngle - 0.4), arrowY - 10 * Math.sin(arrowAngle - 0.4))
                        ctx.lineTo(arrowX - 10 * Math.cos(arrowAngle + 0.4), arrowY - 10 * Math.sin(arrowAngle + 0.4))
                        ctx.closePath()
                        ctx.fill()
                    }
                }
            }
        }

        // Waveforms - 加速度波形和陀螺仪波形左右排列
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 250
            spacing: 10

            // Acceleration waveform (左侧)
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 5

                Label { text: "加速度波形"; font.bold: true; font.pixelSize: fontLarge; color: "black"; Layout.alignment: Qt.AlignHCenter }

                Canvas {
                    id: accelCanvas
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)

                        var leftMargin = 60
                        var bottomMargin = 30
                        var plotWidth = width - leftMargin
                        var plotHeight = height - bottomMargin
                        var centerY = plotHeight / 2

                        // Grid
                        ctx.strokeStyle = "#b0b0b0"
                        ctx.lineWidth = 0.5
                        for (var i = 0; i <= 10; i++) {
                            var y = i * plotHeight / 10
                            ctx.beginPath()
                            ctx.moveTo(leftMargin, y)
                            ctx.lineTo(width, y)
                            ctx.stroke()
                        }

                        // Y labels
                        ctx.fillStyle = "gray"
                        ctx.font = "14px sans-serif"
                        var yValues = [5, 4, 3, 2, 1, 0, -1, -2, -3, -4, -5]
                        for (var i = 0; i < 11; i++) {
                            ctx.fillText(yValues[i], 5, i * plotHeight / 10 + 8)
                        }

                        // Draw waveforms
                        var scaleY = plotHeight / 10.0
                        var scaleX = plotWidth / maxPoints

                        if (axHistory.length < 2) return

                        // AX - red
                        ctx.strokeStyle = "red"
                        ctx.lineWidth = 1.5
                        ctx.beginPath()
                        for (var i = 0; i < axHistory.length; i++) {
                            var x = leftMargin + i * scaleX
                            var y = centerY - axHistory[i] * scaleY
                            if (i === 0) ctx.moveTo(x, y)
                            else ctx.lineTo(x, y)
                        }
                        ctx.stroke()

                        // AY - green
                        ctx.strokeStyle = "green"
                        ctx.beginPath()
                        for (var i = 0; i < ayHistory.length; i++) {
                            var x = leftMargin + i * scaleX
                            var y = centerY - ayHistory[i] * scaleY
                            if (i === 0) ctx.moveTo(x, y)
                            else ctx.lineTo(x, y)
                        }
                        ctx.stroke()

                        // AZ - blue
                        ctx.strokeStyle = "blue"
                        ctx.beginPath()
                        for (var i = 0; i < azHistory.length; i++) {
                            var x = leftMargin + i * scaleX
                            var y = centerY - azHistory[i] * scaleY
                            if (i === 0) ctx.moveTo(x, y)
                            else ctx.lineTo(x, y)
                        }
                        ctx.stroke()
                    }
                }
            }

            // Gyro waveform (右侧)
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 5

                Label { text: "陀螺仪波形"; font.bold: true; font.pixelSize: fontLarge; color: "black"; Layout.alignment: Qt.AlignHCenter }

                Canvas {
                    id: gyroCanvas
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)

                        var leftMargin = 60
                        var bottomMargin = 30
                        var plotWidth = width - leftMargin
                        var plotHeight = height - bottomMargin
                        var centerY = plotHeight / 2

                        // Grid
                        ctx.strokeStyle = "#b0b0b0"
                        ctx.lineWidth = 0.5
                        for (var i = 0; i <= 12; i++) {
                            var y = i * plotHeight / 12
                            ctx.beginPath()
                            ctx.moveTo(leftMargin, y)
                            ctx.lineTo(width, y)
                            ctx.stroke()
                        }

                        // Y labels
                        ctx.fillStyle = "gray"
                        ctx.font = "14px sans-serif"
                        var yValues = [300, 250, 200, 150, 100, 50, 0, -50, -100, -150, -200, -250, -300]
                        for (var i = 0; i < 13; i++) {
                            ctx.fillText(yValues[i], 5, i * plotHeight / 12 + 8)
                        }

                        // Draw waveforms
                        var scaleY = plotHeight / 600.0
                        var scaleX = plotWidth / maxPoints

                        if (gxHistory.length < 2) return

                        // GX - orange
                        ctx.strokeStyle = "orange"
                        ctx.lineWidth = 1.5
                        ctx.beginPath()
                        for (var i = 0; i < gxHistory.length; i++) {
                            var x = leftMargin + i * scaleX
                            var y = centerY - gxHistory[i] * scaleY
                            if (i === 0) ctx.moveTo(x, y)
                            else ctx.lineTo(x, y)
                        }
                        ctx.stroke()

                        // GY - purple
                        ctx.strokeStyle = "purple"
                        ctx.beginPath()
                        for (var i = 0; i < gyHistory.length; i++) {
                            var x = leftMargin + i * scaleX
                            var y = centerY - gyHistory[i] * scaleY
                            if (i === 0) ctx.moveTo(x, y)
                            else ctx.lineTo(x, y)
                        }
                        ctx.stroke()

                        // GZ - brown
                        ctx.strokeStyle = "brown"
                        ctx.beginPath()
                        for (var i = 0; i < gzHistory.length; i++) {
                            var x = leftMargin + i * scaleX
                            var y = centerY - gzHistory[i] * scaleY
                            if (i === 0) ctx.moveTo(x, y)
                            else ctx.lineTo(x, y)
                        }
                        ctx.stroke()
                    }
                }
            }
        }
    }
}