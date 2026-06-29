import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/models/comic.dart';
import '../data/api/api_client.dart';

/// 合集卡片组件 — 在首页与漫画卡片混合展示
class GroupCard extends ConsumerWidget {
  final ComicGroup group;
  final bool isGrid;

  const GroupCard({
    super.key,
    required this.group,
    this.isGrid = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final serverUrl = ref.watch(serverUrlProvider);

    if (isGrid) {
      return _buildGridCard(context, cs, serverUrl);
    }
    return _buildListCard(context, cs, serverUrl);
  }

  Widget _buildGridCard(BuildContext context, ColorScheme cs, String serverUrl) {
    return GestureDetector(
      onTap: () => context.push('/group/${group.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面区域
            AspectRatio(
              aspectRatio: 3 / 4,
              child: _buildCover(cs, serverUrl),
            ),
            // 信息区域
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${group.comicCount} 本',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListCard(BuildContext context, ColorScheme cs, String serverUrl) {
    return GestureDetector(
      onTap: () => context.push('/group/${group.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // 封面
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 72,
                child: _buildCover(cs, serverUrl),
              ),
            ),
            const SizedBox(width: 12),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${group.comicCount} 本',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  if (group.author.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      group.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant.withOpacity(0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // 箭头
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: cs.onSurfaceVariant.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(ColorScheme cs, String serverUrl) {
    // 尝试加载合集封面
    if (group.coverUrl.isNotEmpty) {
      return Image.network(
        '$serverUrl${group.coverUrl}',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(cs),
      );
    }
    return _buildPlaceholder(cs);
  }

  Widget _buildPlaceholder(ColorScheme cs) {
    return Container(
      color: cs.primaryContainer.withOpacity(0.3),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.collections_bookmark_outlined,
              size: 32,
              color: cs.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 4),
            Text(
              '${group.comicCount}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.primary.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
