#ifndef IPADDRESSSERVICE_H
#define IPADDRESSSERVICE_H

#include <QObject>
#include <QNetworkInterface>
#include <QStringList>
#include <QVariantList>

class IpAddressService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList allIPs READ allIPs NOTIFY ipsChanged)
    Q_PROPERTY(QString preferredIP READ preferredIP NOTIFY ipsChanged)

public:
    explicit IpAddressService(QObject *parent = nullptr);

    QStringList allIPs() const;
    QString preferredIP() const;

    Q_INVOKABLE QVariantList getIPInfo() const;
    Q_INVOKABLE QString formatNetworkInfo() const;

signals:
    void ipsChanged();

private slots:
    void checkForChanges();

private:
    QString selectPreferredIP(const QList<QHostAddress> &addresses) const;

    QStringList m_lastIPs;
};

#endif // IPADDRESSSERVICE_H