#ifndef STM32PROTOCOLPARSER_H
#define STM32PROTOCOLPARSER_H

#include <QObject>
#include <QByteArray>
#include <QList>

class Stm32ProtocolParser : public QObject
{
    Q_OBJECT

public:
    explicit Stm32ProtocolParser(QObject *parent = nullptr);

    Q_INVOKABLE void processData(const QByteArray &data);
    Q_INVOKABLE void processDataFromVariant(const QVariant &data);  // 用于 QML 调用

signals:
    void dataParsed(const QByteArray &data, const QString &dataString, const QString &parseType);
    void protocolError(const QString &reason, const QByteArray &data);
    void configDataReceived(const QString &name, const QString &value, int dataType);
    void imuAccelGyroReceived(float ax, float ay, float az, float gx, float gy, float gz);
    void imuAttitudeReceived(float roll, float pitch, float yaw);
    void imuAltVelocityReceived(float alt, float v, float accelUp);
    void controlThrReceived(float thr, float ctrlRoll, float ctrlPitch, float ctrlYaw);
    void locationDataReceived(float x, float y, float vx, float vy);
    void flowDataReceived(float tx, float ty, float x, float y);
    void destAltDataReceived(float destAlt, float currentAlt);
    void logFileDataReceived(const QString &data);
    void rcDataReceived(float roll, float pitch, float yaw, float throttle);
    void freqDataReceived(const QString &name, float freq);
    void gpsDataReceived(int fixType, int numSV, float fLon, float fLat, qint64 hAcc, float ds, float dx, float dy, float hds, float hx, float hy);

private:
    void processReceivedData();
    int findNextStartIndex(int startIndex);
    bool checkStartFlagInData(int startIndex, int length);
    int findActualDataLength();
    void processDataWithActualLength(int actualLength);
    void processNormalDataPacket(int dataLength);
    quint8 calculateCrc(const QByteArray &data);
    quint32 calculateCrc32(const QByteArray &data);
    void onDataParsed(const QByteArray &data, const QString &parseType);

    QList<quint8> m_receivedDataBuffer;
    static const int MAX_DATA_LENGTH = 256;
};

#endif // STM32PROTOCOLPARSER_H