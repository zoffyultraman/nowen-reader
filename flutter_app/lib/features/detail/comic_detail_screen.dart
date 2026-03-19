import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/api/api_client.dart';
import '../../widgets/authenticated_image.dart';
import '../../data/api/comic_api.dart';
import '../../data/models/comic.dart';
import '../../data/providers/auth_provider.dart';
import '../reader/novel_reader_screen.dart';

/// 漫画详情页
class ComicDetailScreen extends ConsumerStatefulWidget {
  final String comicId;
  const ComicDetailScreen({super.key, required this.comicId});

  @override
  ConsumerState<ComicDetailScreen> createState() => _ComicDetailScreenState();
}

class _ComicDetailScreenState extends ConsumerState<ComicDetailScreen> {
  Comic? _comic;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(comicApiProvider);
      final data = await api.getComic(widget.comicId);
      setState(() {
        _comic = Comic.fromJson(data);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_comic == null) return;
    try {
      final api = ref.read(comicApiProvider);
      final data = await api.toggleFavorite(widget.comicId);
      setState(() {
        _comic = _comic!.copyWith(isFavorite: data['isFavorite'] ?? false);
      });
    } catch (_) {}
  }

  Future<void> _updateRating(int rating) async {
    if (_comic == null) return;
    try {
      final api = ref.read(comicApiProvider);
      await api.updateRating(widget.comicId, rating);
      setState(() {
        _comic = _comic!.copyWith(rating: rating);
      });
    } catch (_) {}
  }

  Future<void> _setReadingStatus(String status) async {
    if (_comic == null) return;
    try {
      final api = ref.read(comicApiProvider);
      await api.setReadingStatus(widget.comicId, status);
      setState(() {
        _comic = _comic!.copyWith(readingStatus: status);
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final serverUrl = ref.watch(authProvider).serverUrl;
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final comic = _comic;
    if (comic == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('加载失败')),
      );
    }

    final thumbUrl = getImageUrl(serverUrl, comic.id, thumbnail: true);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 折叠式AppBar + 封面
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            actions: [
              IconButton(
                icon: Icon(
                  comic.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: comic.isFavorite ? Colors.red : null,
                ),
                onPressed: _toggleFavorite,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  AuthenticatedImage(
                    imageUrl: thumbUrl,
                    fit: BoxFit.cover,
                    errorWidget: Container(
                      color: cs.surfaceContainerHighest,
                    ),
                  ),
                  // 渐变遮罩
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                      ),
                    ),
                  ),
                  // 底部信息
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          comic.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (comic.author != null && comic.author!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              comic.author!,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 14),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 内容
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 操作按钮行
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          if (comic.isNovel) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => NovelReaderScreen(
                                  comicId: comic.id,
                                  initialChapter: comic.lastReadPage,
                                ),
                              ),
                            );
                          } else {
                            context.push(
                              '/reader/${comic.id}?page=${comic.lastReadPage}',
                            );
                          }
                        },
                        icon: Icon(comic.isNovel ? Icons.menu_book : Icons.auto_stories),
                        label: Text(comic.lastReadPage > 0
                            ? '继续阅读 (${comic.lastReadPage + 1}/${comic.pageCount})'
                            : '开始阅读'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 评分
                Row(
                  children: [
                    const Text('评分：'),
                    ...List.generate(5, (i) {
                      return IconButton(
                        icon: Icon(
                          i < (comic.rating ?? 0)
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                        ),
                        onPressed: () => _updateRating(i + 1),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 36, minHeight: 36),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 8),

                // 阅读状态
                Wrap(
                  spacing: 8,
                  children: [
                    _StatusChip('想读', 'want', comic.readingStatus, _setReadingStatus),
                    _StatusChip('在读', 'reading', comic.readingStatus, _setReadingStatus),
                    _StatusChip('读完', 'finished', comic.readingStatus, _setReadingStatus),
                    _StatusChip('搁置', 'shelved', comic.readingStatus, _setReadingStatus),
                  ],
                ),
                const SizedBox(height: 16),

                // 元数据信息
                _buildInfoSection(context, comic),
                const SizedBox(height: 12),

                // 元数据刮削入口
                OutlinedButton.icon(
                  onPressed: () {
                    context.push('/metadata/${comic.id}').then((_) {
                      _loadDetail(); // 返回后刷新
                    });
                  },
                  icon: const Icon(Icons.auto_fix_high, size: 18),
                  label: Text(
                    comic.metadataSource != null && comic.metadataSource!.isNotEmpty
                        ? '重新刮削元数据'
                        : '刮削元数据',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 42),
                  ),
                ),

                // 标签
                if (comic.tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('标签', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: comic.tags.map((t) {
                      return Chip(
                        label: Text(t.name, style: const TextStyle(fontSize: 12)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                ],

                // 简介
                if (comic.description != null && comic.description!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('简介', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text(
                    comic.description!,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context, Comic comic) {
    final items = <MapEntry<String, String>>[];
    items.add(MapEntry('页数', '${comic.pageCount}'));
    if (comic.fileSize > 0) {
      final mb = (comic.fileSize / 1024 / 1024).toStringAsFixed(1);
      items.add(MapEntry('文件大小', '${mb}MB'));
    }
    if (comic.publisher != null && comic.publisher!.isNotEmpty) {
      items.add(MapEntry('出版社', comic.publisher!));
    }
    if (comic.year != null) {
      items.add(MapEntry('年份', '${comic.year}'));
    }
    if (comic.language != null && comic.language!.isNotEmpty) {
      items.add(MapEntry('语言', comic.language!));
    }
    if (comic.totalReadTime > 0) {
      final hours = comic.totalReadTime ~/ 3600;
      final mins = (comic.totalReadTime % 3600) ~/ 60;
      items.add(MapEntry('阅读时间', hours > 0 ? '${hours}h ${mins}m' : '${mins}m'));
    }

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: items.map((e) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.key,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            Text(e.value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        );
      }).toList(),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final String value;
  final String? current;
  final Function(String) onTap;

  const _StatusChip(this.label, this.value, this.current, this.onTap);

  @override
  Widget build(BuildContext context) {
    final isSelected = current == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(isSelected ? '' : value),
    );
  }
}
