#ifndef BATTERYSERVICE_H
#define BATTERYSERVICE_H

#include <QObject>
#include <QTimer>

// 读取本机(postmarketOS/Linux)电池电量
// 数据源: /sys/class/power_supply/<电池>/capacity 与 status
class BatteryService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int level READ level NOTIFY changed)         // 0-100，-1=未找到电池
    Q_PROPERTY(bool charging READ charging NOTIFY changed)

public:
    explicit BatteryService(QObject *parent = nullptr);

    int level() const { return m_level; }
    bool charging() const { return m_charging; }

signals:
    void changed();

private slots:
    void refresh();

private:
    QTimer *m_timer = nullptr;
    int m_level = -1;       // -1表示未找到电池（如Windows开发机），界面隐藏
    bool m_charging = false;
};

#endif // BATTERYSERVICE_H
