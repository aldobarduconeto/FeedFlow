import 'package:flutter/material.dart';
import 'package:feedflow/src/services/feed_service.dart';

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
      SnackBar(content: Text('Fonte RSS adicionada e sincronizada.')),
    );
  }
}

class _AddFeedDialog extends StatefulWidget {
  _AddFeedDialog({required this.feedService});

  final FeedService feedService;

  @override
  State<_AddFeedDialog> createState() => _AddFeedDialogState();
}

class _AddFeedDialogState extends State<_AddFeedDialog> {
  final _urlController = TextEditingController();
  String _category = 'Personalizados';
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _addFeed() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.feedService.addFeed(
        _urlController.text,
        category: _category,
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
    return AlertDialog(
      title: Text('Adicionar fonte'),
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
              decoration: InputDecoration(
                labelText: 'URL do site, canal YouTube ou feed',
                hintText: 'https://exemplo.com/feed.xml',
              ),
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(labelText: 'Categoria'),
              items:
                  [
                    'Personalizados',
                    'Notícias',
                    'Tecnologia',
                    'Ciência',
                    'Podcasts',
                  ].map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) setState(() => _category = value);
                    },
            ),
            if (_error != null) ...[
              SizedBox(height: 12),
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
          child: Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _addFeed,
          child: _saving
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('Adicionar'),
        ),
      ],
    );
  }
}
