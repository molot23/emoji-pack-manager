import 'package:flutter/material.dart';

import '../../domain/models/tag.dart';

/// Shared tag-edit UI (dialog or bottom sheet).
///
/// [initialTags] seeds the selected set.
/// [suggestions] are all known tags.
/// [recentTagNames] shown in a 「最近」 row for one-tap add.
/// [allowSkip] shows 「稍后」 instead of/in addition to cancel (import flow).
Future<List<String>?> showTagsEditorSheet(
  BuildContext context, {
  required List<Tag> initialTags,
  required List<Tag> suggestions,
  List<String> recentTagNames = const [],
  String title = '编辑标签',
  String confirmLabel = '保存',
  bool allowSkip = false,
  bool asBottomSheet = true,
}) async {
  final selected = <String>{
    for (final t in initialTags) t.name,
  };
  final controller = TextEditingController();

  Widget buildBody(BuildContext ctx, void Function(void Function()) setLocal) {
    void addName(String raw) {
      final name = raw.trim();
      if (name.isEmpty) return;
      setLocal(() {
        selected.add(name);
        controller.clear();
      });
    }

    final suggestionNames = suggestions
        .map((t) => t.name)
        .where((n) => !selected.contains(n))
        .toList();

    final recentVisible = recentTagNames
        .where((n) => n.trim().isNotEmpty && !selected.contains(n))
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final name in selected)
              InputChip(
                label: Text(name),
                onDeleted: () => setLocal(() => selected.remove(name)),
              ),
            if (selected.isEmpty)
              Text(
                '暂无标签',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.outline,
                    ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '输入新标签后回车',
            prefixIcon: Icon(Icons.label_outline),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: addName,
        ),
        if (recentVisible.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('最近', style: Theme.of(ctx).textTheme.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in recentVisible)
                ActionChip(
                  avatar: const Icon(Icons.history, size: 16),
                  label: Text(name),
                  onPressed: () => addName(name),
                ),
            ],
          ),
        ],
        if (suggestionNames.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('已有标签', style: Theme.of(ctx).textTheme.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in suggestionNames)
                ActionChip(
                  label: Text(name),
                  onPressed: () => addName(name),
                ),
            ],
          ),
        ],
      ],
    );
  }

  List<String>? result;
  if (asBottomSheet) {
    result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              return SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(title, style: Theme.of(ctx).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    Flexible(
                      child: SingleChildScrollView(
                        child: buildBody(ctx, setLocal),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (allowSkip)
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(<String>[]),
                            child: const Text('稍后'),
                          )
                        else
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('取消'),
                          ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () =>
                              Navigator.of(ctx).pop(selected.toList()),
                          child: Text(confirmLabel),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  } else {
    result = await showDialog<List<String>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: buildBody(ctx, setLocal),
                ),
              ),
              actions: [
                if (allowSkip)
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(<String>[]),
                    child: const Text('稍后'),
                  )
                else
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('取消'),
                  ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(selected.toList()),
                  child: Text(confirmLabel),
                ),
              ],
            );
          },
        );
      },
    );
  }

  controller.dispose();
  return result;
}

/// Back-compat alias used by existing call sites.
Future<List<String>?> showTagsEditorDialog(
  BuildContext context, {
  required List<Tag> initialTags,
  required List<Tag> suggestions,
  List<String> recentTagNames = const [],
  String title = '编辑标签',
  String confirmLabel = '保存',
  bool allowSkip = false,
}) {
  return showTagsEditorSheet(
    context,
    initialTags: initialTags,
    suggestions: suggestions,
    recentTagNames: recentTagNames,
    title: title,
    confirmLabel: confirmLabel,
    allowSkip: allowSkip,
    asBottomSheet: true,
  );
}
