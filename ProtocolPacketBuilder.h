#ifndef PROTOCOLPACKETBUILDER_H
#define PROTOCOLPACKETBUILDER_H

#include <QByteArray>
#include <QString>

class ProtocolPacketBuilder
{
public:
    static QByteArray buildPacket(const QString &applicationData);
    static QByteArray buildPacket(const QByteArray &data);

    static QByteArray buildGetConfigPacket(const QString &configName);
    static QByteArray buildSetConfigPacket(const QString &configName, const QString &value);
    static QByteArray buildSaveConfigPacket();
    static QByteArray buildCommandPacket(const QString &command);

private:
    static quint8 calculateCrc(const QByteArray &data);
    static quint32 calculateCrc32(const QByteArray &data);
};

#endif // PROTOCOLPACKETBUILDER_H