#ifndef SYSTEMSERVICE_H
#define SYSTEMSERVICE_H

#include <QObject>
#include <QProcess>
#include <QHash>

class SystemService : public QObject
{
    Q_OBJECT

public:
    explicit SystemService(QObject *parent = nullptr);

public slots:
    void shutdown();
    void reboot();
    void executeScript(const QString &name, const QString &content);

signals:
    void shutdownRequested();
    void rebootRequested();
    void scriptOutput(const QString &name, const QString &line);
    void scriptFinished(const QString &name, int exitCode);

private:
    QHash<const QProcess *, QByteArray> m_outputBuffers;
};

#endif // SYSTEMSERVICE_H