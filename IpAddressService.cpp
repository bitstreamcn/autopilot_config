#include "IpAddressService.h"
#include <QDebug>
#include <QTimer>

IpAddressService::IpAddressService(QObject *parent)
    : QObject(parent)
    , m_lastIPs(allIPs())
{
    // 周期检测IP变化（WiFi连接获取DHCP IP / 切回AP模式后自动刷新列表）
    auto *timer = new QTimer(this);
    connect(timer, &QTimer::timeout, this, &IpAddressService::checkForChanges);
    timer->start(3000);
}

void IpAddressService::checkForChanges()
{
    QStringList current = allIPs();

    QStringList sortedCurrent = current;
    sortedCurrent.sort();
    QStringList sortedLast = m_lastIPs;
    sortedLast.sort();

    if (sortedCurrent != sortedLast) {
        m_lastIPs = current;
        emit ipsChanged();
    }
}

QStringList IpAddressService::allIPs() const
{
    QStringList ips;
    auto interfaces = QNetworkInterface::allInterfaces();

    for (const auto &interface : interfaces) {
        if (interface.flags() & QNetworkInterface::IsLoopBack) continue;
        if (!(interface.flags() & QNetworkInterface::IsUp)) continue;

        auto addresses = interface.addressEntries();
        for (const auto &addr : addresses) {
            if (addr.ip().protocol() == QAbstractSocket::IPv4Protocol) {
                ips.append(addr.ip().toString());
            }
        }
    }

    return ips;
}

QString IpAddressService::preferredIP() const
{
    auto ips = allIPs();
    if (ips.isEmpty()) return "";

    // Prefer non-localhost IPs with gateway access
    for (const auto &ip : ips) {
        if (!ip.startsWith("169.") && !ip.startsWith("127.")) {
            return ip;
        }
    }

    return ips.first();
}

QVariantList IpAddressService::getIPInfo() const
{
    QVariantList result;
    auto interfaces = QNetworkInterface::allInterfaces();

    for (const auto &interface : interfaces) {
        if (interface.flags() & QNetworkInterface::IsLoopBack) continue;
        if (!(interface.flags() & QNetworkInterface::IsUp)) continue;

        QVariantMap ipInfo;
        ipInfo["interfaceName"] = interface.name();
        ipInfo["interfaceType"] = QString::number(static_cast<int>(interface.type()));
        ipInfo["isUp"] = static_cast<bool>(interface.flags() & QNetworkInterface::IsUp);

        auto addresses = interface.addressEntries();
        QStringList ips;
        for (const auto &addr : addresses) {
            if (addr.ip().protocol() == QAbstractSocket::IPv4Protocol) {
                ips.append(addr.ip().toString());
            }
        }

        if (!ips.isEmpty()) {
            ipInfo["ips"] = ips;
            result.append(ipInfo);
        }
    }

    return result;
}

QString IpAddressService::formatNetworkInfo() const
{
    QString text = "=== 网络接口信息 ===\n";
    QString pref = preferredIP();
    text += QString("首选IP: %1\n").arg(pref.isEmpty() ? "无" : pref);

    auto ips = allIPs();
    text += QString("所有IP: %1\n").arg(ips.join(", "));

    return text;
}

QString IpAddressService::selectPreferredIP(const QList<QHostAddress> &addresses) const
{
    for (const auto &addr : addresses) {
        QString ip = addr.toString();
        if (!ip.startsWith("169.") && !ip.startsWith("127.")) {
            return ip;
        }
    }

    if (!addresses.isEmpty()) {
        return addresses.first().toString();
    }

    return "";
}