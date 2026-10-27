# HoshiLedger | 极简离线记账

HoshiLedger (Hoshi记账) 是一款基于 Flutter 开发的极简个人记账应用。记账功能离线使用，账单保存在本地；联网仅用于检查和下载应用更新。

## 🌟 核心特色

- **本地记账**：账单、分类和记账模板保存在设备本地，不上传到更新服务。
- **极简交互**：精心设计的“先选类别，后填金额”流式记账流程，单手即可极速完成。
- **备注神器**：支持备注模板管理，具备拖拽排序优先级功能，记账时横向滑动即可快速填选。
- **财务准确**：底层金额采用“分”单位整数存储，彻底杜绝浮点数精度误差。
- **数据自由**：支持全量数据的 CSV/JSON 格式导出与导入，方便跨设备迁移或数据备份。

## 📸 功能说明

### 1. 流式记账 (Add Record)
点击底部 `+` 号，系统将引导你先选择“支出”或“收入”的具体类别。选择完毕后弹出简洁的金额输入窗口。这种“类别驱动”的交互方式极大地减少了弹窗内的视觉干扰。

### 2. 备注模板管理 (Note Templates)
系统会根据你的记账习惯自动保存常用的备注。在设置页面中，你可以进入“备注模板管理”，通过**长按拖拽**调整备注的优先级。在记账时，高优先级的备注会优先在横向列表中展示。

### 3. 数据备份与恢复
- **导出**：支持 CSV (适合 Excel 查看) 和 JSON (适合技术备份)。
- **导入**：支持从 CSV 或 JSON 文件中恢复账单，实现无感迁移。

### 4. 统计与分析
支持按月/按年查看收支概览，通过直观的饼图分析资金流向，并支持点击饼图查看对应分类的详细交易记录。

## 🛠 技术实现

- **Framework**: Flutter (Dart)
- **Database**: SQLite (sqflite)
- **Package Name**: `com.hoshi.ledger`
- **State Management**: 全局 ValueNotifier 响应式更新
- **Design Logic**: 本地记账，GitHub Releases 提供应用更新

## 版本与自动发布

Android 使用四段版本号，由 `pubspec.yaml` 中的 `major.minor.patch+revision` 统一管理，应用中显示为 `major.minor.patch.revision`。

版本增加并推送到 `main` 后，GitHub Actions 自动构建 APK、校验版本和签名，再创建标签并发布 GitHub Release。版本未变化时不会打包或发布。

Release 提供仅支持 ARM64 设备的 APK、SHA-256 校验文件和供 App 读取的更新信息。构建使用 GitHub Actions Secrets 中保存的签名密钥，确保安装包可以覆盖升级；密钥和密码不提交到代码仓库。

### 手机更新

App 仅在用户点击设置中的「检查更新」后联网检查，不在启动时或后台自动检查。
更新地址是公开仓库的 `releases/latest/download/latest.json`，不会携带任何账单数据或 GitHub Token。
下载支持进度和取消，完成后校验大小与 SHA-256；安装前再校验包名、版本和签名。
Android 的安装授权和最终安装确认由系统处理，不会静默安装。
更新不清空账单数据库。

## 🚀 快速开始

1. 确保已配置 [Flutter SDK](https://docs.flutter.dev/get-started/install)。
2. 克隆项目并进入根目录。
3. 获取依赖：
   ```bash
   flutter pub get
   ```
4. 运行应用：
   ```bash
   flutter run --release
   ```
5. 打包 APK：
   ```bash
   flutter build apk --release --target-platform android-arm64
   ```

---
*本项目由 Antigravity (AI Coding Assistant) 协作完成。*
