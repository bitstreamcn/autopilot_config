#ifndef PARAMFILEMANAGER_H
#define PARAMFILEMANAGER_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>

// 参数文件管理器 - 提供参数保存到文件和从文件加载的功能
// 文件格式：参数名=参数值（参考H743PilotX-Tcp的实现）
class ParamFileManager : public QObject
{
    Q_OBJECT

public:
    explicit ParamFileManager(QObject *parent = nullptr);

    // 保存参数到文件
    // 参数：filePath - 文件路径，paramNames - 参数名列表，paramValues - 参数值列表
    // 返回：成功返回true，失败返回false
    Q_INVOKABLE bool saveParameters(const QString &filePath, const QStringList &paramNames, const QStringList &paramValues);

    // 从文件加载参数
    // 参数：filePath - 文件路径
    // 返回：参数名和参数值的列表（QVariantList包含两个QStringList）
    // 格式：[paramNames, paramValues]
    Q_INVOKABLE QVariantList loadParameters(const QString &filePath, const QStringList &existingParamNames);
};

#endif // PARAMFILEMANAGER_H