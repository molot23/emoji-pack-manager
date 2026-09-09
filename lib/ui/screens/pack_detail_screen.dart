import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../domain/models/sticker.dart';
import '../app_state.dart';
import '../widgets/name_dialog.dart';

class PackDetailScreen extends StatefulWidget {
  const PackDetailScreen({super.key});

  @override
  State<PackDetailScreen> createState() => _PackDetailScreenState();
}

class _PackDetailScreenState extends State<PackDetailScreen> {
  final _imagePicker = ImagePicker();
  final Map<String, String> _absCache = {};

  Future<String> _abs(String relative) async {
    if (_absCache.containsKey(relative)) return _absCache[relative]!;
    final path = await context.read<AppState>().absolutePath(relative);
    _absCache[relative] = path;
    return path;
  }

  Future<void> _addFromGallery() async {
    try {
      final images = await _imagePicker.pickMultiImage(imageQuality: 95);
      if (images.isEmpty || !mounted) return;
      final files = images.map((x) => File(x.path)).toList();
      await context.read<AppState>().addImages(files);
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

  Future<void> _addFromFiles() async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.image,
      );
      if (picked.isEmpty || !mounted) return;
      final files = picked
          .where((f) => f.path != null)
          .map((f) => File(f.path!))
          .toList();
      if (files.isEmpty) return;
      await context.read<AppState>().addImages(files);
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

  Future<void> _deleteSticker(Sticker sticker) async {
    final ok = await showConfirmDialog(
      context,
      title: '删除图片',
      message: '确定删除这张图片吗？',
    );
    if (!ok || !mounted) return;
    await context.read<AppState>().deleteSticker(sticker);
  }

  Future<void> _preview(Sticker sticker) async {
    final path = await _abs(sticker.relativePath);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: InteractiveViewer(
                  child: Image.file(File(path), fit: BoxFit.contain),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('关闭'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(ctx).colorScheme.error,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _deleteSticker(sticker);
                      },
                      child: const Text('删除'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pack = state.currentPack;
    if (pack == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('表情包')),
        body: const Center(child: Text('未选择表情包')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(pack.name),
        actions: [
          IconButton(
            tooltip: '添加图片',
            icon: const Icon(Icons.add_photo_alternate_outlined),
            onPressed: _showAddSheet,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSheet,
        icon: const Icon(Icons.add),
        label: const Text('添加图片'),
      ),
      body: state.loading && state.currentStickers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.currentStickers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.image_outlined,
                        size: 72,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 12),
                      const Text('这个表情包还没有图片'),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: _showAddSheet,
                        child: const Text('添加图片'),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: state.currentStickers.length,
                  itemBuilder: (context, index) {
                    final sticker = state.currentStickers[index];
                    return FutureBuilder<String>(
                      future: _abs(sticker.relativePath),
                      builder: (context, snap) {
                        Widget child;
                        if (!snap.hasData) {
                          child = const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        } else {
                          child = Image.file(
                            File(snap.data!),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.broken_image_outlined,
                            ),
                          );
                        }
                        return Material(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _preview(sticker),
                            onLongPress: () => _deleteSticker(sticker),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                child,
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: IconButton.filledTonal(
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.black45,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.all(4),
                                      minimumSize: const Size(28, 28),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    iconSize: 16,
                                    icon: const Icon(Icons.close),
                                    onPressed: () => _deleteSticker(sticker),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
