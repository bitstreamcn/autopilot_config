#include "Stm32ProtocolParser.h"
#include <QDebug>
#include <QRegularExpression>
#include <QString>

Stm32ProtocolParser::Stm32ProtocolParser(QObject *parent)
    : QObject(parent)
{
}

void Stm32ProtocolParser::processData(const QByteArray &data)
{
    for (auto byte : data) {
        m_receivedDataBuffer.append(static_cast<quint8>(byte));
    }
    processReceivedData();
}

void Stm32ProtocolParser::processDataFromVariant(const QVariant &data)
{
    if (data.typeId() == QMetaType::QByteArray) {
        QByteArray ba = data.toByteArray();
        processData(ba);
    } else {
        qWarning() << "Invalid data type for processDataFromVariant:" << data.typeName();
    }
}

void Stm32ProtocolParser::processReceivedData()
{
    while (m_receivedDataBuffer.size() >= 7) {
        // Check start flag
        if (m_receivedDataBuffer[0] == 0xAA && m_receivedDataBuffer[1] == 0x55) {
            int dataLength = (m_receivedDataBuffer[3] << 8) | m_receivedDataBuffer[2];

            if (dataLength > MAX_DATA_LENGTH) {
                // 提取错误数据
                QByteArray errorData;
                int bytesToCopy = qMin(20, m_receivedDataBuffer.size());  // 最多显示20字节
                for (int i = 0; i < bytesToCopy; i++) {
                    errorData.append(static_cast<char>(m_receivedDataBuffer[i]));
                }
                emit protocolError("数据长度异常", errorData);
                int nextStartIndex = findNextStartIndex(1);
                if (nextStartIndex > 0) {
                    for (int i = 0; i < nextStartIndex; i++) {
                        m_receivedDataBuffer.removeFirst();
                    }
                    continue;
                } else {
                    m_receivedDataBuffer.clear();
                    break;
                }
            }

            if (m_receivedDataBuffer.size() >= 4 + dataLength + 1) {
                bool hasStartFlagInData = checkStartFlagInData(4, dataLength);
                if (hasStartFlagInData) {
                    int actualLength = findActualDataLength();
                    if (actualLength > 0 && actualLength <= MAX_DATA_LENGTH) {
                        processDataWithActualLength(actualLength);
                    } else {
                        // 提取错误数据
                        QByteArray errorData;
                        int bytesToCopy = qMin(4 + dataLength + 1, m_receivedDataBuffer.size());
                        for (int i = 0; i < bytesToCopy; i++) {
                            errorData.append(static_cast<char>(m_receivedDataBuffer[i]));
                        }
                        emit protocolError("数据区内发现开始标志，长度异常", errorData);
                        for (int i = 0; i < 4 + dataLength + 1; i++) {
                            m_receivedDataBuffer.removeFirst();
                        }
                    }
                } else {
                    processNormalDataPacket(dataLength);
                }
            } else {
                break;
            }
        } else {
            int nextStartIndex = findNextStartIndex(0);
            if (nextStartIndex > 0) {
                // 提取错误数据
                QByteArray errorData;
                for (int i = 0; i < nextStartIndex; i++) {
                    errorData.append(static_cast<char>(m_receivedDataBuffer[i]));
                }
                emit protocolError("无效的开始标志", errorData);
                for (int i = 0; i < nextStartIndex; i++) {
                    m_receivedDataBuffer.removeFirst();
                }
            } else {
                // 提取全部数据作为错误数据
                QByteArray errorData;
                int bytesToCopy = qMin(20, m_receivedDataBuffer.size());  // 最多显示20字节
                for (int i = 0; i < bytesToCopy; i++) {
                    errorData.append(static_cast<char>(m_receivedDataBuffer[i]));
                }
                emit protocolError("无有效开始标志", errorData);
                m_receivedDataBuffer.clear();
                break;
            }
        }
    }
}

int Stm32ProtocolParser::findNextStartIndex(int startIndex)
{
    for (int i = startIndex; i < m_receivedDataBuffer.size() - 1; i++) {
        if (m_receivedDataBuffer[i] == 0xAA && m_receivedDataBuffer[i + 1] == 0x55) {
            return i;
        }
    }
    return -1;
}

