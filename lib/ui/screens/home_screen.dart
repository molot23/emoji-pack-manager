import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../widgets/name_dialog.dart';
import 'pack_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadPacks();
    });
  }

  Future<void> _createPack() async {
    final name = await showNameDialog(
      context,
      title: '新建表情包',
      hint: '例如：日常表情',
      confirmLabel: '创建',
    );
    if (name == null || !mounted) return;
    try {
      await context.read<AppState>().createPack(name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已创建「$name」')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建失败：$e')),
      );
    }
  }

  Future<void> _renamePack(String id, String current) async {
    final name = await showNameDialog(
      context,
      title: '重命名表情包',
      initial: current,
      confirmLabel: '保存',
    );
    if (name == null || !mounted) return;
    await context.read<AppState>().renamePack(id, name);
  }

  Future<void> _deletePack(String id, String name) async {
    final ok = await showConfirmDialog(
      context,
      title: '删除表情包',
      message: '确定删除「$name」及其全部图片吗？此操作不可恢复。',
    );
    if (!ok || !mounted) return;
    await context.read<AppState>().deletePack(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已删除「$name」')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('表情包管理'),
        actions: [
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createPack,
        icon: const Icon(Icons.add),
        label: const Text('新建'),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().loadPacks(),
        child: _buildBody(state),
      ),
    );
  }

  Widget _buildBody(AppState state) {
    if (state.loading && state.packs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.packs.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(child: Text(state.error!)),
        ],
      );
    }
    if (state.packs.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Icon(
            Icons.emoji_emotions_outlined,
            size: 72,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text('还没有表情包\n点击右下角「新建」开始', textAlign: TextAlign.center),
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: state.packs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final pack = state.packs[index];
        return Card(
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              child: Icon(
                Icons.collections,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
            title: Text(pack.name),
            subtitle: Text('${pack.stickerCount} 张图片'),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'rename') {
                  _renamePack(pack.id, pack.name);
                } else if (value == 'delete') {
                  _deletePack(pack.id, pack.name);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'rename', child: Text('重命名')),
                PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
            ),
            onTap: () async {
              await context.read<AppState>().openPack(pack);
              if (!context.mounted) return;
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PackDetailScreen()),
              );
              if (context.mounted) {
                await context.read<AppState>().loadPacks();
              }
            },
          ),
        );
      },
    );
  }
}
