import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/repositories/pack_repository.dart';
import '../domain/models/pack.dart';
import '../domain/models/sticker.dart';

class AppState extends ChangeNotifier {
  AppState({PackRepository? repository})
      : _repo = repository ?? PackRepository();

  final PackRepository _repo;

  List<Pack> packs = [];
  List<Sticker> currentStickers = [];
  Pack? currentPack;
  bool loading = false;
  String? error;

  Future<void> loadPacks() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      packs = await _repo.getAllPacks();
    } catch (e) {
      error = '加载失败：$e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> createPack(String name) async {
    if (name.trim().isEmpty) {
      throw ArgumentError('名称不能为空');
    }
    await _repo.createPack(name);
    await loadPacks();
  }

  Future<void> renamePack(String id, String name) async {
    if (name.trim().isEmpty) {
      throw ArgumentError('名称不能为空');
    }
    await _repo.renamePack(id, name);
    await loadPacks();
    if (currentPack?.id == id) {
      currentPack = await _repo.getPack(id);
      notifyListeners();
    }
  }

  Future<void> deletePack(String id) async {
    await _repo.deletePack(id);
    if (currentPack?.id == id) {
      currentPack = null;
      currentStickers = [];
    }
    await loadPacks();
  }

  Future<void> openPack(Pack pack) async {
    currentPack = pack;
    loading = true;
    notifyListeners();
    try {
      currentStickers = await _repo.getStickers(pack.id);
      currentPack = await _repo.getPack(pack.id);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshCurrentPack() async {
    if (currentPack == null) return;
    currentStickers = await _repo.getStickers(currentPack!.id);
    currentPack = await _repo.getPack(currentPack!.id);
    await loadPacks();
  }

  Future<void> addImages(List<File> files) async {
    if (currentPack == null) return;
    for (final f in files) {
      await _repo.addStickerFromFile(packId: currentPack!.id, source: f);
    }
    await refreshCurrentPack();
  }

  Future<void> deleteSticker(Sticker sticker) async {
    await _repo.deleteSticker(sticker);
    await refreshCurrentPack();
  }

  Future<String> absolutePath(String relativePath) {
    return _repo.resolveAbsolutePath(relativePath);
  }
}
