# 表情包管理（安卓 v1）

本地-only 表情包 / 贴纸包管理器。数据全部保存在手机本地，**不支持** WebDAV、云同步或微信分享。

- 应用名：表情包管理
- 包名：`com.emojipack.manager`
- 技术：Flutter + Material 3 + sqflite

## 功能

- **表情包**：创建、重命名、删除
- **图片**：从相册或文件选择添加；网格浏览；长按 / 预览中删除单张
- **持久化**：SQLite（`emoji_pack_manager.db`）+ 应用文档目录下 `stickers/<packId>/` 图片文件，杀进程后仍在
- **设置**：关于、应用名、包名、本地存储说明（无同步）

## 环境

本仓库构建时使用：

- Flutter 3.47.2（stable）
- Dart 3.13.2
- Android SDK 36 / Build-Tools 36.0.0
- JDK 17

若在本机开发，请先安装 Flutter 与 Android SDK，并确保 `flutter doctor` 中 Android toolchain 可用。

## 运行（调试）

```bash
cd /workspace/emoji-pack-manager   # 或你的项目路径
flutter pub get
flutter run                        # 连接真机或模拟器
```

## 构建 APK

```bash
flutter build apk --debug
```

产物路径：

- 默认：`build/app/outputs/flutter-apk/app-debug.apk`
- 便捷副本：`emoji-pack-manager-debug.apk`（项目根目录，debug 约 153MB）

将 APK 传到安卓手机后安装即可（可能需允许「未知来源」）。

## 主要依赖

| 包 | 用途 |
|---|---|
| `sqflite` | 本地数据库 |
| `path_provider` | 应用文档目录 |
| `path` | 路径拼接 |
| `uuid` | 主键 / 文件名 |
| `image_picker` | 相册多选 |
| `file_picker` | 文件选择器 |
| `provider` | 简单状态管理 |

## 目录结构（摘要）

```
lib/
  domain/models/     # Pack、Sticker
  data/database/     # sqflite
  data/services/     # 图片文件存储
  data/repositories/ # 业务仓储
  ui/screens/        # 首页、详情、设置
  ui/widgets/        # 对话框等
  app.dart / main.dart
```

## 说明

- 卸载应用会清除本地数据库与图片。
- 本版本为本地 v1，刻意不做同步与分享。
