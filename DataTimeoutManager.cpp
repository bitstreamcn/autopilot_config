#include "DataTimeoutManager.h"
#include <QDebug>

const QStringList DataTimeoutManager::DATA_ITEMS = {
    "Roll", "Pitch", "Yaw", "Throttle",
    "200hz", "OnPacketIn", "OnRxDone", "Response", "OnPacketChannels", "Application::Loop",
    "ControlThr", "LocationData", "FlowData",
    "ImuAccelGyro", "ImuAttitude", "ImuAltVel", "ImuAccelUp", "DestAlt",
    "Gps"
};

DataTimeoutManager::DataTimeoutManager(QObject *parent)
    : QObject(parent)
    , m_timeoutTimer(new QTimer(this))
{
    initializeDataItems();

    m_timeoutTimer->setInterval(CHECK_INTERVAL_MS);
    connect(m_timeoutTimer, &QTimer::timeout, this, &DataTimeoutManager::onTimeoutCheck);
    m_timeoutTimer->start();
}

DataTimeoutManager::~DataTimeoutManager()
{
    if (m_timeoutTimer) {
        m_timeoutTimer->stop();
    }
}

void DataTimeoutManager::initializeDataItems()
{
    for (const QString &item : DATA_ITEMS) {
        m_dataItemLastUpdate[item] = QDateTime();
    }
}

void DataTimeoutManager::updateTimestamp(const QString &key)
{
    if (m_dataItemLastUpdate.contains(key)) {
        m_dataItemLastUpdate[key] = QDateTime::currentDateTime();
    }
}

void DataTimeoutManager::clearAllTimestamps()
{
    for (const QString &item : DATA_ITEMS) {
        m_dataItemLastUpdate[item] = QDateTime();
    }
}

void DataTimeoutManager::resetDataItemTimestamp(const QString &key)
{
    m_dataItemLastUpdate[key] = QDateTime();
}

void DataTimeoutManager::onTimeoutCheck()
{
    QDateTime now = QDateTime::currentDateTime();

    for (auto it = m_dataItemLastUpdate.begin(); it != m_dataItemLastUpdate.end(); ++it) {
        const QString &key = it.key();
        const QDateTime &lastUpdate = it.value();

        // 如果时间戳有效且超过超时时间
        if (lastUpdate.isValid()) {
            qint64 elapsedMs = lastUpdate.msecsTo(now);
            if (elapsedMs > DATA_TIMEOUT_SECONDS * 1000) {
                // 发出超时信号
                emit dataTimeout(key);

                // 重置时间戳
                resetDataItemTimestamp(key);
            }
        }
    }
}