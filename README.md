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

Android 使用四段版本号，版本源仍为 `pubspec.yaml`：

| 配置 | 显示版本 / 标签 | Android versionCode |
| --- | --- | --- |
| `1.0.2+0` | `1.0.2.0` / `v1.0.2.0` | `100002000` |
| `1.0.2+1` | `1.0.2.1` / `v1.0.2.1` | `100002001` |
| `1.0.3+0` | `1.0.3.0` / `v1.0.3.0` | `100003000` |

换算规则：`major * 100000000 + minor * 1000000 + patch * 1000 + revision`。
四段分别限制为 `0..20`、`0..99`、`0..999`、`0..999`，整体必须大于零。
前三段或修订号增加时，按四段元组比较递增；新版本不能复用或回退。
使用 Flutter 命令或 Android Studio 的 Flutter 运行配置打包，Flutter 会同步本机的版本配置。

### 首次配置签名

在 GitHub 仓库 `Settings > Secrets and variables > Actions` 中配置：

| Secret | 内容 |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | 当前已安装版本所用 keystore 文件的 Base64 内容 |
| `ANDROID_STORE_PASSWORD` | keystore 密码 |
| `ANDROID_KEY_ALIAS` | 密钥别名 |
| `ANDROID_KEY_PASSWORD` | 密钥密码 |

现有版本使用本机的 `~/.android/debug.keystore`。必须保留并备份这把密钥，不能由 CI 重新生成。
发布脚本会把 APK 的签名 SHA-256 与已发布 `v1.0.1` 的签名核对，不一致就停止发布。
密钥、`android/key.properties` 和密码均不提交到 Git。
工作流通过仓库内置 `GITHUB_TOKEN` 创建标签和 Release，无需把 Token 放进 App。

### 日常发布

1. 在功能分支修改代码，准备发布时修改 `pubspec.yaml` 的版本。
2. 检查后合并到 `main`。普通业务代码提交不会启动发布工作流。
3. `main` 上的 `pubspec.yaml` 变化时，Actions 先比较推送前后的版本；只改依赖、版本不变时直接结束。
4. 版本增加后，自动构建多架构 APK、核对版本和签名，并确认包内没有迁移 CSV。
5. 构建通过后创建附注标签，先上传到草稿 Release，产物齐全后才发布。

Release 包含 `HoshiLedger-vX.Y.Z.N.apk`、对应 `.sha256` 和 `latest.json`。
`latest.json` 提供版本、整数版本码、大小、校验值、更新说明、提交和 APK 下载地址。
同一提交可以重跑失败的发布流程；已正式发布的文件不覆盖，同名标签也不移动。
发布串行执行，较旧版本不会取代新版的 latest Release。

### 手机更新

App 启动时最多每 24 小时自动检查一次，失败时不打断记账；可在设置中关闭自动检查或手动检查。
更新地址是公开仓库的 `releases/latest/download/latest.json`，不会携带任何账单数据或 GitHub Token。
下载支持进度和取消，完成后校验大小与 SHA-256；安装前再校验包名、版本和签名。
Android 的安装授权和最终安装确认由系统处理，不会静默安装。
需要先手动覆盖安装一次带更新器的 `1.0.2.0`，后续才能从 App 内更新。

### 回退

开发基准为 `v1.0.1` / `145a308`，当前功能在 `codex/auto-update-release` 分支完成。
未合并时可直接回到 `main` 检查旧实现；合并后可用新的 revert 提交撤回代码，保留原有提交历史。
手机安装过较高版本后，修复发布必须继续增加版本号，不能移动已有标签或降低安装版本码。
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
   flutter build apk --release
   ```

---
*本项目由 Antigravity (AI Coding Assistant) 协作完成。*
