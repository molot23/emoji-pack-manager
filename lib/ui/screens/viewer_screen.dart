import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/services/share_service.dart';
import '../../domain/models/sticker.dart';
import '../app_state.dart';
import '../widgets/name_dialog.dart';
import '../widgets/tags_editor_dialog.dart';

class ViewerScreen extends StatefulWidget {
  const ViewerScreen({
    super.key,
    required this.stickers,
    required this.initialIndex,
  });

  final List<Sticker> stickers;
  final int initialIndex;

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  late final PageController _pageController;
  late int _index;
  final Map<String, String> _absCache = {};
  final _shareService = ShareService();
  bool _uiVisible = true;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.stickers.length - 1);
    _pageController = PageController(initialPage: _index);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageController.dispose();
    super.dispose();
  }

  List<Sticker> get _stickers {
    final live = context.read<AppState>().stickers;
    if (live.isEmpty) return widget.stickers;
    return live;
  }

  Sticker? get _current {
    final list = _stickers;
    if (list.isEmpty) return null;
    final i = _index.clamp(0, list.length - 1);
    return list[i];
  }

  Future<String> _abs(String relative) async {
    if (_absCache.containsKey(relative)) return _absCache[relative]!;
    final path = await context.read<AppState>().absolutePath(relative);
    _absCache[relative] = path;
    return path;
  }

  Future<void> _editTags() async {
    final sticker = _current;
    if (sticker == null) return;
    final state = context.read<AppState>();
    final result = await showTagsEditorSheet(
      context,
      initialTags: sticker.tags,
      suggestions: state.allTags,
      recentTagNames: state.recentTagNames,
    );
    if (result == null || !mounted) return;
    await state.setStickerTags(sticker.id, result);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _removeTag(String name) async {
    final sticker = _current;
    if (sticker == null) return;
    await context.read<AppState>().removeTagFromSticker(sticker.id, name);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _quickAddTag(String name) async {
    final sticker = _current;
    if (sticker == null) return;
    await context.read<AppState>().addTagToSticker(sticker.id, name);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _share() async {
    final sticker = _current;
    if (sticker == null) return;
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

  Future<void> _delete() async {
    final sticker = _current;
    if (sticker == null) return;
    final ok = await showConfirmDialog(
      context,
      title: '删除图片',
      message: '确定删除这张图片吗？',
    );
    if (!ok || !mounted) return;
    final list = _stickers;
    final wasLast = list.length <= 1;
    final nextIndex = _index >= list.length - 1 ? _index - 1 : _index;
    await context.read<AppState>().deleteSticker(sticker);
    if (!mounted) return;
    if (wasLast) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _index = nextIndex.clamp(0, context.read<AppState>().stickers.length - 1);
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(_index);
    }
  }

  Widget _buildTagBar(Sticker current, AppState state) {
    final currentNames = current.tags.map((t) => t.name).toSet();
    final recent = state.recentTagNames
        .where((n) => n.trim().isNotEmpty && !currentNames.contains(n))
        .take(6)
        .toList();

    return Material(
      color: Colors.black54,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final tag in current.tags)
                  InputChip(
                    label: Text(tag.name),
                    onDeleted: () => _removeTag(tag.name),
                    deleteIconColor: Colors.white70,
                    backgroundColor: Colors.white24,
                    labelStyle: const TextStyle(color: Colors.white),
                    side: BorderSide.none,
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18, color: Colors.white),
                  label: const Text('添加', style: TextStyle(color: Colors.white)),
                  backgroundColor: Colors.white24,
                  side: BorderSide.none,
                  onPressed: _editTags,
                ),
                if (current.tags.isEmpty)
                  const Text(
                    '无标签',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
              ],
            ),
            if (recent.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '最近',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white70,
                    ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final name in recent)
                    ActionChip(
                      avatar: const Icon(Icons.history,
                          size: 16, color: Colors.white70),
                      label: Text(
                        name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.white12,
                      side: BorderSide.none,
                      onPressed: () => _quickAddTag(name),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final list = state.stickers.isNotEmpty ? state.stickers : widget.stickers;
    if (list.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('没有图片', style: TextStyle(color: Colors.white)),
        ),
      );
    }
    final safeIndex = _index.clamp(0, list.length - 1);
    final current = list[safeIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: list.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, index) {
              final sticker = list[index];
              return GestureDetector(
                onTap: () => setState(() => _uiVisible = !_uiVisible),
                child: FutureBuilder<String>(
                  future: _abs(sticker.relativePath),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    }
                    return InteractiveViewer(
                      minScale: 1,
                      maxScale: 5,
                      child: Center(
                        child: Image.file(
                          File(snap.data!),
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white54,
                            size: 64,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          if (_uiVisible) ...[
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Material(
                  color: Colors.black54,
                  child: ListTile(
                    leading: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    title: Text(
                      '${safeIndex + 1} / ${list.length}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: '分享',
                          icon: const Icon(Icons.share, color: Colors.white),
                          onPressed: _share,
                        ),
                        IconButton(
                          tooltip: '编辑标签',
                          icon: const Icon(Icons.label_outline,
                              color: Colors.white),
                          onPressed: _editTags,
                        ),
                        IconButton(
                          tooltip: '删除',
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.white),
                          onPressed: _delete,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _buildTagBar(current, state),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
