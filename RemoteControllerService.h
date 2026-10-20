#ifndef REMOTECONTROLLERSERVICE_H
#define REMOTECONTROLLERSERVICE_H

#include <QObject>
#include <QThread>
#include <QTimer>
#include <QByteArray>
#include <QElapsedTimer>

class QProcess;

// 串口读取线程：完全复刻控制台 cat 的成功访问模式
// O_RDONLY + 阻塞式 poll/read + 不改termios，避免干扰USB gadget链路
class RemoteReaderThread : public QThread
{
    Q_OBJECT
public:
    explicit RemoteReaderThread(const QString &device, QObject *parent = nullptr);
    void stop() { m_stop = true; }

signals:
    void linesReceived(const QStringList &lines);
    void linkLost(const QString &reason);

protected:
    void run() override;

private:
    QString m_device;
    QAtomicInteger<bool> m_stop;
};

// 遥控器串口通信服务
// 通过 /dev/ttyGS0 (USB虚拟串口) 与遥控器通信
// 读取: 独立线程按cat方式读取（O_RDONLY、默认termios、阻塞poll）
//       之前O_RDWR+O_NONBLOCK+termios改写+反复开关会导致tty挂断（cat退出/只收到一条）
// 写入: 独立的写fd（O_WRONLY），连接期间保持打开
// 接收: 文本行, 字段为 key:value 或 key=value, 逗号/空格分隔
//   摇杆: roll/pitch/yaw/thr(throttle)
//   电池: bat(battery/volt/voltage)
//   模式: mode
//   灯光: light(led)
// 发送: 文本命令行(自动追加换行), 命令字符串集中在本cpp底部定义
class RemoteControllerService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)

public:
    explicit RemoteControllerService(QObject *parent = nullptr);
    ~RemoteControllerService() override;

    bool connected() const;

    Q_INVOKABLE void openPort(const QString &device = QStringLiteral("/dev/ttyGS0"));
    Q_INVOKABLE void closePort();

    // 发送任意文本命令（自动追加换行）
    Q_INVOKABLE void sendCommand(const QString &command);

    // 功能命令
    Q_INVOKABLE void changeMode();
    Q_INVOKABLE void returnHome();
    Q_INVOKABLE void cancelReturnHome();
    Q_INVOKABLE void setLight(bool on);
    Q_INVOKABLE void setClimbPower(int percent);
    Q_INVOKABLE void updateFirmware();

    // 用dfu-util刷写固件（参数可为file:// URL或本地路径），完成后MCU自动重启
    Q_INVOKABLE void flashFirmware(const QString &fileUrl);

    // 恢复30秒无数据关机看门狗（刷机取消/失败后调用）
    Q_INVOKABLE void resumeWatchdog();

signals:
    void connectedChanged();
    void portOpened(const QString &device);
    void portError(const QString &error);
    void joystickReceived(float roll, float pitch, float yaw, float thr);
    void batteryReceived(float voltage);
    void modeReceived(const QString &mode);
    void lightReceived(const QString &state);
    void rawLinesReceived(const QStringList &lines);
    void shutdownRequested(const QString &reason);
    void firmwareFlashOutput(const QString &line);
    void firmwareFlashFinished(bool success, const QString &message);

private slots:
    void onLinesReceived(const QStringList &lines);
    void onLinkLost(const QString &reason);
    void checkWatchdog();

private:
    void tryOpenPort();
    void handleDisconnected(const QString &reason);
    bool parseLine(const QString &line);    // 返回true=识别到至少一个已知字段
    void doShutdown(const QString &reason);

    int m_fd = -1;              // 写句柄（发送命令）
    RemoteReaderThread *m_reader = nullptr;
    QTimer *m_retryTimer = nullptr;     // 未连接时周期重试
    QString m_device = QStringLiteral("/dev/ttyGS0");
    bool m_retrying = false;    // 故障期间避免重复报错刷屏
    QElapsedTimer m_lastMsgTimer;   // 距上次收到遥控器消息
    bool m_gotFirstMsg = false;     // 收到首条消息后才启用超时关机看门狗
    bool m_watchdogEnabled = true;  // 刷机期间暂停30秒无数据关机看门狗
    bool m_watchdogPendingReArm = false;    // 刷机结束后等待首个数据包再恢复看门狗
    QProcess *m_flashProcess = nullptr; // dfu-util刷机进程
};

#endif // REMOTECONTROLLERSERVICE_H
