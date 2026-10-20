#ifndef TCPSERVERSERVICE_H
#define TCPSERVERSERVICE_H

#include <QObject>
#include <QTcpServer>
#include <QTcpSocket>
#include <QList>
#include <QTimer>

class TcpServerService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isRunning READ isRunning NOTIFY runningChanged)
    Q_PROPERTY(int connectedClientsCount READ connectedClientsCount NOTIFY clientCountChanged)

public:
    explicit TcpServerService(int port = 26413, QObject *parent = nullptr);
    ~TcpServerService();

    bool isRunning() const;
    int connectedClientsCount() const;

public slots:
    void startServer();
    void stopServer();
    void sendDataToAll(const QByteArray &data);

signals:
    void clientConnected(const QString &ipAddress, int port, int count);
    void clientDisconnected(const QString &ipAddress, int port, const QString &reason, int count);
    void dataReceived(const QVariant &data, const QString &ipAddress, int port);  // 使用 QVariant 以便 QML 可以访问
    void dataReceivedHex(const QString &hexData, int length, const QString &ipAddress, int port);  // 十六进制格式
    void serverStatusChanged(const QString &status);
    void runningChanged();
    void clientCountChanged();
    void errorOccurred(const QString &operation, const QString &errorMessage);

private slots:
    void onNewConnection();
    void onClientReadyRead();
    void onClientDisconnected();
    void onHeartbeatTimer();  // 心跳检测定时器

private:
    QTcpServer *m_tcpServer;
    QList<QTcpSocket*> m_connectedClients;
    int m_port;
    bool m_isRunning;
    QTimer *m_heartbeatTimer;  // 心跳检测定时器
    static const int HEARTBEAT_INTERVAL = 10000;  // 10秒间隔
};

#endif // TCPSERVERSERVICE_H