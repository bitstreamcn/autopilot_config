#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QProcess>
#include <QFile>
#include <QTimer>
#include <QThread>
#include <QtConcurrent>
#include <QDebug>
#include <QSurfaceFormat>
#include "TcpServerService.h"
#include "Stm32ProtocolParser.h"
#include "ProtocolPacketBuilderWrapper.h"
#include "DataDisplayProcessor.h"
#include "IpAddressService.h"
#include "SystemService.h"
#include "DataTimeoutManager.h"
#include "ParamFileManager.h"  // 参数文件管理器
#include "RemoteControllerService.h"  // 遥控器串口服务
#include "BatteryService.h"  // 本机电池电量

// 安全执行命令的辅助函数 - 不会导致程序崩溃
static bool safeExecuteCommand(const QString &program, const QStringList &args, int timeoutMs = 5000)
{
    try {
        QProcess process;
        process.start(program, args);

        if (!process.waitForStarted(1000)) {
            qDebug() << "[safeExecuteCommand] Failed to start:" << program << args;
            return false;
        }

        if (!process.waitForFinished(timeoutMs)) {
            qDebug() << "[safeExecuteCommand] Timeout:" << program << args;
            process.kill();
            process.waitForFinished(1000);
            return false;
        }

        if (process.exitStatus() == QProcess::CrashExit) {
            qDebug() << "[safeExecuteCommand] Process crashed:" << program << args;
            return false;
        }

        return true;
    } catch (...) {
        qDebug() << "[safeExecuteCommand] Exception caught:" << program << args;
        return false;
    }
}

static void disableScreenSaver()
{
    // 禁用屏幕保护并设置横屏显示 - 可能需要几秒,异步执行
    // 使用安全执行方式,失败不影响程序运行
    qDebug() << "[disableScreenSaver] Starting...";

    try {
        // 设置DISPLAY环境变量
        qputenv("DISPLAY", QByteArray(":0"));

        // 逐个执行命令,每个命令独立处理
        safeExecuteCommand("xset", {"s", "off"}, 3000);
        safeExecuteCommand("xset", {"s", "noblank"}, 3000);
        safeExecuteCommand("xset", {"-dpms"}, 3000);

        // 屏幕旋转命令可能失败,不影响程序
        if (!safeExecuteCommand("xrandr", {"--output", "DSI-1", "--rotate", "right"}, 5000)) {
            qDebug() << "[disableScreenSaver] xrandr failed, but continuing...";
        }

        qDebug() << "[disableScreenSaver] Completed";
    } catch (...) {
        qDebug() << "[disableScreenSaver] Exception caught, but program will continue";
    }
}

static void setLandscapeOrientation()
{
    // Try framebuffer rotation via sysfs - 快速操作,可以在主线程执行
    try {
        QFile rotateFile("/sys/class/graphics/fb0/rotate");
        if (rotateFile.open(QIODevice::WriteOnly)) {
            rotateFile.write("1");  // 1 = 90 degrees (landscape)
            rotateFile.close();
            qDebug() << "[setLandscapeOrientation] FB rotation set successfully";
        } else {
            qDebug() << "[setLandscapeOrientation] Cannot open rotate file";
        }
    } catch (...) {
        qDebug() << "[setLandscapeOrientation] Exception caught";
    }
}

static void startWifiHotspot()
{
    // 这个函数耗时很长(至少5秒 + 多个服务启动),必须异步执行
    qDebug() << "[startWifiHotspot] Starting WiFi hotspot setup...";

    try {
        // 使用安全执行方式
        safeExecuteCommand("sh", {"-c", "rc-service wpa_supplicant stop 2>/dev/null || true"}, 3000);
        safeExecuteCommand("sh", {"-c", "pkill wpa_supplicant 2>/dev/null || true"}, 2000);

        safeExecuteCommand("sh", {"-c", "ip link set wlan0 up 2>/dev/null || true"}, 3000);
        safeExecuteCommand("sh", {"-c", "ip addr add 192.168.4.1/24 dev wlan0 2>/dev/null || true"}, 3000);

        safeExecuteCommand("sh", {"-c", "rc-service hostapd stop 2>/dev/null || true"}, 3000);
        safeExecuteCommand("sh", {"-c", "rc-service dnsmasq stop 2>/dev/null || true"}, 3000);

        // Wait 5 seconds before starting services
        QThread::sleep(5);

        safeExecuteCommand("sh", {"-c", "rc-service hostapd start 2>/dev/null || true"}, 5000);
        safeExecuteCommand("sh", {"-c", "rc-service dnsmasq start 2>/dev/null || true"}, 5000);

        qDebug() << "[startWifiHotspot] WiFi hotspot setup completed";
    } catch (...) {
        qDebug() << "[startWifiHotspot] Exception caught, but WiFi setup will not affect program";
    }
}

