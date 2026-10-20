#ifndef DATATIMEOUTMANAGER_H
#define DATATIMEOUTMANAGER_H

#include <QObject>
#include <QTimer>
#include <QMap>
#include <QDateTime>

class DataTimeoutManager : public QObject
{
    Q_OBJECT

public:
    explicit DataTimeoutManager(QObject *parent = nullptr);
    ~DataTimeoutManager();

    // 更新数据项的时间戳
    Q_INVOKABLE void updateTimestamp(const QString &key);

    // 清空所有时间戳
    Q_INVOKABLE void clearAllTimestamps();

signals:
    // 当数据项超时时发出信号
    void dataTimeout(const QString &key);

private slots:
    void onTimeoutCheck();

private:
    void initializeDataItems();
    void resetDataItemTimestamp(const QString &key);

    QMap<QString, QDateTime> m_dataItemLastUpdate;
    QTimer *m_timeoutTimer;
    static const int DATA_TIMEOUT_SECONDS = 10;  // 10秒超时
    static const int CHECK_INTERVAL_MS = 500;    // 每500ms检查一次

    // 需要监控的数据项列表
    static const QStringList DATA_ITEMS;
};

#endif // DATATIMEOUTMANAGER_H