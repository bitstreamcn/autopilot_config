#include "DataDisplayProcessor.h"
#include <QDateTime>

DataDisplayProcessor::DataDisplayProcessor(QObject *parent)
    : QObject(parent)
{
}

void DataDisplayProcessor::addText(const QString &text, int colorType)
{
    emit displayTextReady(text, colorType);
}

void DataDisplayProcessor::addSystemText(const QString &text)
{
    addText(text, System);
}

void DataDisplayProcessor::addNormalDataText(const QString &text)
{
    addText(text, NormalData);
}

void DataDisplayProcessor::addErrorText(const QString &text)
{
    addText(text, Error);
}

void DataDisplayProcessor::addWarningText(const QString &text)
{
    addText(text, Warning);
}

void DataDisplayProcessor::addCriticalText(const QString &text)
{
    addText(text, Critical);
}

QString DataDisplayProcessor::currentTime() const
{
    return QDateTime::currentDateTime().toString("HH:mm:ss");
}

QString DataDisplayProcessor::formatClientConnected(const QString &ipAddress, int port, int count)
{
    QString now = QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss");
    return QString("[%1] 客户端已连接\n"
                   "    IP地址: %2\n"
                   "    端口: %3\n"
                   "    连接时间: %4\n"
                   "    当前连接数: %5\n"
                   "----------------------------------------\n")
        .arg(currentTime(), ipAddress)
        .arg(port)
        .arg(now)
        .arg(count);
}

QString DataDisplayProcessor::formatClientDisconnected(const QString &ipAddress, int port, const QString &reason, int count)
{
    QString now = QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss");
    return QString("[%1] 客户端已断开连接\n"
                   "    IP地址: %2\n"
                   "    端口: %3\n"
                   "    断开时间: %4\n"
                   "    原因: %5\n"
                   "    剩余连接数: %6\n"
                   "----------------------------------------\n")
        .arg(currentTime(), ipAddress)
        .arg(port)
        .arg(now)
        .arg(reason)
        .arg(count);
}

QString DataDisplayProcessor::formatServerStatus(const QString &status)
{
    return QString("[%1] %2\n"
                   "----------------------------------------\n")
        .arg(currentTime(), status);
}

QString DataDisplayProcessor::formatError(const QString &operation, const QString &errorMessage)
{
    return QString("[%1] %2: %3\n"
                   "----------------------------------------\n")
        .arg(currentTime(), operation, errorMessage);
}

QString DataDisplayProcessor::formatReceivedData(const QString &dataString, const QString &parseType)
{
    QString trimmed = dataString;
    trimmed.replace("\r", "").replace("\n", "");
    // 参考程序虽然定义了typeSuffix但没有在返回中使用，所以不显示parseType后缀
    return QString("[%1] %2").arg(currentTime(), trimmed);
}

QString DataDisplayProcessor::formatAbnormalData(const QByteArray &data, const QString &reason)
{
    // 十六进制格式
    QString hexString;
    for (int i = 0; i < data.size(); i++) {
        hexString += QString("%1 ").arg(static_cast<quint8>(data[i]), 2, 16, QChar('0')).toUpper();
    }

    // ASCII格式（替换不可见字符为'.')
    QString asciiString;
    for (int i = 0; i < data.size(); i++) {
        quint8 c = static_cast<quint8>(data[i]);
        if (c > 127 || (c < 32 && c != '\r' && c != '\n' && c != '\t')) {
            asciiString += '.';
        } else {
            asciiString += QChar(c);
        }
    }

    return QString("[%1] 异常数据 - %2\n"
                   "十六进制: %3\n"
                   "ASCII: %4\n"
                   "----------------------------------------\n")
        .arg(currentTime(), reason, hexString, asciiString);
}

QString DataDisplayProcessor::byteArrayToHex(const QByteArray &data)
{
    return data.toHex(' ');
}