import 'package:flutter/material.dart';

import '../../domain/models/tag.dart';

/// Edit tags for a sticker. Returns the final tag name list, or null if cancelled.
Future<List<String>?> showTagsEditorDialog(
  BuildContext context, {
  required List<Tag> initialTags,
  required List<Tag> suggestions,
  String title = '编辑标签',
}) async {
  final selected = <String>{
    for (final t in initialTags) t.name,
  };
  final controller = TextEditingController();

  final result = await showDialog<List<String>>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
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

          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
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
                    if (suggestionNames.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        '已有标签',
                        style: Theme.of(ctx).textTheme.labelMedium,
                      ),
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
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(selected.toList()),
                child: const Text('保存'),
              ),
            ],
          );
        },
      );
    },
  );
  controller.dispose();
  return result;
}
