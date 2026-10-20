#include "ParamFileManager.h"
#include <QFile>
#include <QTextStream>
#include <QDateTime>
#include <QDebug>
#include <QDir>  // 关键修复：添加QDir用于创建目录>

ParamFileManager::ParamFileManager(QObject *parent)
    : QObject{parent}
{
}

bool ParamFileManager::saveParameters(const QString &filePath, const QStringList &paramNames, const QStringList &paramValues)
{
    if (paramNames.size() != paramValues.size()) {
        qWarning() << "参数名和参数值数量不匹配";
        return false;
    }

    // 关键修复：检查并创建目录（如果不存在）
    QFileInfo fileInfo(filePath);
    QDir dir = fileInfo.absoluteDir();
    if (!dir.exists()) {
        if (!dir.mkpath(".")) {
            qWarning() << "无法创建目录：" << dir.absolutePath();
            return false;
        }
        qDebug() << "目录已创建：" << dir.absolutePath();
    }

    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "无法打开文件写入：" << filePath << file.errorString();
        return false;
    }

    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);

    // 写入文件头注释（参考H743PilotX-Tcp）
    out << "# 参数配置文件\n";
    out << "# 保存时间: " << QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss") << "\n";
    out << "# 格式: 参数名=参数值\n";
    out << "\n";

    // 写入参数（格式：参数名=参数值）
    for (int i = 0; i < paramNames.size(); i++) {
        QString name = paramNames[i];
        QString value = paramValues[i];

        // 处理特殊字符（参考H743PilotX-Tcp的逻辑）
        bool needQuotes = value.contains(' ') || value.contains('\n') || value.contains('\r') ||
                          value.contains('\t') || value.contains('"') || value.contains('#');

        if (needQuotes) {
            // 转义特殊字符
            value.replace("\\", "\\\\");
            value.replace("\"", "\\\"");
            value.replace("\n", "\\n");
            value.replace("\r", "\\r");
            value.replace("\t", "\\t");
            value = "\"" + value + "\"";
        }

        out << name << "=" << value << "\n";
    }

    file.close();
    return true;
}

QVariantList ParamFileManager::loadParameters(const QString &filePath, const QStringList &existingParamNames)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "无法打开文件读取：" << filePath << file.errorString();
        return QVariantList();
    }

    QTextStream in(&file);
    in.setEncoding(QStringConverter::Utf8);

    QStringList loadedNames;
    QStringList loadedValues;
    int loadedCount = 0;
    int skippedCount = 0;

    while (!in.atEnd()) {
        QString line = in.readLine().trimmed();

        // 跳过空行和注释行
        if (line.isEmpty() || line.startsWith('#')) {
            continue;
        }

        // 解析参数名和参数值（格式：参数名=参数值）
        int equalIndex = line.indexOf('=');
        if (equalIndex > 0) {
            QString name = line.left(equalIndex).trimmed();
            QString value = line.mid(equalIndex + 1).trimmed();

            // 处理引号包围的值（参考H743PilotX-Tcp的逻辑）
            if (value.startsWith('"') && value.endsWith('"') && value.length() >= 2) {
                value = value.mid(1, value.length() - 2);  // 移除引号
                // 反转义特殊字符
                value.replace("\\n", "\n");
                value.replace("\\r", "\r");
                value.replace("\\t", "\t");
                value.replace("\\\"", "\"");
                value.replace("\\\\", "\\");
            }

            // 检查参数是否在现有参数列表中（参考H743PilotX-Tcp的逻辑）
            if (existingParamNames.contains(name)) {
                loadedNames.append(name);
                loadedValues.append(value);
                loadedCount++;
            } else {
                skippedCount++;
            }
        }
    }

    file.close();

    qDebug() << "从文件加载参数完成: 加载" << loadedCount << "个, 跳过" << skippedCount << "个未知参数";

    // 返回格式：[loadedNames, loadedValues, loadedCount, skippedCount]
    QVariantList result;
    result.append(QVariant::fromValue(loadedNames));
    result.append(QVariant::fromValue(loadedValues));
    result.append(loadedCount);
    result.append(skippedCount);
    return result;
}