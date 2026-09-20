import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../data/services/share_service.dart';
import '../../domain/models/sticker.dart';
import '../../domain/models/tag.dart';
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
  final _shareService = ShareService();
  final Map<String, String> _absCache = {};

  bool _selecting = false;
  final Set<String> _selectedIds = {};

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

  void _enterSelection([Sticker? seed]) {
    setState(() {
      _selecting = true;
      _selectedIds.clear();
      if (seed != null) _selectedIds.add(seed.id);
    });
  }

  void _exitSelection() {
    setState(() {
      _selecting = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelected(Sticker sticker) {
    setState(() {
      if (_selectedIds.contains(sticker.id)) {
        _selectedIds.remove(sticker.id);
      } else {
        _selectedIds.add(sticker.id);
      }
    });
  }

  Future<List<String>?> _promptTags({
    required String title,
    String confirmLabel = '保存',
    bool allowSkip = false,
    List<Tag> initialTags = const [],
  }) {
    final state = context.read<AppState>();
    return showTagsEditorSheet(
      context,
      title: title,
      confirmLabel: confirmLabel,
      allowSkip: allowSkip,
      initialTags: initialTags,
      suggestions: state.allTags,
      recentTagNames: state.recentTagNames,
    );
  }

  Future<void> _importFiles(List<File> files) async {
    if (files.isEmpty || !mounted) return;
    final tags = await _promptTags(
      title: '为这批表情打标签',
      confirmLabel: '应用并导入',
      allowSkip: true,
    );
    // null (dismiss) or empty (稍后) → import without tags
    if (!mounted) return;
    final tagNames = tags ?? const <String>[];
    try {
      await context.read<AppState>().addImages(files, tagNames: tagNames);
      if (!mounted) return;
      final tagHint = tagNames.isEmpty ? '' : '（已打标签）';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加 ${files.length} 张图片$tagHint')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加失败：$e')),
      );
    }
  }

  Future<void> _addFromGallery() async {
    try {
      final images = await _imagePicker.pickMultiImage(imageQuality: 95);
      if (images.isEmpty || !mounted) return;
      await _importFiles(images.map((x) => File(x.path)).toList());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加失败：$e')),
      );
    }
  }

  Future<void> _addFromFiles() async {
    try {
      final picked = await FilePicker.pickFiles(type: FileType.image);
      if (picked.isEmpty || !mounted) return;
      final files = picked
          .where((f) => f.path != null)
          .map((f) => File(f.path!))
          .toList();
      await _importFiles(files);
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
    final result = await _promptTags(
      title: '编辑标签',
      initialTags: sticker.tags,
    );
    if (result == null || !mounted) return;
    await context.read<AppState>().setStickerTags(sticker.id, result);
  }

  Future<void> _batchTagSelected() async {
    if (_selectedIds.isEmpty) return;
    final result = await _promptTags(
      title: '为 ${_selectedIds.length} 张打标签',
      confirmLabel: '添加标签',
    );
    if (result == null || !mounted) return;
    if (result.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择至少一个标签')),
      );
      return;
    }
    await context
        .read<AppState>()
        .addTagsToStickers(_selectedIds.toList(), result);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已为 ${_selectedIds.length} 张添加标签')),
    );
    _exitSelection();
  }

  Future<void> _shareSticker(Sticker sticker) async {
    try {
      final path = await _abs(sticker.relativePath);
      await _shareService.shareImageFile(path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('分享失败：$e')),
      );
    }
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
    setState(() => _selectedIds.remove(sticker.id));
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

  PreferredSizeWidget _buildAppBar(AppState state) {
    if (_selecting) {
      return AppBar(
        leading: IconButton(
          tooltip: '取消选择',
          icon: const Icon(Icons.close),
          onPressed: _exitSelection,
        ),
        title: Text('已选 ${_selectedIds.length}'),
        actions: [
          IconButton(
            tooltip: '全选',
            icon: const Icon(Icons.select_all),
            onPressed: () {
              setState(() {
                _selectedIds
                  ..clear()
                  ..addAll(state.stickers.map((s) => s.id));
              });
            },
          ),
          IconButton(
            tooltip: '打标签',
            icon: const Icon(Icons.label_outline),
            onPressed: _selectedIds.isEmpty ? null : _batchTagSelected,
          ),
        ],
      );
    }
    return AppBar(
      title: const Text('表情包管理'),
      actions: [
        IconButton(
          tooltip: '多选',
          icon: const Icon(Icons.checklist),
          onPressed: state.stickers.isEmpty ? null : () => _enterSelection(),
        ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: _buildAppBar(state),
      floatingActionButton: _selecting
          ? null
          : FloatingActionButton.extended(
              onPressed: _showAddSheet,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('添加'),
            ),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().load(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildTagFilters(state)),
            ..._buildBodySlivers(state),
          ],
        ),
      ),
      bottomNavigationBar: _selecting && _selectedIds.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: _batchTagSelected,
                  icon: const Icon(Icons.label_outline),
                  label: Text('打标签（${_selectedIds.length}）'),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildTagFilters(AppState state) {
    final hasFilters =
        state.allTags.isNotEmpty || state.filterUntaggedOnly;
    if (!hasFilters && state.allTags.isEmpty) {
      // Still show 未标签 chip once there are stickers (useful even with no tags yet).
      if (state.stickers.isEmpty && !state.filterUntaggedOnly) {
        return const SizedBox.shrink();
      }
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          FilterChip(
            label: const Text('全部'),
            selected: state.selectedTagIds.isEmpty && !state.filterUntaggedOnly,
            onSelected: (_) => context.read<AppState>().clearTagFilters(),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('未标签'),
            selected: state.filterUntaggedOnly,
            onSelected: (v) =>
                context.read<AppState>().setFilterUntaggedOnly(v),
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
                state.selectedTagIds.isEmpty && !state.filterUntaggedOnly
                    ? '还没有表情\n点击右下角「添加」开始'
                    : '没有符合筛选条件的表情',
                textAlign: TextAlign.center,
              ),
              if (state.selectedTagIds.isNotEmpty ||
                  state.filterUntaggedOnly) ...[
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

    final spacing = state.gridColumns >= 5 ? 6.0 : 10.0;
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: state.gridColumns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: 1,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final sticker = state.stickers[index];
              final selected = _selectedIds.contains(sticker.id);
              return _StickerTile(
                sticker: sticker,
                absFuture: _abs(sticker.relativePath),
                compact: state.gridColumns >= 5,
                selecting: _selecting,
                selected: selected,
                onTap: () {
                  if (_selecting) {
                    _toggleSelected(sticker);
                  } else {
                    _openViewer(index);
                  }
                },
                onLongPress: () {
                  if (_selecting) {
                    _toggleSelected(sticker);
                  } else {
                    _enterSelection(sticker);
                  }
                },
                onShare: () => _shareSticker(sticker),
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
    required this.compact,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onShare,
    required this.onEditTags,
    required this.onDelete,
  });

  final Sticker sticker;
  final Future<String> absFuture;
  final bool compact;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onShare;
  final VoidCallback onEditTags;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(compact ? 12 : 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
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
            if (sticker.tags.isNotEmpty && !selecting)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 4 : 8,
                    vertical: compact ? 4 : 6,
                  ),
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
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 10 : 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            if (selecting)
              Positioned(
                top: 6,
                left: 6,
                child: Icon(
                  selected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: selected ? scheme.primary : Colors.white,
                  shadows: const [
                    Shadow(color: Colors.black54, blurRadius: 4),
                  ],
                ),
              )
            else
              Positioned(
                top: 2,
                right: 2,
                child: PopupMenuButton<String>(
                  tooltip: '更多',
                  padding: EdgeInsets.zero,
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.more_vert,
                      color: Colors.white,
                      size: compact ? 16 : 18,
                    ),
                  ),
                  onSelected: (value) {
                    if (value == 'share') onShare();
                    if (value == 'tags') onEditTags();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'share',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.share_outlined),
                        title: Text('分享'),
                        dense: true,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'tags',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.label_outline),
                        title: Text('编辑标签'),
                        dense: true,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delete_outline),
                        title: Text('删除'),
                        dense: true,
                      ),
                    ),
                  ],
                ),
              ),
            if (selected)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.22),
                      border: Border.all(color: scheme.primary, width: 2),
                      borderRadius: BorderRadius.circular(compact ? 12 : 16),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
