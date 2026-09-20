import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../domain/models/sticker.dart';
import '../app_state.dart';
import '../widgets/name_dialog.dart';
import '../widgets/tags_editor_dialog.dart';
import 'settings_screen.dart';
import 'viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _imagePicker = ImagePicker();
  final Map<String, String> _absCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().load();
    });
  }

  Future<String> _abs(String relative) async {
    if (_absCache.containsKey(relative)) return _absCache[relative]!;
    final path = await context.read<AppState>().absolutePath(relative);
    _absCache[relative] = path;
    return path;
  }

  Future<void> _addFromGallery({List<String> tagNames = const []}) async {
    try {
      final images = await _imagePicker.pickMultiImage(imageQuality: 95);
      if (images.isEmpty || !mounted) return;
      final files = images.map((x) => File(x.path)).toList();
      await context.read<AppState>().addImages(files, tagNames: tagNames);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加 ${files.length} 张图片')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加失败：$e')),
      );
    }
  }

  Future<void> _addFromFiles({List<String> tagNames = const []}) async {
    try {
      final picked = await FilePicker.pickFiles(type: FileType.image);
      if (picked.isEmpty || !mounted) return;
      final files = picked
          .where((f) => f.path != null)
          .map((f) => File(f.path!))
          .toList();
      if (files.isEmpty) return;
      await context.read<AppState>().addImages(files, tagNames: tagNames);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加 ${files.length} 张图片')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加失败：$e')),
      );
    }
  }

  Future<void> _showAddSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('从相册选择'),
                onTap: () {
                  Navigator.pop(ctx);
                  _addFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_open_outlined),
                title: const Text('从文件选择'),
                onTap: () {
                  Navigator.pop(ctx);
                  _addFromFiles();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editTags(Sticker sticker) async {
    final state = context.read<AppState>();
    final result = await showTagsEditorDialog(
      context,
      initialTags: sticker.tags,
      suggestions: state.allTags,
    );
    if (result == null || !mounted) return;
    await state.setStickerTags(sticker.id, result);
  }

  Future<void> _deleteSticker(Sticker sticker) async {
    final ok = await showConfirmDialog(
      context,
      title: '删除图片',
      message: '确定删除这张图片吗？',
    );
    if (!ok || !mounted) return;
    await context.read<AppState>().deleteSticker(sticker);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已删除')),
    );
  }

  void _openViewer(int index) {
    final stickers = context.read<AppState>().stickers;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ViewerScreen(
          stickers: List.of(stickers),
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('表情包管理'),
        actions: [
          PopupMenuButton<StickerSort>(
            tooltip: '排序',
            icon: const Icon(Icons.sort),
            initialValue: state.sort,
            onSelected: (v) => context.read<AppState>().setSort(v),
            itemBuilder: (context) => [
              for (final s in StickerSort.values)
                PopupMenuItem(
                  value: s,
                  child: Row(
                    children: [
                      if (state.sort == s)
                        Icon(Icons.check,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary)
                      else
                        const SizedBox(width: 18),
                      const SizedBox(width: 8),
                      Text(s.label),
                    ],
                  ),
                ),
            ],
          ),
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
        onPressed: _showAddSheet,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('添加'),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().load(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (state.allTags.isNotEmpty)
              SliverToBoxAdapter(child: _buildTagFilters(state)),
            ..._buildBodySlivers(state),
          ],
        ),
      ),
    );
  }

  Widget _buildTagFilters(AppState state) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          FilterChip(
            label: const Text('全部'),
            selected: state.selectedTagIds.isEmpty,
            onSelected: (_) => context.read<AppState>().clearTagFilters(),
          ),
          const SizedBox(width: 8),
          for (final tag in state.allTags) ...[
            FilterChip(
              label: Text('${tag.name} (${tag.stickerCount})'),
              selected: state.selectedTagIds.contains(tag.id),
              onSelected: (_) =>
                  context.read<AppState>().toggleTagFilter(tag.id),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildBodySlivers(AppState state) {
    if (state.loading && state.stickers.isEmpty) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (state.error != null && state.stickers.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: Text(state.error!)),
        ),
      ];
    }
    if (state.stickers.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 72,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                state.selectedTagIds.isEmpty
                    ? '还没有表情\n点击右下角「添加」开始'
                    : '没有符合筛选条件的表情',
                textAlign: TextAlign.center,
              ),
              if (state.selectedTagIds.isNotEmpty) ...[
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () => context.read<AppState>().clearTagFilters(),
                  child: const Text('清除筛选'),
                ),
              ],
            ],
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final sticker = state.stickers[index];
              return _StickerTile(
                sticker: sticker,
                absFuture: _abs(sticker.relativePath),
                onTap: () => _openViewer(index),
                onEditTags: () => _editTags(sticker),
                onDelete: () => _deleteSticker(sticker),
              );
            },
            childCount: state.stickers.length,
          ),
        ),
      ),
    ];
  }
}

class _StickerTile extends StatelessWidget {
  const _StickerTile({
    required this.sticker,
    required this.absFuture,
    required this.onTap,
    required this.onEditTags,
    required this.onDelete,
  });

  final Sticker sticker;
  final Future<String> absFuture;
  final VoidCallback onTap;
  final VoidCallback onEditTags;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onEditTags,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder<String>(
              future: absFuture,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                return Image.file(
                  File(snap.data!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined),
                );
              },
            ),
            if (sticker.tags.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black54, Colors.transparent],
                    ),
                  ),
                  child: Text(
                    sticker.tags.map((t) => t.name).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 4,
              right: 4,
              child: PopupMenuButton<String>(
                tooltip: '更多',
                padding: EdgeInsets.zero,
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.more_vert,
                      color: Colors.white, size: 18),
                ),
                onSelected: (value) {
                  if (value == 'tags') onEditTags();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'tags', child: Text('编辑标签')),
                  PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
