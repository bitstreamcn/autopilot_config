#include "BatteryService.h"
#include <QDir>
#include <QFile>

BatteryService::BatteryService(QObject *parent)
    : QObject(parent)
{
    // 5秒周期刷新，仅在数值变化时通知界面
    m_timer = new QTimer(this);
    connect(m_timer, &QTimer::timeout, this, &BatteryService::refresh);
    m_timer->start(5000);
    refresh();
}

void BatteryService::refresh()
{
    // postmarketOS各机型电池目录名不同（battery/BAT0/max77705battery等），
    // 遍历并按type=="Battery"识别
    const QString base = QStringLiteral("/sys/class/power_supply");
    const QFileInfoList dirs = QDir(base).entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QFileInfo &fi : dirs) {
        QFile typeFile(fi.filePath() + "/type");
        if (!typeFile.open(QIODevice::ReadOnly)) continue;
        if (QString::fromLocal8Bit(typeFile.readAll()).trimmed() != QLatin1String("Battery")) continue;

        // 找到电池，读取电量百分比
        QFile capFile(fi.filePath() + "/capacity");
        if (capFile.open(QIODevice::ReadOnly)) {
            bool ok = false;
            const int lv = QString::fromLocal8Bit(capFile.readAll()).trimmed().toInt(&ok);
            if (ok) {
                const int old = m_level;
                m_level = qBound(0, lv, 100);
                // status: Charging/Discharging/Full/Not charging/Unknown
                bool chg = false;
                QFile stFile(fi.filePath() + "/status");
                if (stFile.open(QIODevice::ReadOnly)) {
                    const QString st = QString::fromLocal8Bit(stFile.readAll()).trimmed().toLower();
                    chg = (st == QLatin1String("charging") || st == QLatin1String("full"));
                }
                if (m_level != old || chg != m_charging) {
                    m_charging = chg;
                    emit changed();
                }
            }
        }
        return; // 只处理第一个电池设备
    }
}
