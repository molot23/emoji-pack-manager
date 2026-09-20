import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/repositories/sticker_repository.dart';
import '../domain/models/sticker.dart';
import '../domain/models/tag.dart';

class AppState extends ChangeNotifier {
  AppState({StickerRepository? repository})
      : _repo = repository ?? StickerRepository();

  final StickerRepository _repo;

  List<Sticker> stickers = [];
  List<Tag> allTags = [];
  Set<String> selectedTagIds = {};
  StickerSort sort = StickerSort.newest;
  bool loading = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      allTags = await _repo.getAllTags();
      stickers = await _repo.getStickers(
        tagIds: selectedTagIds,
        sort: sort,
      );
    } catch (e) {
      error = '加载失败：$e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> setSort(StickerSort value) async {
    if (sort == value) return;
    sort = value;
    await load();
  }

  Future<void> toggleTagFilter(String tagId) async {
    if (selectedTagIds.contains(tagId)) {
      selectedTagIds = {...selectedTagIds}..remove(tagId);
    } else {
      selectedTagIds = {...selectedTagIds, tagId};
    }
    await load();
  }

  Future<void> clearTagFilters() async {
    if (selectedTagIds.isEmpty) return;
    selectedTagIds = {};
    await load();
  }

  Future<void> addImages(
    List<File> files, {
    List<String> tagNames = const [],
  }) async {
    for (final f in files) {
      await _repo.addStickerFromFile(source: f, tagNames: tagNames);
    }
    await load();
  }

  Future<void> deleteSticker(Sticker sticker) async {
    await _repo.deleteSticker(sticker);
    await load();
  }

  Future<void> setStickerTags(String stickerId, List<String> tagNames) async {
    await _repo.setStickerTags(stickerId, tagNames);
    await load();
  }

  Future<String> absolutePath(String relativePath) {
    return _repo.resolveAbsolutePath(relativePath);
  }
}
