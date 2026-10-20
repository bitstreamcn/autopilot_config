#include "RemoteControllerService.h"
#include <QRegularExpression>
#include <QProcess>
#include <QUrl>
#include <QFile>

#ifdef Q_OS_UNIX
#include <fcntl.h>
#include <unistd.h>
#include <poll.h>
#include <termios.h>
#include <cerrno>
#include <cstring>
#endif

// ===== 读取线程：按cat方式读取串口 =====

RemoteReaderThread::RemoteReaderThread(const QString &device, QObject *parent)
    : QThread(parent)
    , m_device(device)
    , m_stop(false)
{
}

void RemoteReaderThread::run()
{
#ifdef Q_OS_UNIX
    // 与控制台cat完全一致的打开方式：只读、阻塞模式、不改termios
    int fd = ::open(m_device.toLocal8Bit().constData(), O_RDONLY | O_NOCTTY);
    if (fd < 0) {
        emit linkLost(QString("打开串口失败: %1").arg(strerror(errno)));
        return;
    }

    // 仅关闭回显：默认termios的ECHO开启会把收到的数据原样回发给遥控器，
    // 导致回程流量翻倍且可能干扰遥控器固件。其余设置保持默认不变。
    struct termios tio;
    if (tcgetattr(fd, &tio) == 0) {
        tio.c_lflag &= ~(ECHO | ECHOE | ECHOK | ECHONL | ECHOCTL | ECHOPRT | ECHOKE);
        if (tcsetattr(fd, TCSANOW, &tio) < 0) {
            // 关闭失败不影响读取，仅记录原因
            emit linkLost(QString("关闭回显失败: %1").arg(strerror(errno)));
            ::close(fd);
            return;
        }
    }

    QByteArray lineBuf;
    struct pollfd pfd;
    pfd.fd = fd;
    pfd.events = POLLIN;

    for (;;) {
        if (m_stop.loadAcquire()) break;

        int pr = ::poll(&pfd, 1, 200);
        if (m_stop.loadAcquire()) break;

        if (pr < 0) {
            if (errno == EINTR) continue;
            emit linkLost(QString("poll错误: %1").arg(strerror(errno)));
            break;
        }
        if (pr == 0) continue;  // 超时，继续等待

        if (pfd.revents & (POLLHUP | POLLERR | POLLNVAL)) {
            // 先把残留数据读完再退出
            if (pfd.revents & POLLIN) {
                char buf[512];
                ssize_t n = ::read(fd, buf, sizeof(buf));
                if (n > 0) {
                    QStringList lines;
                    for (ssize_t i = 0; i < n; i++) {
                        char c = buf[i];
                        if (c == '\n' || c == '\r') {
                            if (!lineBuf.isEmpty()) {
                                lines << QString::fromLocal8Bit(lineBuf);
                                lineBuf.clear();
                            }
                        } else {
                            lineBuf.append(c);
                            if (lineBuf.size() > 512) lineBuf.clear();
                        }
                    }
                    if (!lines.isEmpty()) emit linesReceived(lines);
                }
            }
            emit linkLost(QStringLiteral("串口链路已挂断"));
            break;
        }

        if (pfd.revents & POLLIN) {
            char buf[512];
            ssize_t n = ::read(fd, buf, sizeof(buf));
            if (n > 0) {
                // 批量处理本块数据中的所有完整行，一次信号发送，降低跨线程开销
                QStringList lines;
                for (ssize_t i = 0; i < n; i++) {
                    char c = buf[i];
                    if (c == '\n' || c == '\r') {
                        if (!lineBuf.isEmpty()) {
                            lines << QString::fromLocal8Bit(lineBuf);
                            lineBuf.clear();
                        }
                    } else {
                        lineBuf.append(c);
                        if (lineBuf.size() > 512) lineBuf.clear();
                    }
                }
                if (!lines.isEmpty()) emit linesReceived(lines);
                continue;
            }
            if (n == 0) {
                emit linkLost(QStringLiteral("串口返回EOF（链路已断开）"));
                break;
            }
            if (errno == EINTR) continue;
            emit linkLost(QString("串口读取错误: %1").arg(strerror(errno)));
            break;
        }
    }

    ::close(fd);
#endif
}

