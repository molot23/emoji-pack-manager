import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const appName = '表情包管理';
  static const version = '1.0.0';
  static const packageId = 'com.emojipack.manager';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(
                      Icons.emoji_emotions,
                      size: 40,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    appName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '版本 $version',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: const [
                ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('关于'),
                  subtitle: Text('本地表情包 / 贴纸包管理器（安卓 v1）'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.phone_android),
                  title: Text('应用包名'),
                  subtitle: Text(packageId),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.storage_outlined),
                  title: Text('数据存储'),
                  subtitle: Text('全部保存在本机：SQLite 数据库 + 应用文档目录中的图片文件。卸载应用会清除数据。'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.cloud_off_outlined),
                  title: Text('同步'),
                  subtitle: Text('本版本不支持 WebDAV / 云同步，仅本地使用。'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