bool Stm32ProtocolParser::checkStartFlagInData(int startIndex, int length)
{
    for (int i = startIndex; i < startIndex + length - 1; i++) {
        if (m_receivedDataBuffer[i] == 0xAA && m_receivedDataBuffer[i + 1] == 0x55) {
            return true;
        }
    }
    return false;
}

int Stm32ProtocolParser::findActualDataLength()
{
    for (int i = 2; i < m_receivedDataBuffer.size() - 1; i++) {
        if (m_receivedDataBuffer[i] == 0xAA && m_receivedDataBuffer[i + 1] == 0x55) {
            if (i >= 1) {
                quint8 possibleCrc = m_receivedDataBuffer[i - 1];
                int actualLength = i - 1 - 4;
                if (actualLength >= 0) {
                    QByteArray actualData;
                    for (int j = 4; j < 4 + actualLength; j++) {
                        actualData.append(static_cast<char>(m_receivedDataBuffer[j]));
                    }
                    quint8 calculatedCrc = calculateCrc(actualData);
                    if (calculatedCrc == possibleCrc) {
                        return actualLength;
                    }
                }
            }
        }
    }
    return -1;
}

void Stm32ProtocolParser::processDataWithActualLength(int actualLength)
{
    QByteArray dataBytes;
    for (int i = 4; i < 4 + actualLength; i++) {
        dataBytes.append(static_cast<char>(m_receivedDataBuffer[i]));
    }

    quint8 receivedCrc = m_receivedDataBuffer[4 + actualLength];
    quint8 calculatedCrc = calculateCrc(dataBytes);

    if (receivedCrc == calculatedCrc) {
        onDataParsed(dataBytes, "修正长度");
    } else {
        emit protocolError("CRC校验失败(修正长度)", dataBytes);
    }

    for (int i = 0; i < 4 + actualLength + 1; i++) {
        m_receivedDataBuffer.removeFirst();
    }
}

void Stm32ProtocolParser::processNormalDataPacket(int dataLength)
{
    QByteArray dataBytes;
    for (int i = 4; i < 4 + dataLength; i++) {
        dataBytes.append(static_cast<char>(m_receivedDataBuffer[i]));
    }

    quint8 receivedCrc = m_receivedDataBuffer[4 + dataLength];
    quint8 calculatedCrc = calculateCrc(dataBytes);

    if (receivedCrc == calculatedCrc) {
        onDataParsed(dataBytes, "正常");
    } else {
        emit protocolError(QString("CRC校验失败, 计算结果：%1, 收到：%2")
                          .arg(calculatedCrc).arg(receivedCrc), dataBytes);
    }

    for (int i = 0; i < 4 + dataLength + 1; i++) {
        m_receivedDataBuffer.removeFirst();
    }
}

quint8 Stm32ProtocolParser::calculateCrc(const QByteArray &data)
{
    int paddingLength = 4 - (data.size() % 4);

    QByteArray paddedData = data;
    for (int i = 0; i < paddingLength; i++) {
        paddedData.append('\0');
    }

    int numWords = (data.size() / 4) + 1;
    int bytesToCalculate = numWords * 4;

    QByteArray dataToCalculate = paddedData;
    if (bytesToCalculate < paddedData.size()) {
        dataToCalculate = paddedData.left(bytesToCalculate);
    }

    quint32 crcResult = calculateCrc32(dataToCalculate);

    quint8 crc = static_cast<quint8>(
        (crcResult & 0xFF) +
        ((crcResult >> 8) & 0xFF) +
        ((crcResult >> 16) & 0xFF) +
        ((crcResult >> 24) & 0xFF)
    );

    return crc;
}

quint32 Stm32ProtocolParser::calculateCrc32(const QByteArray &data)
{
    quint32 polynomial = 0x04C11DB7;
    quint32 crc = 0xFFFFFFFF;

    int numWords = data.size() / 4;
    for (int i = 0; i < numWords; i++) {
        quint32 word = static_cast<quint32>(
            static_cast<quint8>(data[i * 4]) |
            (static_cast<quint8>(data[i * 4 + 1]) << 8) |
            (static_cast<quint8>(data[i * 4 + 2]) << 16) |
            (static_cast<quint8>(data[i * 4 + 3]) << 24)
        );

        crc ^= word;

        for (int j = 0; j < 32; j++) {
            if (crc & 0x80000000) {
                crc = (crc << 1) ^ polynomial;
            } else {
                crc <<= 1;
            }
        }
    }

    return crc;
}

