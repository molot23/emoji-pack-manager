import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/services/update_check_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static const appName = '表情包管理';
  static const packageId = 'com.emojipack.manager';

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _updateService = UpdateCheckService();

  String _versionLabel = '…';
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _versionLabel = '${info.version}+${info.buildNumber}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _versionLabel = '未知');
    }
  }

  Future<void> _checkForUpdates() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);

    // Brief loading snackbar so the tap feels responsive.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('正在检查更新…'),
        duration: Duration(seconds: 2),
      ),
    );

    final result = await _updateService.checkForUpdates();
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => _checkingUpdate = false);

    switch (result) {
      case UpdateAvailable(
          :final latestTag,
          :final releaseUrl,
          :final notesSummary,
          :final localVersion,
        ):
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('发现新版本'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('当前：$localVersion'),
                  const SizedBox(height: 4),
                  Text('最新：$latestTag'),
                  const SizedBox(height: 12),
                  Text(notesSummary),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('稍后'),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await _openReleasePage(releaseUrl);
                },
                child: const Text('前往下载'),
              ),
            ],
          ),
        );
      case AlreadyLatest(:final localVersion, :final latestTag):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已是最新版（$localVersion / $latestTag）')),
        );
      case UpdateCheckError(:final message):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
    }
  }

  Future<void> _openReleasePage(String url) async {
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法打开下载页面')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开下载页面')),
      );
    }
  }

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
                    SettingsScreen.appName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '版本 $_versionLabel',
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
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('关于'),
                  subtitle: Text('本地表情相册 · 标签管理（安卓）'),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.phone_android),
                  title: Text('应用包名'),
                  subtitle: Text(SettingsScreen.packageId),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: _checkingUpdate
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.system_update_alt),
                  title: const Text('检查更新'),
                  subtitle: const Text('从 GitHub Releases 获取最新版本'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _checkingUpdate ? null : _checkForUpdates,
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.storage_outlined),
                  title: Text('数据存储'),
                  subtitle: Text(
                    '全部保存在本机：SQLite 数据库 + 应用文档目录中的图片文件。卸载应用会清除数据。',
                  ),
                ),
                const Divider(height: 1),
                const ListTile(
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