static bool checkServiceCrashed(const QString &serviceName)
{
    try {
        QProcess process;
        process.start("sh", {"-c", "rc-service " + serviceName + " status"});

        if (!process.waitForStarted(1000)) {
            qDebug() << "[checkServiceCrashed] Cannot start process for" << serviceName;
            return false;
        }

        if (!process.waitForFinished(5000)) {
            qDebug() << "[checkServiceCrashed] Timeout for" << serviceName;
            process.kill();
            return false;
        }

        QString output = process.readAllStandardOutput();
        QString error = process.readAllStandardError();

        // Check if output contains "status: crashed"
        return output.contains("status: crashed") || error.contains("status: crashed");
    } catch (...) {
        qDebug() << "[checkServiceCrashed] Exception for" << serviceName;
        return false;
    }
}

static void checkWifiServices()
{
    try {
        bool hostapdCrashed = checkServiceCrashed("hostapd");
        bool dnsmasqCrashed = checkServiceCrashed("dnsmasq");

        if (hostapdCrashed || dnsmasqCrashed) {
            qDebug() << "[checkWifiServices] Services crashed, restarting...";
            startWifiHotspot();
        }
    } catch (...) {
        qDebug() << "[checkWifiServices] Exception caught";
    }
}

int main(int argc, char *argv[])
{
    // ===== 性能优化设置 - 减少闪烁和提升渲染性能 =====

    // 1. 关键优化：强制使用软件渲染 - 解决postmarketOS上的闪烁和崩溃问题
    // 这会跳过OpenGL渲染，使用纯CPU软件渲染，完全避免GPU驱动问题
    qputenv("QT_QUICK_BACKEND", "software");

    // 注意：软件渲染模式下，以下设置无效（已注释）
    // qputenv("QSG_RHI_BACKEND", "opengl");  // 软件渲染不需要RHI

    // 2. 禁用动画过渡 - 减少渲染开销
    qputenv("QT_QUICK_CONTROLS_MATERIAL_ELEVATION_ENABLED", "false");

    // 3. 软件渲染模式下的表面格式（可选）
    // 注意：软件渲染不使用OpenGL，这些设置可能无效
    QSurfaceFormat format;
    format.setDepthBufferSize(24);
    format.setStencilBufferSize(8);
    QSurfaceFormat::setDefaultFormat(format);

    // 4. 设置渲染循环类型 - basic模式更适合软件渲染
    qputenv("QSG_RENDER_LOOP", "basic");
    
    // 启用虚拟键盘
    qputenv("QT_IM_MODULE", QByteArray("qtvirtualkeyboard"));
    qputenv("QT_VIRTUALKEYBOARD_STYLE", QByteArray("retro"));

    // 快速的文件操作可以在主线程执行
    setLandscapeOrientation();

    // 耗时的系统配置命令异步执行，避免启动卡顿
    // 使用QThreadPool::start()替代QtConcurrent::run()消除编译警告
    QThreadPool::globalInstance()->start(disableScreenSaver);

    QGuiApplication app(argc, argv);
    
    // 设置应用标识，避免DBus Portal警告
    app.setOrganizationName("autopilot_config");
    app.setApplicationName("autopilot_config");
    app.setApplicationDisplayName("飞控调试工具");
    app.setDesktopFileName("autopilot_config.desktop");
    
    // 禁用屏幕保护 - 通过Qt内部机制
    // QGuiApplication没有直接API，但可以通过设置环境变量或使用QScreen的方式
    // 在Wayland环境下，设置窗口标志更有效
    
    // Create instances
    TcpServerService tcpServer(26413);
    Stm32ProtocolParser protocolParser;
    DataDisplayProcessor displayProcessor;
    IpAddressService ipAddressService;
    ProtocolPacketBuilderWrapper packetBuilder;
    SystemService systemService;
    DataTimeoutManager timeoutManager;
    RemoteControllerService remoteController;
    BatteryService batteryService;

    // Create QML engine
    QQmlApplicationEngine engine;

    // 注册C++对象到QML上下文
    engine.rootContext()->setContextProperty("tcpServer", &tcpServer);
    engine.rootContext()->setContextProperty("protocolParser", &protocolParser);
    engine.rootContext()->setContextProperty("displayProcessor", &displayProcessor);
    engine.rootContext()->setContextProperty("ipAddressService", &ipAddressService);
    engine.rootContext()->setContextProperty("packetBuilder", &packetBuilder);
    engine.rootContext()->setContextProperty("systemService", &systemService);
    engine.rootContext()->setContextProperty("timeoutManager", &timeoutManager);
    engine.rootContext()->setContextProperty("remoteController", &remoteController);
    engine.rootContext()->setContextProperty("batteryService", &batteryService);

    // 注册参数文件管理器
    ParamFileManager paramFileManager;
    engine.rootContext()->setContextProperty("paramFileManager", &paramFileManager);

    // Load QML
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("autopilot_config", "Main");

    // Setup timer to check WiFi services every 10 seconds
    QTimer wifiCheckTimer;
    QObject::connect(&wifiCheckTimer, &QTimer::timeout, []() {
        checkWifiServices();
    });
    wifiCheckTimer.start(10000);  // 10 seconds interval

    return app.exec();
}