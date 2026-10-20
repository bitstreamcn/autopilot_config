#ifndef PROTOCOLPACKETBUILDERWRAPPER_H
#define PROTOCOLPACKETBUILDERWRAPPER_H

#include <QObject>
#include <QByteArray>
#include <QString>

class ProtocolPacketBuilderWrapper : public QObject
{
    Q_OBJECT

public:
    explicit ProtocolPacketBuilderWrapper(QObject *parent = nullptr) : QObject(parent) {}

    Q_INVOKABLE QByteArray buildPacket(const QString &applicationData) {
        QByteArray data = applicationData.toUtf8();
        return buildPacketFromData(data);
    }

    Q_INVOKABLE QByteArray buildPacketFromData(const QByteArray &data);

    Q_INVOKABLE QByteArray buildGetConfigPacket(const QString &configName) {
        return buildPacket(QString("getconfig:%1").arg(configName));
    }

    Q_INVOKABLE QByteArray buildSetConfigPacket(const QString &configName, const QString &value) {
        return buildPacket(QString("setconfig:%1=%2").arg(configName, value));
    }

    Q_INVOKABLE QByteArray buildSaveConfigPacket() {
        return buildPacket(QString("saveconfig"));
    }

    Q_INVOKABLE QByteArray buildCommandPacket(const QString &command) {
        return buildPacket(command);
    }

private:
    static quint8 calculateCrc(const QByteArray &data);
    static quint32 calculateCrc32(const QByteArray &data);
};

#endif // PROTOCOLPACKETBUILDERWRAPPER_H