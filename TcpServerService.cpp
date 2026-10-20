#include "TcpServerService.h"
#include <QDebug>

TcpServerService::TcpServerService(int port, QObject *parent)
    : QObject(parent)
    , m_tcpServer(nullptr)
    , m_port(port)
    , m_isRunning(false)
    , m_heartbeatTimer(new QTimer(this))
{
    connect(m_heartbeatTimer, &QTimer::timeout, this, &TcpServerService::onHeartbeatTimer);
}

TcpServerService::~TcpServerService()
{
    stopServer();
}

bool TcpServerService::isRunning() const
{
    return m_isRunning;
}

int TcpServerService::connectedClientsCount() const
{
    return m_connectedClients.count();
}

void TcpServerService::startServer()
{
    if (m_isRunning) return;

    m_tcpServer = new QTcpServer(this);
    if (!m_tcpServer->listen(QHostAddress::Any, m_port)) {
        emit errorOccurred("启动TCP服务失败", m_tcpServer->errorString());
        delete m_tcpServer;
        m_tcpServer = nullptr;
        return;
    }

    m_isRunning = true;
    connect(m_tcpServer, &QTcpServer::newConnection, this, &TcpServerService::onNewConnection);
    
    // 启动心跳检测定时器（10秒间隔）
    m_heartbeatTimer->start(HEARTBEAT_INTERVAL);
    
    emit serverStatusChanged(QString("TCP服务已启动，端口 %1").arg(m_port));
    emit runningChanged();
}

void TcpServerService::stopServer()
{
    if (!m_isRunning) return;

    m_isRunning = false;
    
    // 停止心跳检测定时器
    m_heartbeatTimer->stop();

    for (auto client : m_connectedClients) {
        QString ip = client->peerAddress().toString();
        int port = client->peerPort();
        client->disconnectFromHost();
        emit clientDisconnected(ip, port, "服务停止", 0);
    }
    m_connectedClients.clear();

    if (m_tcpServer) {
        m_tcpServer->close();
        delete m_tcpServer;
        m_tcpServer = nullptr;
    }

    emit serverStatusChanged("TCP服务已停止");
    emit runningChanged();
    emit clientCountChanged();
}

void TcpServerService::sendDataToAll(const QByteArray &data)
{
    if (!m_isRunning) return;

    for (auto client : m_connectedClients) {
        if (client->state() == QAbstractSocket::ConnectedState) {
            client->write(data);
            client->flush();
        }
    }
}

void TcpServerService::onNewConnection()
{
    QTcpSocket *client = m_tcpServer->nextPendingConnection();
    QString ip = client->peerAddress().toString();
    int port = client->peerPort();

    m_connectedClients.append(client);

    connect(client, &QTcpSocket::readyRead, this, &TcpServerService::onClientReadyRead);
    connect(client, &QTcpSocket::disconnected, this, &TcpServerService::onClientDisconnected);

    emit clientConnected(ip, port, m_connectedClients.count());
    emit clientCountChanged();
    qDebug() << "[ClientConnected]" << ip << port;
}

void TcpServerService::onClientReadyRead()
{
    QTcpSocket *client = qobject_cast<QTcpSocket*>(sender());
    if (!client) return;

    QByteArray data = client->readAll();
    QString ip = client->peerAddress().toString();
    int port = client->peerPort();

    // 发送 QVariant 格式的数据（用于协议解析）
    emit dataReceived(QVariant(data), ip, port);

    // 发送十六进制字符串格式（用于日志显示）
    QString hexStr = data.toHex(' ');
    emit dataReceivedHex(hexStr, data.size(), ip, port);
}

void TcpServerService::onClientDisconnected()
{
    QTcpSocket *client = qobject_cast<QTcpSocket*>(sender());
    if (!client) return;

    QString ip = client->peerAddress().toString();
    int port = client->peerPort();

    m_connectedClients.removeOne(client);
    client->deleteLater();

    emit clientDisconnected(ip, port, "正常断开", m_connectedClients.count());
    emit clientCountChanged();
    qDebug() << "[ClientDisconnected]" << ip << port;
}

void TcpServerService::onHeartbeatTimer()
{
    if (!m_isRunning || m_connectedClients.isEmpty()) return;

    // 发送心跳检测命令"!"到所有客户端
    QByteArray heartbeatData = QByteArray(1, '!');  // 发送单个字符 '!'

    QList<QTcpSocket*> disconnectedClients;

    for (auto client : m_connectedClients) {
        if (client->state() == QAbstractSocket::ConnectedState) {
            qint64 bytesWritten = client->write(heartbeatData);
            client->flush();
            
            if (bytesWritten == -1) {
                // 发送失败，记录该客户端需要断开
                disconnectedClients.append(client);
            }
        } else {
            // 客户端状态不是ConnectedState，标记为需要断开
            disconnectedClients.append(client);
        }
    }

    // 处理断开的客户端
    for (auto client : disconnectedClients) {
        QString ip = client->peerAddress().toString();
        int port = client->peerPort();

        m_connectedClients.removeOne(client);
        client->disconnectFromHost();
        client->deleteLater();

        emit clientDisconnected(ip, port, "心跳检测失败", m_connectedClients.count());
        emit clientCountChanged();
    }
}