// ===== 服务 =====

RemoteControllerService::RemoteControllerService(QObject *parent)
    : QObject(parent)
{
    // 未连接时周期重试打开串口（无限重试）
    m_retryTimer = new QTimer(this);
    m_retryTimer->setInterval(2000);
    connect(m_retryTimer, &QTimer::timeout, this, [this]() {
        if (!connected()) {
            tryOpenPort();
        }
    });
    m_retryTimer->start();

    // 看门狗：收到首条消息后，超过30秒无任何消息则关机（每5秒检查一次）
    QTimer *watchdog = new QTimer(this);
    connect(watchdog, &QTimer::timeout, this, &RemoteControllerService::checkWatchdog);
    watchdog->start(5000);
}

RemoteControllerService::~RemoteControllerService()
{
    m_retryTimer->stop();
    closePort();
}

bool RemoteControllerService::connected() const
{
    return m_fd >= 0 && m_reader != nullptr;
}

void RemoteControllerService::openPort(const QString &device)
{
    m_device = device;
    tryOpenPort();
}

void RemoteControllerService::tryOpenPort()
{
    // 已连接则跳过（重试定时器周期触发）
    if (connected()) return;

    // 清理残留
    closePort();

#ifdef Q_OS_UNIX
    // 写句柄（发送命令用），独立于读取线程
    int fd = ::open(m_device.toLocal8Bit().constData(), O_WRONLY | O_NOCTTY | O_NONBLOCK);
    if (fd < 0) {
        if (!m_retrying) {
            m_retrying = true;
            emit portError(QString("无法打开串口 %1: %2（将自动重试）").arg(m_device, strerror(errno)));
        }
        return;
    }
    m_fd = fd;

    // 读取线程按cat方式读串口
    m_reader = new RemoteReaderThread(m_device, this);
    connect(m_reader, &RemoteReaderThread::linesReceived, this, &RemoteControllerService::onLinesReceived);
    connect(m_reader, &RemoteReaderThread::linkLost, this, &RemoteControllerService::onLinkLost);
    m_reader->start();

    emit connectedChanged();
    emit portOpened(m_device);
#else
    if (!m_retrying) {
        m_retrying = true;
        emit portError("当前平台不支持串口");
    }
#endif
}

void RemoteControllerService::closePort()
{
#ifdef Q_OS_UNIX
    if (m_reader) {
        RemoteReaderThread *reader = m_reader;
        m_reader = nullptr;
        reader->stop();
        reader->wait(1000);  // 等待线程退出（poll超时200ms）
        reader->deleteLater();
    }
    if (m_fd >= 0) {
        ::close(m_fd);
        m_fd = -1;
        emit connectedChanged();
    }
#endif
}

void RemoteControllerService::handleDisconnected(const QString &reason)
{
    closePort();
    // 断开原因仅在首次报告（重连成功收到数据后m_retrying复位）
    if (!m_retrying) {
        m_retrying = true;
        emit portError(reason + QStringLiteral("，将自动重试"));
    }
}

void RemoteControllerService::onLinesReceived(const QStringList &lines)
{
    m_retrying = false;  // 收到数据，链路正常
    m_gotFirstMsg = true;
    m_lastMsgTimer.restart();
    // 刷机结束后收到首个数据包，恢复看门狗并重新计时30秒
    if (m_watchdogPendingReArm) {
        m_watchdogPendingReArm = false;
        m_watchdogEnabled = true;
    }

    // 逐行解析状态数据；未识别出任何已知字段的行才进原始日志
    QStringList rawLines;
    for (const QString &line : lines) {
        const QString trimmed = line.trimmed();
        if (!trimmed.isEmpty() && !parseLine(trimmed)) {
            rawLines.append(trimmed);
        }
    }
    if (!rawLines.isEmpty()) {
        emit rawLinesReceived(rawLines);
    }
}

