import 'package:flutter/material.dart';

import '../../models/feed_source.dart';
import '../../models/suggested_feed.dart';
import '../../services/feed_service.dart';
import 'colors.dart';

Future<void> showAddFeedDialog(
  BuildContext context,
  FeedService feedService,
) async {
  final added = await showDialog<bool>(
    context: context,
    builder: (_) => _AddFeedDialog(feedService: feedService),
  );
  if (added == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fonte RSS adicionada e sincronizada.')),
    );
  }
}

Future<void> showEditCategoryDialog(
  BuildContext context,
  FeedSource source,
  FeedService feedService,
) async {
  final updated = await showDialog<bool>(
    context: context,
    builder: (_) => _EditCategoryDialog(
      source: source,
      feedService: feedService,
    ),
  );
  if (updated == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Categoria de "${source.title}" atualizada.')),
    );
  }
}

class _AddFeedDialog extends StatefulWidget {
  const _AddFeedDialog({required this.feedService});

  final FeedService feedService;

  @override
  State<_AddFeedDialog> createState() => _AddFeedDialogState();
}

class _AddFeedDialogState extends State<_AddFeedDialog> {
  final _urlController = TextEditingController();
  final _customCategoryController = TextEditingController();
  String _category = 'Notícias';
  bool _isCustom = false;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _urlController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  Future<void> _addFeed() async {
    final finalCategory = _isCustom
        ? _customCategoryController.text.trim().isNotEmpty
            ? _customCategoryController.text.trim()
            : 'Personalizados'
        : _category;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.feedService.addFeed(
        _urlController.text,
        category: finalCategory,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('FormatException: ', '');
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = FeedCategories.defaultCategories;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: FeedFlowColors.divider.withValues(alpha: 0.7),
          width: 0.8,
        ),
      ),
      backgroundColor: FeedFlowColors.surfaceElevated,
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: FeedFlowColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.add_link_rounded,
              color: FeedFlowColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Adicionar fonte',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: FeedFlowColors.textPrimary,
                  ),
                ),
                Text(
                  'Insira o link RSS, Atom ou YouTube',
                  style: TextStyle(
                    fontSize: 12,
                    color: FeedFlowColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _urlController,
              autofocus: true,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onSubmitted: _saving ? null : (_) => _addFeed(),
              decoration: const InputDecoration(
                labelText: 'URL da fonte ou feed',
                hintText: 'https://exemplo.com/feed.xml',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _isCustom ? 'Nova categoria...' : _category,
              decoration: const InputDecoration(labelText: 'Categoria'),
              borderRadius: BorderRadius.circular(16),
              dropdownColor: FeedFlowColors.surfaceElevated,
              items: [
                ...categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }),
                const DropdownMenuItem(
                  value: 'Nova categoria...',
                  child: Text('+ Criar nova categoria...'),
                ),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          if (value == 'Nova categoria...') {
                            _isCustom = true;
                          } else {
                            _isCustom = false;
                            _category = value;
                          }
                        });
                      }
                    },
            ),
            if (_isCustom) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customCategoryController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nome da nova categoria',
                  hintText: 'Ex: Inteligência Artificial, Games...',
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: FeedFlowColors.textSecondary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _addFeed,
          style: FilledButton.styleFrom(
            backgroundColor: FeedFlowColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Adicionar'),
        ),
      ],
    );
  }
}

class _EditCategoryDialog extends StatefulWidget {
  final FeedSource source;
  final FeedService feedService;

  const _EditCategoryDialog({
    required this.source,
    required this.feedService,
  });

  @override
  State<_EditCategoryDialog> createState() => _EditCategoryDialogState();
}

class _EditCategoryDialogState extends State<_EditCategoryDialog> {
  late String _selectedCategory;
  final _customCategoryController = TextEditingController();
  bool _isCustom = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final categories = FeedCategories.defaultCategories;
    if (categories.contains(widget.source.category)) {
      _selectedCategory = widget.source.category;
    } else {
      _selectedCategory = 'Nova categoria...';
      _isCustom = true;
      _customCategoryController.text = widget.source.category;
    }
  }

  @override
  void dispose() {
    _customCategoryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final finalCategory = _isCustom
        ? _customCategoryController.text.trim().isNotEmpty
            ? _customCategoryController.text.trim()
            : 'Personalizados'
        : _selectedCategory;

    setState(() => _saving = true);
    await widget.feedService.updateSourceCategory(
      widget.source.id,
      finalCategory,
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final categories = FeedCategories.defaultCategories;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: FeedFlowColors.divider.withValues(alpha: 0.7),
          width: 0.8,
        ),
      ),
      backgroundColor: FeedFlowColors.surfaceElevated,
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: FeedFlowColors.secondary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.label_outline_rounded,
              color: FeedFlowColors.secondary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Categorizar fonte',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: FeedFlowColors.textPrimary,
                  ),
                ),
                Text(
                  widget.source.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: FeedFlowColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _isCustom ? 'Nova categoria...' : _selectedCategory,
              decoration: const InputDecoration(labelText: 'Selecione a categoria'),
              borderRadius: BorderRadius.circular(16),
              dropdownColor: FeedFlowColors.surfaceElevated,
              items: [
                ...categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }),
                const DropdownMenuItem(
                  value: 'Nova categoria...',
                  child: Text('+ Criar nova categoria...'),
                ),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          if (value == 'Nova categoria...') {
                            _isCustom = true;
                          } else {
                            _isCustom = false;
                            _selectedCategory = value;
                          }
                        });
                      }
                    },
            ),
            if (_isCustom) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customCategoryController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nome da categoria personalizada',
                  hintText: 'Ex: Estudos, Finanças, Espaço...',
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: FeedFlowColors.textSecondary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: FeedFlowColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
