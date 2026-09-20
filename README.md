# 表情包管理（安卓）

本地-only 表情相册与标签管理器。数据全部保存在手机本地，**不支持** WebDAV、云同步或 Windows。

- 应用名：表情包管理
- 包名：`com.emojipack.manager`
- 技术：Flutter + Material 3 + sqflite
- 当前版本：`0.2.1+4`

## 功能（相册 + 标签）

- **统一相册**：所有表情在缩略图网格中浏览（不再以「表情包」为一级结构）
- **网格列数**：设置页可切换主页每行 3 / 4 / 5 / 6 列（默认 4，SharedPreferences 持久化）
- **标签**：每张表情可有多个标签；主页按标签筛选（多选为 AND）
- **排序**：最新优先 / 最旧优先 / 按文件名
- **添加**：从相册或文件选择；删除；编辑标签
- **分享**：主页长按菜单 / 磁贴「⋯」菜单，以及全屏查看页顶部「分享」，通过系统分享面板发送图片文件（`image/*`）
- **全屏查看**：左右滑动浏览，支持捏合缩放；可分享、编辑标签或删除
- **持久化**：SQLite（`emoji_pack_manager.db`）+ 应用文档目录下 `stickers/` 图片文件
- **设置**：网格列数、关于、包名、本地存储说明、**检查更新**（GitHub Releases API）

## 从旧版迁移

从 `0.1.x`（表情包模式）升级到 `0.2.0` 时：

- 所有贴纸合并进同一相册
- 原表情包名称会尽量写成该贴纸的初始标签
- 图片文件路径保持不变
- 全新安装直接使用相册 + 标签结构

## 环境

本仓库构建时使用：

- Flutter 3.47.2（stable）
- Dart 3.13.2
- Android SDK 36 / Build-Tools 36.0.0
- JDK 17

## 运行（调试）

```bash
cd /workspace/emoji-pack-manager
source /workspace/tools/env.sh   # 或自行配置 PATH
flutter pub get
flutter run
```

## 构建 APK

```bash
flutter build apk --release --split-per-abi
```

产物示例：

- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- 便捷副本：`emoji-pack-manager-arm64-release.apk`（项目根目录）

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
| `shared_preferences` | 网格列数等偏好 |
| `share_plus` | 系统分享面板发送图片 |
| `package_info_plus` | 读取本地版本号 |
| `http` | 请求 GitHub Releases API |
| `url_launcher` | 打开下载页（浏览器） |

## 目录结构（摘要）

```
lib/
  domain/models/     # Sticker、Tag
  data/database/     # sqflite（含 v1→v2 迁移）
  data/services/     # 图片文件存储、检查更新、分享
  data/repositories/ # StickerRepository
  ui/screens/        # 相册首页、全屏查看、设置
  ui/widgets/        # 标签编辑、确认对话框
  app.dart / main.dart
```

## 数据模型

- `stickers`：id、file_name、relative_path、created_at
- `tags`：id、name（唯一）、created_at
- `sticker_tags`：多对多关联
- 新图片保存在 `stickers/album/`；旧版包目录下的文件仍可按原 relative_path 访问

## 检查更新

设置页「检查更新」：通过公开 GitHub API 读取
[`releases/latest`](https://github.com/molot23/emoji-pack-manager/releases/latest)，
与本地版本比较。

## 说明

- 卸载应用会清除本地数据库与图片。
- 本版本支持系统分享图片；不做云同步。
