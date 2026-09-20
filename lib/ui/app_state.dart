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
  static const prefsRecentTagsKey = 'recent_tag_names';
  static const defaultGridColumns = 4;
  static const allowedGridColumns = [3, 4, 5, 6];
  static const maxRecentTags = 10;

  List<Sticker> stickers = [];
  List<Tag> allTags = [];
  List<String> recentTagNames = [];
  Set<String> selectedTagIds = {};
  bool filterUntaggedOnly = false;
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
        untaggedOnly: filterUntaggedOnly,
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
    recentTagNames = prefs.getStringList(prefsRecentTagsKey) ?? [];
  }

  Future<void> setGridColumns(int value) async {
    if (!allowedGridColumns.contains(value) || gridColumns == value) return;
    gridColumns = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(prefsGridColumnsKey, value);
  }

  /// Record tags as recently used (most recent first, capped).
  Future<void> recordRecentTags(List<String> names) async {
    final cleaned = <String>[];
    for (final raw in names) {
      final n = raw.trim();
      if (n.isEmpty) continue;
      cleaned.remove(n);
      cleaned.add(n);
    }
    if (cleaned.isEmpty) return;

    final next = <String>[...cleaned.reversed, ...recentTagNames];
    final seen = <String>{};
    final deduped = <String>[];
    for (final n in next) {
      if (seen.add(n)) deduped.add(n);
      if (deduped.length >= maxRecentTags) break;
    }
    recentTagNames = deduped;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(prefsRecentTagsKey, recentTagNames);
  }

  Future<void> setSort(StickerSort value) async {
    if (sort == value) return;
    sort = value;
    await load();
  }

  Future<void> toggleTagFilter(String tagId) async {
    filterUntaggedOnly = false;
    if (selectedTagIds.contains(tagId)) {
      selectedTagIds = {...selectedTagIds}..remove(tagId);
    } else {
      selectedTagIds = {...selectedTagIds, tagId};
    }
    await load();
  }

  Future<void> setFilterUntaggedOnly(bool value) async {
    if (value == filterUntaggedOnly &&
        (!value || selectedTagIds.isEmpty)) {
      return;
    }
    filterUntaggedOnly = value;
    if (value) selectedTagIds = {};
    await load();
  }

  Future<void> clearTagFilters() async {
    if (selectedTagIds.isEmpty && !filterUntaggedOnly) return;
    selectedTagIds = {};
    filterUntaggedOnly = false;
    await load();
  }

  Future<void> addImages(
    List<File> files, {
    List<String> tagNames = const [],
  }) async {
    for (final f in files) {
      await _repo.addStickerFromFile(source: f, tagNames: tagNames);
    }
    if (tagNames.isNotEmpty) {
      await recordRecentTags(tagNames);
    }
    await load();
  }

  Future<void> deleteSticker(Sticker sticker) async {
    await _repo.deleteSticker(sticker);
    await load();
  }

  Future<void> setStickerTags(String stickerId, List<String> tagNames) async {
    await _repo.setStickerTags(stickerId, tagNames);
    if (tagNames.isNotEmpty) {
      await recordRecentTags(tagNames);
    }
    await load();
  }

  /// Add [tagNames] onto each sticker (union; does not remove existing tags).
  Future<void> addTagsToStickers(
    List<String> stickerIds,
    List<String> tagNames,
  ) async {
    if (stickerIds.isEmpty || tagNames.isEmpty) return;
    await _repo.addTagsToStickers(stickerIds, tagNames);
    await recordRecentTags(tagNames);
    await load();
  }

  /// Remove a single tag name from one sticker.
  Future<void> removeTagFromSticker(String stickerId, String tagName) async {
    Sticker? sticker;
    for (final s in stickers) {
      if (s.id == stickerId) {
        sticker = s;
        break;
      }
    }
    sticker ??= await _repo.getSticker(stickerId);
    if (sticker == null) return;
    final names =
        sticker.tags.map((t) => t.name).where((n) => n != tagName).toList();
    await setStickerTags(stickerId, names);
  }

  /// Append one tag to a sticker (viewer quick-add).
  Future<void> addTagToSticker(String stickerId, String tagName) async {
    final name = tagName.trim();
    if (name.isEmpty) return;
    await _repo.addTagsToStickers([stickerId], [name]);
    await recordRecentTags([name]);
    await load();
  }

  Future<String> absolutePath(String relativePath) {
    return _repo.resolveAbsolutePath(relativePath);
  }
}