void Stm32ProtocolParser::onDataParsed(const QByteArray &data, const QString &parseType)
{
    QString dataString = QString::fromUtf8(data).trimmed();

    // Check log file data
    if (dataString.startsWith("-*-*- File:") || dataString.startsWith("-*-*- End of")) {
        emit logFileDataReceived(dataString);
        emit dataParsed(data, dataString, parseType);
        return;
    }

    // Check log content
    if (!dataString.contains("-*-*-") && QRegularExpression("^\\d+:").match(dataString).hasMatch()) {
        emit logFileDataReceived(dataString);
    }

    // Config data
    if (dataString.startsWith("[C]")) {
        QString configData = dataString.mid(3).trimmed();

        if (configData == "save ok") {
            emit configDataReceived("save", "ok", 2); // SaveConfirm
        } else if (configData.endsWith(" ok")) {
            QString name = configData.left(configData.length() - 3).trimmed();
            emit configDataReceived(name, "ok", 1); // SetConfirm
        } else {
            int equalIndex = configData.indexOf('=');
            if (equalIndex > 0) {
                QString name = configData.left(equalIndex).trimmed();
                QString value = configData.mid(equalIndex + 1).trimmed();
                emit configDataReceived(name, value, 0); // GetValue
            }
        }
        emit dataParsed(data, dataString, parseType);
        return;
    }

    // IMU Accel/Gyro (格式: ax=xxx,ay=xxx,az=xxx,gx=xxx,gy=xxx,gz=xxx) - 等号分隔
    if (dataString.contains("ax=") && dataString.contains("gx=")) {
        QRegularExpression axRx("ax=([\\-\\d.]+)");
        QRegularExpression ayRx("ay=([\\-\\d.]+)");
        QRegularExpression azRx("az=([\\-\\d.]+)");
        QRegularExpression gxRx("gx=([\\-\\d.]+)");
        QRegularExpression gyRx("gy=([\\-\\d.]+)");
        QRegularExpression gzRx("gz=([\\-\\d.]+)");

        auto axMatch = axRx.match(dataString);
        auto ayMatch = ayRx.match(dataString);
        auto azMatch = azRx.match(dataString);
        auto gxMatch = gxRx.match(dataString);
        auto gyMatch = gyRx.match(dataString);
        auto gzMatch = gzRx.match(dataString);

        if (axMatch.hasMatch() || gxMatch.hasMatch()) {
            float ax = axMatch.hasMatch() ? axMatch.captured(1).toFloat() : 0;
            float ay = ayMatch.hasMatch() ? ayMatch.captured(1).toFloat() : 0;
            float az = azMatch.hasMatch() ? azMatch.captured(1).toFloat() : 0;
            float gx = gxMatch.hasMatch() ? gxMatch.captured(1).toFloat() : 0;
            float gy = gyMatch.hasMatch() ? gyMatch.captured(1).toFloat() : 0;
            float gz = gzMatch.hasMatch() ? gzMatch.captured(1).toFloat() : 0;
            emit imuAccelGyroReceived(ax, ay, az, gx, gy, gz);
            return;
        }
    }

    // IMU Attitude (格式: roll=xxx,pitch=xxx,yaw=xxx) - 等号分隔
    if (dataString.contains("roll=") && dataString.contains("pitch=")) {
        QRegularExpression rollRx("roll=([\\-\\d.]+)");
        QRegularExpression pitchRx("pitch=([\\-\\d.]+)");
        QRegularExpression yawRx("yaw=([\\-\\d.]+)");

        auto rollMatch = rollRx.match(dataString);
        auto pitchMatch = pitchRx.match(dataString);
        auto yawMatch = yawRx.match(dataString);

        if (rollMatch.hasMatch() || pitchMatch.hasMatch()) {
            float roll = rollMatch.hasMatch() ? rollMatch.captured(1).toFloat() : 0;
            float pitch = pitchMatch.hasMatch() ? pitchMatch.captured(1).toFloat() : 0;
            float yaw = yawMatch.hasMatch() ? yawMatch.captured(1).toFloat() : 0;
            emit imuAttitudeReceived(roll, pitch, yaw);
            return;
        }
    }

    // IMU Alt/Velocity (实际格式: alt=xxx,v=xxx,accelup=xxx) - 注意是accelup不是accel_up
    // 参考程序格式示例: alt=0.054928 v=0.023771 accelup=0
    if (dataString.contains("alt=") && dataString.contains("v=")) {
        QRegularExpression altRx("alt=([\\-\\d.]+)");
        QRegularExpression vRx("v=([\\-\\d.]+)");
        // 关键修复：实际数据格式是accelup=（没有下划线），参考程序正则也是accelup=
        QRegularExpression accelUpRx("accelup=([\\-\\d.]+)");

        auto altMatch = altRx.match(dataString);
        auto vMatch = vRx.match(dataString);
        auto accelUpMatch = accelUpRx.match(dataString);

        if (altMatch.hasMatch()) {
            float alt = altMatch.captured(1).toFloat();
            float v = vMatch.hasMatch() ? vMatch.captured(1).toFloat() : 0;
            float accelUp = accelUpMatch.hasMatch() ? accelUpMatch.captured(1).toFloat() : 0;
            emit imuAltVelocityReceived(alt, v, accelUp);
            return;
        }
    }

    // Control Thr (格式: thr:xxx,roll:xxx,pitch:xxx,yaw:xxx) - 冒号分隔
    if (dataString.contains("thr:")) {
        QRegularExpression thrRx("thr:([\\-\\d.]+)");
        QRegularExpression rollRx(",roll:([\\-\\d.]+)");
        QRegularExpression pitchRx(",pitch:([\\-\\d.]+)");
        QRegularExpression yawRx(",yaw:([\\-\\d.]+)");

        auto thrMatch = thrRx.match(dataString);
        auto rollMatch = rollRx.match(dataString);
        auto pitchMatch = pitchRx.match(dataString);
        auto yawMatch = yawRx.match(dataString);

        if (thrMatch.hasMatch()) {
            float thr = thrMatch.captured(1).toFloat();
            float ctrlRoll = rollMatch.hasMatch() ? rollMatch.captured(1).toFloat() : 0;
            float ctrlPitch = pitchMatch.hasMatch() ? pitchMatch.captured(1).toFloat() : 0;
            float ctrlYaw = yawMatch.hasMatch() ? yawMatch.captured(1).toFloat() : 0;
            emit controlThrReceived(thr, ctrlRoll, ctrlPitch, ctrlYaw);
            return;
        }
    }

    // Location (格式: [LOC]x:xxx,y:xxx,vx:xxx,vy:xxx) - 冒号分隔，带[LOC]前缀
    if (dataString.contains("[LOC]")) {
        QRegularExpression xRx("\\[LOC\\]x:([\\-\\d.]+)");
        QRegularExpression yRx(",y:([\\-\\d.]+)");
        QRegularExpression vxRx(",vx:([\\-\\d.]+)");
        QRegularExpression vyRx(",vy:([\\-\\d.]+)");

        auto xMatch = xRx.match(dataString);
        auto yMatch = yRx.match(dataString);
        auto vxMatch = vxRx.match(dataString);
        auto vyMatch = vyRx.match(dataString);

        if (xMatch.hasMatch() || yMatch.hasMatch()) {
            float x = xMatch.hasMatch() ? xMatch.captured(1).toFloat() : 0;
            float y = yMatch.hasMatch() ? yMatch.captured(1).toFloat() : 0;
            float vx = vxMatch.hasMatch() ? vxMatch.captured(1).toFloat() : 0;
            float vy = vyMatch.hasMatch() ? vyMatch.captured(1).toFloat() : 0;
            emit locationDataReceived(x, y, vx, vy);
            return;
        }
    }

    // Flow (格式: pmw3901=> tx:xxx ty:xxx x:xxx y:xxx) - 冒号分隔，带pmw3901=>前缀
    if (dataString.contains("pmw3901=>")) {
        QRegularExpression txRx(" tx:([\\-\\d.]+)");
        QRegularExpression tyRx(" ty:([\\-\\d.]+)");
        QRegularExpression xRx(" x:([\\-\\d.]+)");
        QRegularExpression yRx(" y:([\\-\\d.]+)");

        auto txMatch = txRx.match(dataString);
        auto tyMatch = tyRx.match(dataString);
        auto xMatch = xRx.match(dataString);
        auto yMatch = yRx.match(dataString);

        if (txMatch.hasMatch() || xMatch.hasMatch()) {
            float tx = txMatch.hasMatch() ? txMatch.captured(1).toFloat() : 0;
            float ty = tyMatch.hasMatch() ? tyMatch.captured(1).toFloat() : 0;
            float x = xMatch.hasMatch() ? xMatch.captured(1).toFloat() : 0;
            float y = yMatch.hasMatch() ? yMatch.captured(1).toFloat() : 0;
            emit flowDataReceived(tx, ty, x, y);
            return;
        }
    }

    // Dest Alt (实际格式: dest_alt:xxx, current_alt:xxx) - 注意current_alt前有空格
    // 参考程序格式示例: dest_alt:0.000000, current_alt:0.000000
    if (dataString.contains("dest_alt:") && dataString.contains("current_alt:")) {
        QRegularExpression destAltRx("dest_alt:([\\-\\d.]+)");
        // 关键修复：实际数据格式中current_alt前面有空格（逗号后有空格）
        QRegularExpression currentAltRx(", current_alt:([\\-\\d.]+)");  // 添加空格和逗号前缀

        auto destAltMatch = destAltRx.match(dataString);
        auto currentAltMatch = currentAltRx.match(dataString);

        if (destAltMatch.hasMatch()) {
            float destAlt = destAltMatch.captured(1).toFloat();
            float currentAlt = currentAltMatch.hasMatch() ? currentAltMatch.captured(1).toFloat() : 0;
            emit destAltDataReceived(destAlt, currentAlt);
            return;
        }
    }

    // RC Data (遥控数据) (格式: Roll:xxx,Pitch:xxx,Yaw:xxx,Throttle:xxx) - 冒号分隔，逗号分隔数据项
    if (dataString.contains("Roll:") && dataString.contains("Pitch:")) {
        // 关键修复：从 "Roll:" 开始截取字符串（参考程序的做法）
        // 数据字符串可能包含前缀，例如 "[I] Roll:xxx,Pitch:xxx,..."
        int startIndex = dataString.indexOf("Roll:");
        QString rcData = dataString.mid(startIndex);  // 从 "Roll:" 开始截取
        
        // 使用逗号分隔数据项
        QStringList parts = rcData.split(',');
        float roll = 0, pitch = 0, yaw = 0, throttle = 0;
        bool matched = false;

        for (const QString& part : parts) {
            // 使用冒号分隔键值对
            QStringList keyValue = part.split(':');
            if (keyValue.size() >= 2) {
                QString key = keyValue[0].trimmed();
                QString valueStr = keyValue[1].trimmed();

                // 解析整数值（使用ok参数判断转换是否成功）
                bool ok;
                int value = valueStr.toInt(&ok);

                if (ok) {  // 确保成功转换
                    if (key == "Roll") {
                        roll = value;
                        matched = true;
                    } else if (key == "Pitch") {
                        pitch = value;
                        matched = true;
                    } else if (key == "Yaw") {
                        yaw = value;
                        matched = true;
                    } else if (key == "Throttle") {
                        throttle = value;
                        matched = true;
                    }
                }
            }
        }

        if (matched) {
            emit rcDataReceived(roll, pitch, yaw, throttle);
            return;
        }
    }

    // Frequency Data (频率数据) (格式: [Freq] Name : Value Hz)
    if (dataString.contains("[Freq]")) {
        // 格式: [I] [Freq] 200hz : 200.0 Hz
        int freqIndex = dataString.indexOf("[Freq]");
        QString afterFreq = dataString.mid(freqIndex + 6).trimmed();
        int colonIndex = afterFreq.indexOf(" : ");

        // 关键修复：只有格式正确（colonIndex > 0）才解析
        if (colonIndex > 0) {
            QString name = afterFreq.left(colonIndex).trimmed();
            QString valueStr = afterFreq.mid(colonIndex + 3).trimmed();

            // 去掉 " Hz" 后缀
            if (valueStr.endsWith(" Hz")) {
                valueStr = valueStr.left(valueStr.length() - 3);
            }

            // 关键修复：检查name是否是右侧面板支持的频率项
            QStringList supportedFreqNames = {"200hz", "OnPacketIn", "OnRxDone", "Response", "OnPacketChannels", "Application::Loop"};
            
            if (supportedFreqNames.contains(name)) {
                // 匹配成功：保留浮点数精度，不转换为整数（参考程序直接使用字符串）
                float freq = valueStr.toFloat();
                emit freqDataReceived(name, freq);  // 传递float，不是int
                return;  // ✅ 只有真正匹配成功才return
            }
        }
        
        // 格式不正确或name不支持，不return，继续尝试其他匹配逻辑
    }

    // GPS Data (格式: [gps]fixType:%d, numSV:%d, fLon:%f, fLat:%f, hAcc:%ld, ds:%f, dx:%f, dy:%f, hds:%f, hx:%f, hy:%f)
    if (dataString.contains("[gps]")) {
        QRegularExpression fixTypeRx("fixType:(\\d+)");
        QRegularExpression numSVRx("numSV:(\\d+)");
        QRegularExpression fLonRx("fLon:([\\-\\d.]+)");
        QRegularExpression fLatRx("fLat:([\\-\\d.]+)");
        QRegularExpression hAccRx("hAcc:(\\d+)");
        QRegularExpression dsRx("ds:([\\-\\d.]+)");
        QRegularExpression dxRx("dx:([\\-\\d.]+)");
        QRegularExpression dyRx("dy:([\\-\\d.]+)");
        QRegularExpression hdsRx("hds:([\\-\\d.]+)");
        QRegularExpression hxRx("hx:([\\-\\d.]+)");
        QRegularExpression hyRx("hy:([\\-\\d.]+)");

        auto fixTypeMatch = fixTypeRx.match(dataString);
        auto numSVMatch = numSVRx.match(dataString);
        auto fLonMatch = fLonRx.match(dataString);
        auto fLatMatch = fLatRx.match(dataString);
        auto hAccMatch = hAccRx.match(dataString);
        auto dsMatch = dsRx.match(dataString);
        auto dxMatch = dxRx.match(dataString);
        auto dyMatch = dyRx.match(dataString);
        auto hdsMatch = hdsRx.match(dataString);
        auto hxMatch = hxRx.match(dataString);
        auto hyMatch = hyRx.match(dataString);

        if (fixTypeMatch.hasMatch()) {
            int fixType = fixTypeMatch.captured(1).toInt();
            int numSV = numSVMatch.hasMatch() ? numSVMatch.captured(1).toInt() : 0;
            float fLon = fLonMatch.hasMatch() ? fLonMatch.captured(1).toFloat() : 0;
            float fLat = fLatMatch.hasMatch() ? fLatMatch.captured(1).toFloat() : 0;
            qint64 hAcc = hAccMatch.hasMatch() ? hAccMatch.captured(1).toLongLong() : 0;
            float ds = dsMatch.hasMatch() ? dsMatch.captured(1).toFloat() : 0;
            float dx = dxMatch.hasMatch() ? dxMatch.captured(1).toFloat() : 0;
            float dy = dyMatch.hasMatch() ? dyMatch.captured(1).toFloat() : 0;
            float hds = hdsMatch.hasMatch() ? hdsMatch.captured(1).toFloat() : 0;
            float hx = hxMatch.hasMatch() ? hxMatch.captured(1).toFloat() : 0;
            float hy = hyMatch.hasMatch() ? hyMatch.captured(1).toFloat() : 0;

            emit gpsDataReceived(fixType, numSV, fLon, fLat, hAcc, ds, dx, dy, hds, hx, hy);
            return;
        }
    }

    // 未识别的数据才发送dataParsed信号显示在日志中
    emit dataParsed(data, dataString, parseType);
}