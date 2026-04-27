import 'package:flutter/material.dart';
import '../data/api/api_client.dart';
import '../data/models/comic.dart';
import 'authenticated_image.dart';

/// 漫画列表项组件（列表模式下使用）
class ComicListTile extends StatelessWidget {
  final Comic comic;
  final String serverUrl;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteToggle;

  const ComicListTile({
    super.key,
    required this.comic,
    required this.serverUrl,
    required this.onTap,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final thumbUrl = getImageUrl(serverUrl, comic.id, thumbnail: true);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              // 封面缩略图
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 80,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AuthenticatedImage(
                        imageUrl: thumbUrl,
                        fit: BoxFit.cover,
                        placeholder: Container(
                          color: cs.surfaceContainerHighest,
                          child: const Icon(Icons.image_outlined, size: 24),
                        ),
                        errorWidget: Container(
                          color: cs.surfaceContainerHighest,
                          child: const Icon(Icons.broken_image_outlined, size: 24),
                        ),
                      ),
                      // 阅读进度条
                      if (comic.progress > 0)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: LinearProgressIndicator(
                            value: comic.progress / 100,
                            minHeight: 3,
                            backgroundColor: Colors.black38,
                            valueColor: AlwaysStoppedAnimation(cs.primary),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 信息区域
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 标题行（含类型标签）
                    Row(
                      children: [
                        if (comic.isNovel)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: cs.tertiaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '小说',
                              style: TextStyle(
                                color: cs.onTertiaryContainer,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            comic.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    // 作者
                    if (comic.author.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        comic.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    // 进度、评分、页数
                    Row(
                      children: [
                        if (comic.progress > 0) ...[
                          Text(
                            '${comic.progress}%',
                            style: TextStyle(
                              color: cs.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          '${comic.pageCount}页',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                        if (comic.rating != null && comic.rating! > 0) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.star, size: 13, color: Colors.amber),
                          Text(
                            ' ${comic.rating!.toStringAsFixed(1)}',
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // 收藏按钮
              if (onFavoriteToggle != null)
                GestureDetector(
                  onTap: onFavoriteToggle,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      comic.isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: comic.isFavorite ? Colors.red : cs.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