void RemoteControllerService::onLinkLost(const QString &reason)
{
    handleDisconnected(reason);
}

bool RemoteControllerService::parseLine(const QString &line)
{
    if (line.isEmpty()) return false;

    // 关机指令：整行为 shutdown
    if (line.compare(QLatin1String("shutdown"), Qt::CaseInsensitive) == 0) {
        doShutdown(QStringLiteral("收到遥控器关机指令"));
        return true;
    }

    // 按 逗号/空白 拆分字段，每个字段为 key:value 或 key=value（静态编译一次）
    static const QRegularExpression sepRegex("[,\\s]+");

    float roll = 0, pitch = 0, yaw = 0, thr = 0;
    bool hasJoy = false;
    float bat = 0;
    bool hasBat = false;
    bool recognized = false;

    const QStringList tokens = line.split(sepRegex, Qt::SkipEmptyParts);
    for (const QString &token : tokens) {
        int sep = token.indexOf(':');
        int eq = token.indexOf('=');
        if (eq >= 0 && (sep < 0 || eq < sep)) sep = eq;
        if (sep <= 0) continue;

        const QString key = token.left(sep).trimmed().toLower();
        const QString value = token.mid(sep + 1).trimmed();
        bool ok = false;
        const float num = value.toFloat(&ok);

        // 关机指令：key或value为shutdown（如 shutdown:1 / event:shutdown）
        if (key == "shutdown" ||
            value.compare(QLatin1String("shutdown"), Qt::CaseInsensitive) == 0) {
            doShutdown(QStringLiteral("收到遥控器关机指令"));
            return true;
        }

        if (key == "roll" && ok) {
            roll = num;
            hasJoy = true;
            recognized = true;
        } else if (key == "pitch" && ok) {
            pitch = num;
            hasJoy = true;
            recognized = true;
        } else if (key == "yaw" && ok) {
            yaw = num;
            hasJoy = true;
            recognized = true;
        } else if ((key == "thr" || key == "throttle") && ok) {
            thr = num;
            hasJoy = true;
            recognized = true;
        } else if (key == "bat" || key == "battery" || key == "volt" || key == "voltage") {
            recognized = true;
            if (ok) {
                bat = num;
                hasBat = true;
            }
        } else if (key == "mode") {
            emit modeReceived(value);
            recognized = true;
        } else if (key == "light" || key == "led") {
            emit lightReceived(value);
            recognized = true;
        }
    }

    if (hasJoy) emit joystickReceived(roll, pitch, yaw, thr);
    if (hasBat) emit batteryReceived(bat);
    return recognized;
}

void RemoteControllerService::checkWatchdog()
{
    // 收到首条消息后才开始计时；超过30秒无任何消息则关机；刷机期间暂停
    if (!m_watchdogEnabled) return;
    if (!m_gotFirstMsg) return;
    if (m_lastMsgTimer.elapsed() < 30000) return;
    doShutdown(QStringLiteral("超过30秒未收到遥控器数据"));
}

void RemoteControllerService::resumeWatchdog()
{
    // 刷机结束：保持看门狗暂停，等收到MCU重启后的首个数据包再恢复30秒计时
    m_watchdogEnabled = false;
    m_watchdogPendingReArm = true;
}

void RemoteControllerService::doShutdown(const QString &reason)
{
    // 复位看门狗，避免关机过程中重复触发
    m_gotFirstMsg = false;
    m_watchdogEnabled = false;
    m_watchdogPendingReArm = false;
    emit shutdownRequested(reason);
    // 同步文件系统后关机；startDetached独立于本进程存活
    QProcess::startDetached(QStringLiteral("sh"),
                            QStringList{QStringLiteral("-c"), QStringLiteral("sync; poweroff")});
}

