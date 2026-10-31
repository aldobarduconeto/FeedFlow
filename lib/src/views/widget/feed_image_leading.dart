import 'package:flutter/material.dart';

import '../../models/feed.dart';
import 'colors.dart';

class FeedImageLeading extends StatelessWidget {
  FeedImageLeading({required this.item, super.key});

  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrl;
    final icon = item.isPodcast
        ? Icons.podcasts_rounded
        : Icons.article_outlined;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 56,
        height: 56,
        child: imageUrl == null || imageUrl.isEmpty
            ? _placeholder(icon)
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                semanticLabel: 'Imagem de ${item.title}',
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return _placeholder(icon);
                },
                errorBuilder: (context, error, stackTrace) =>
                    _placeholder(icon),
              ),
      ),
    );
  }

  Widget _placeholder(IconData icon) {
    return ColoredBox(
      color: FeedFlowColors.surfaceElevated,
      child: Icon(icon, color: FeedFlowColors.secondary),
    );
  }
}
