#include "ProtocolPacketBuilder.h"

QByteArray ProtocolPacketBuilder::buildPacket(const QString &applicationData)
{
    return buildPacket(applicationData.toUtf8());
}

QByteArray ProtocolPacketBuilder::buildPacket(const QByteArray &data)
{
    QByteArray packet;
    packet.append(0xAA);
    packet.append(0x55);

    // Length (little endian)
    packet.append(static_cast<char>(data.size() & 0xFF));
    packet.append(static_cast<char>((data.size() >> 8) & 0xFF));

    packet.append(data);

    quint8 crc = calculateCrc(data);
    packet.append(crc);

    return packet;
}

QByteArray ProtocolPacketBuilder::buildGetConfigPacket(const QString &configName)
{
    return buildPacket(QString("getconfig:%1").arg(configName));
}

QByteArray ProtocolPacketBuilder::buildSetConfigPacket(const QString &configName, const QString &value)
{
    return buildPacket(QString("setconfig:%1=%2").arg(configName, value));
}

QByteArray ProtocolPacketBuilder::buildSaveConfigPacket()
{
    return buildPacket(QString("saveconfig"));
}

QByteArray ProtocolPacketBuilder::buildCommandPacket(const QString &command)
{
    return buildPacket(command);
}

quint8 ProtocolPacketBuilder::calculateCrc(const QByteArray &data)
{
    // STM32 HAL_CRC_Calculate compatible CRC
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

quint32 ProtocolPacketBuilder::calculateCrc32(const QByteArray &data)
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