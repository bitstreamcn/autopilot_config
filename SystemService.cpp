#include "SystemService.h"
#include <QDebug>
#include <QFile>

SystemService::SystemService(QObject *parent)
    : QObject{parent}
{
}

void SystemService::shutdown()
{
    emit shutdownRequested();
    qDebug() << "Executing shutdown command...";
    QProcess::execute("poweroff", QStringList());
}

void SystemService::reboot()
{
    emit rebootRequested();
    qDebug() << "Executing reboot command...";
    QProcess::execute("reboot", QStringList());
}

void SystemService::executeScript(const QString &name, const QString &content)
{
    // 将脚本写入临时文件并以 /bin/sh 异步执行，避免阻塞UI
    const QString path = "/tmp/" + name + ".sh";
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        emit scriptOutput(name, QStringLiteral("错误：无法写入脚本文件: ") + file.errorString());
        return;
    }
    file.write(content.toUtf8());
    file.close();

    // 添加可执行权限
    QFile::setPermissions(path,
                          QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner |
                          QFile::ReadGroup | QFile::ExeGroup |
                          QFile::ReadOther | QFile::ExeOther);

    // 托管QProcess执行，逐行转发脚本输出到日志
    QProcess *process = new QProcess(this);
    process->setProgram("/bin/sh");
    process->setArguments({path});
    process->setProcessChannelMode(QProcess::MergedChannels);
    m_outputBuffers.insert(process, QByteArray());

    // MergedChannels模式下所有输出都在stdout通道
    connect(process, &QProcess::readyReadStandardOutput, this, [this, process, name]() {
        QByteArray &buf = m_outputBuffers[process];
        buf += process->readAll();
        int idx;
        while ((idx = buf.indexOf('\n')) >= 0) {
            QString line = QString::fromLocal8Bit(buf.left(idx)).remove('\r').trimmed();
            buf.remove(0, idx + 1);
            if (!line.isEmpty())
                emit scriptOutput(name, line);
        }
    });

    connect(process, &QProcess::finished, this, [this, process, name](int exitCode) {
        // 转发剩余未换行的输出
        QByteArray &buf = m_outputBuffers[process];
        buf += process->readAll();
        QString line = QString::fromLocal8Bit(buf).remove('\r').trimmed();
        if (!line.isEmpty())
            emit scriptOutput(name, line);
        m_outputBuffers.remove(process);

        emit scriptFinished(name, exitCode);
        process->deleteLater();
    });

    connect(process, &QProcess::errorOccurred, this, [this, name](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart)
            emit scriptOutput(name, QStringLiteral("错误：脚本启动失败"));
    });

    process->start();
    emit scriptOutput(name, QStringLiteral("开始执行脚本"));
}