void RemoteControllerService::sendCommand(const QString &command)
{
    if (m_fd < 0) {
        emit portError("串口未打开，无法发送命令");
        return;
    }
#ifdef Q_OS_UNIX
    QByteArray data = command.toLocal8Bit();
    if (!data.endsWith('\n')) data.append('\n');
    if (::write(m_fd, data.constData(), static_cast<size_t>(data.size())) < 0) {
        emit portError(QString("命令发送失败: %1").arg(strerror(errno)));
    }
#endif
}

// ===== 功能命令定义（如遥控器命令字符串不同，只需修改此处） =====

void RemoteControllerService::changeMode()
{
    sendCommand(QStringLiteral("cmd=changemode"));
}

void RemoteControllerService::returnHome()
{
    sendCommand(QStringLiteral("cmd=rth"));
}

void RemoteControllerService::cancelReturnHome()
{
    sendCommand(QStringLiteral("cmd=rth_cancel"));
}

void RemoteControllerService::setLight(bool on)
{
    sendCommand(QStringLiteral("light=") + (on ? QStringLiteral("1") : QStringLiteral("0")));
}

void RemoteControllerService::setClimbPower(int percent)
{
    sendCommand(QStringLiteral("climb_power=") + QString::number(percent));
}

void RemoteControllerService::updateFirmware()
{
    // 刷机期间MCU进入DFU模式不再发数据，暂停30秒无数据关机看门狗
    m_watchdogEnabled = false;
    sendCommand(QStringLiteral("cmd=update"));
}

void RemoteControllerService::flashFirmware(const QString &fileUrl)
{
#ifdef Q_OS_UNIX
    if (m_flashProcess) {
        emit firmwareFlashFinished(false, QStringLiteral("已有刷机任务在进行中"));
        resumeWatchdog();
        return;
    }

    // 支持传入QML的file:// URL或本地路径
    QUrl url(fileUrl);
    const QString path = url.isLocalFile() ? url.toLocalFile() : fileUrl;
    if (path.isEmpty() || !QFile::exists(path)) {
        emit firmwareFlashFinished(false, QStringLiteral("固件文件不存在: %1").arg(path));
        resumeWatchdog();
        return;
    }

    m_flashProcess = new QProcess(this);
    m_flashProcess->setProcessChannelMode(QProcess::MergedChannels);
    connect(m_flashProcess, &QProcess::readyReadStandardOutput, this, [this]() {
        // dfu-util的进度条用\r刷新，按\r或\n统一分段
        static const QRegularExpression lineSep("[\r\n]+");
        const QStringList parts = QString::fromLocal8Bit(m_flashProcess->readAllStandardOutput())
                                      .split(lineSep, Qt::SkipEmptyParts);
        for (const QString &l : parts) emit firmwareFlashOutput(l.trimmed());
    });
    connect(m_flashProcess, &QProcess::finished, this, [this](int exitCode, QProcess::ExitStatus status) {
        const bool ok = (status == QProcess::NormalExit && exitCode == 0);
        // -s :leave 使MCU下载完成后自动退出DFU模式并重启运行用户程序
        emit firmwareFlashFinished(ok, ok ? QStringLiteral("刷机完成，MCU将自动重启运行")
                                          : QStringLiteral("dfu-util异常退出，退出码: %1").arg(exitCode));
        // 刷机结束（无论成败），恢复看门狗并重新计时
        resumeWatchdog();
        m_flashProcess->deleteLater();
        m_flashProcess = nullptr;
    });

    // -a 0: DFU altsetting 0;  -D: 下载固件文件;  -s :leave: 完成后离开DFU并重启运行
    m_flashProcess->start(QStringLiteral("dfu-util"),
                          QStringList{QStringLiteral("-a"), QStringLiteral("0"),
                                      QStringLiteral("-D"), path,
                                      QStringLiteral("-s"), QStringLiteral("0x08000000:leave")});
#else
    Q_UNUSED(fileUrl)
    emit firmwareFlashFinished(false, QStringLiteral("当前平台不支持dfu-util刷机"));
#endif
}
