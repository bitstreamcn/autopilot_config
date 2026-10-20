#ifndef DATADISPLAYPROCESSOR_H
#define DATADISPLAYPROCESSOR_H

#include <QObject>
#include <QString>

class DataDisplayProcessor : public QObject
{
    Q_OBJECT

public:
    enum TextColorType {
        Default = 0,
        Error = 1,
        System = 2,
        NormalData = 3,
        Warning = 4,
        Critical = 5
    };

    explicit DataDisplayProcessor(QObject *parent = nullptr);

    Q_INVOKABLE void addText(const QString &text, int colorType = Default);
    Q_INVOKABLE void addSystemText(const QString &text);
    Q_INVOKABLE void addNormalDataText(const QString &text);
    Q_INVOKABLE void addErrorText(const QString &text);
    Q_INVOKABLE void addWarningText(const QString &text);
    Q_INVOKABLE void addCriticalText(const QString &text);

    Q_INVOKABLE QString currentTime() const;
    Q_INVOKABLE QString formatClientConnected(const QString &ipAddress, int port, int count);
    Q_INVOKABLE QString formatClientDisconnected(const QString &ipAddress, int port, const QString &reason, int count);
    Q_INVOKABLE QString formatServerStatus(const QString &status);
    Q_INVOKABLE QString formatError(const QString &operation, const QString &errorMessage);
    Q_INVOKABLE QString formatReceivedData(const QString &dataString, const QString &parseType = "");
    Q_INVOKABLE QString formatAbnormalData(const QByteArray &data, const QString &reason);
    Q_INVOKABLE QString byteArrayToHex(const QByteArray &data);  // 用于QML中显示数据包

signals:
    void displayTextReady(const QString &text, int colorType);
};

#endif // DATADISPLAYPROCESSOR_H