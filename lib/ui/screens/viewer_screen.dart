import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
    // Prefer live list from AppState when ids still match.
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
    final result = await showTagsEditorDialog(
      context,
      initialTags: sticker.tags,
      suggestions: state.allTags,
    );
    if (result == null || !mounted) return;
    await state.setStickerTags(sticker.id, result);
    if (!mounted) return;
    setState(() {});
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
                    subtitle: current.tags.isEmpty
                        ? const Text(
                            '无标签',
                            style: TextStyle(color: Colors.white70),
                          )
                        : Text(
                            current.tags.map((t) => t.name).join(' · '),
                            style: const TextStyle(color: Colors.white70),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
          ],
        ],
      ),
    );
  }
}
