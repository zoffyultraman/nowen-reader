import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/api/api_client.dart';
import '../data/api/comic_api.dart';
import '../data/models/comic.dart';
import '../data/providers/auth_provider.dart';
import 'authenticated_image.dart';

/// 继续阅读横条 — 显示最近阅读的漫画，带阅读进度
/// 类似 Netflix "继续观看" 的体验
class ContinueReading extends ConsumerStatefulWidget {
  const ContinueReading({super.key});

  @override
  ConsumerState<ContinueReading> createState() => _ContinueReadingState();
}

class _ContinueReadingState extends ConsumerState<ContinueReading> {
  List<Comic> _recentComics = [];
  bool _loading = true;
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    _fetchRecent();
  }

  Future<void> _fetchRecent() async {
    try {
      final api = ref.read(comicApiProvider);
      final data = await api.listComics(
        page: 1,
        limit: 10,
        sort: 'lastReadAt',
        order: 'desc',
      );
      final comics = ((data['comics'] as List<dynamic>?) ?? [])
          .map((e) => Comic.fromJson(e))
          .where((c) =>
              c.lastReadAt != null &&
              c.lastReadAt!.isNotEmpty &&
              c.lastReadPage > 0 &&
              (c.pageCount == 0 || c.lastReadPage < c.pageCount - 1))
          .take(8)
          .toList();
      if (mounted) {
        setState(() {
          _recentComics = comics;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 刷新阅读记录（外部可调用）
  Future<void> refresh() => _fetchRecent();

  String _formatTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 1) return '刚刚';
      if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
      if (diff.inHours < 24) return '${diff.inHours}小时前';
      if (diff.inDays < 7) return '${diff.inDays}天前';
      return '${date.month}/${date.day}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _recentComics.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final serverUrl = ref.watch(authProvider).serverUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题栏 — 可点击折叠
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: GestureDetector(
            onTap: () => setState(() => _collapsed = !_collapsed),
            child: Row(
              children: [
                Icon(Icons.auto_stories, size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  '继续阅读',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '(${_recentComics.length})',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                const SizedBox(width: 4),
                Icon(
                  _collapsed
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_up,
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),

        // 横向滚动列表
        AnimatedCrossFade(
          firstChild: SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _recentComics.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final comic = _recentComics[index];
                final progress = comic.pageCount > 0
                    ? (comic.lastReadPage / comic.pageCount * 100).round()
                    : 0;
                final thumbUrl =
                    getImageUrl(serverUrl, comic.id, thumbnail: true);

                return GestureDetector(
                  onTap: () {
                    context.push(
                      '/reader/${comic.id}?page=${comic.lastReadPage}',
                    );
                  },
                  child: SizedBox(
                    width: 120,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 封面 + 进度覆盖层
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                AuthenticatedImage(
                                  imageUrl: thumbUrl,
                                  fit: BoxFit.cover,
                                  placeholder: Container(
                                    color: cs.surfaceContainerHighest,
                                    child: const Center(
                                      child: Icon(Icons.image_outlined,
                                          size: 24),
                                    ),
                                  ),
                                  errorWidget: Container(
                                    color: cs.surfaceContainerHighest,
                                  ),
                                ),
                                // 底部渐变 + 进度
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(
                                        6, 20, 6, 6),
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          Colors.black87,
                                          Colors.transparent
                                        ],
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        // 进度文字
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${comic.lastReadPage + 1}/${comic.pageCount}页',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 9,
                                              ),
                                            ),
                                            Text(
                                              '$progress%',
                                              style: TextStyle(
                                                color: cs.primary,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        // 进度条
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(2),
                                          child: LinearProgressIndicator(
                                            value: progress / 100,
                                            minHeight: 3,
                                            backgroundColor:
                                                Colors.white.withAlpha(51),
                                            valueColor:
                                                AlwaysStoppedAnimation(
                                                    cs.primary),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // 标题
                        Text(
                          comic.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface.withAlpha(204),
                          ),
                        ),
                        const SizedBox(height: 2),
                        // 阅读时间
                        Row(
                          children: [
                            Icon(Icons.access_time,
                                size: 10, color: cs.onSurfaceVariant),
                            const SizedBox(width: 3),
                            Text(
                              _formatTime(comic.lastReadAt!),
                              style: TextStyle(
                                fontSize: 10,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          secondChild: const SizedBox.shrink(),
          crossFadeState: _collapsed
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }
}
