import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repositories/sticker_repository.dart';
import '../domain/models/sticker.dart';
import '../domain/models/tag.dart';

class AppState extends ChangeNotifier {
  AppState({StickerRepository? repository})
      : _repo = repository ?? StickerRepository();

  final StickerRepository _repo;

  static const prefsGridColumnsKey = 'grid_columns';
  static const defaultGridColumns = 4;
  static const allowedGridColumns = [3, 4, 5, 6];

  List<Sticker> stickers = [];
  List<Tag> allTags = [];
  Set<String> selectedTagIds = {};
  StickerSort sort = StickerSort.newest;
  int gridColumns = defaultGridColumns;
  bool loading = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await _loadPrefs();
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

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(prefsGridColumnsKey);
    if (stored != null && allowedGridColumns.contains(stored)) {
      gridColumns = stored;
    } else {
      gridColumns = defaultGridColumns;
    }
  }

  Future<void> setGridColumns(int value) async {
    if (!allowedGridColumns.contains(value) || gridColumns == value) return;
    gridColumns = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(prefsGridColumnsKey, value);
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
