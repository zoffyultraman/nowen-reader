import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../data/api/api_client.dart';
import '../../data/api/comic_api.dart';
import '../../data/models/comic.dart';
import '../../data/providers/auth_provider.dart';

/// 分组详情页面
class GroupDetailScreen extends ConsumerStatefulWidget {
  final int groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  Map<String, dynamic>? _detail;
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
      final data = await api.getGroupDetail(widget.groupId);
      setState(() {
        _detail = data;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
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

    if (_detail == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('加载失败')),
      );
    }

    final name = _detail!['name'] ?? '分组';
    final comics = (_detail!['comics'] as List<dynamic>?)
            ?.map((e) => Comic.fromJson(e))
            .toList() ??
        [];

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: comics.isEmpty
          ? const Center(child: Text('此分组暂无漫画'))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: comics.length,
              itemBuilder: (context, index) {
                final comic = comics[index];
                final thumbUrl =
                    getImageUrl(serverUrl, comic.id, thumbnail: true);

                return Card(
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 48,
                        height: 64,
                        child: CachedNetworkImage(
                          imageUrl: thumbUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: cs.surfaceContainerHighest,
                            child: const Icon(Icons.image, size: 20),
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      comic.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${comic.pageCount}页',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => context.push('/comic/${comic.id}'),
                  ),
                );
              },
            ),
    );
  }
}
