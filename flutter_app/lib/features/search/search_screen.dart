import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../data/api/api_client.dart';
import '../../data/models/comic.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/comic_provider.dart';

/// 搜索页面
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchCtrl = TextEditingController();
  List<Comic> _results = [];
  bool _searching = false;
  String? _selectedTag;
  String? _selectedCategory;

  // 标签和分类
  List<Tag> _tags = [];
  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFilters() async {
    final tagsAsync = ref.read(tagsProvider.future);
    final catsAsync = ref.read(categoriesProvider.future);
    try {
      final tags = await tagsAsync;
      final cats = await catsAsync;
      if (mounted) {
        setState(() {
          _tags = tags;
          _categories = cats;
        });
      }
    } catch (_) {}
  }

  Future<void> _search() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty && _selectedTag == null && _selectedCategory == null) return;

    setState(() => _searching = true);
    try {
      final notifier = ref.read(comicListProvider.notifier);
      await notifier.loadComics(
        params: ComicListParams(
          search: query.isNotEmpty ? query : null,
          tag: _selectedTag,
          category: _selectedCategory,
        ),
      );
      final state = ref.read(comicListProvider);
      setState(() {
        _results = state.comics;
        _searching = false;
      });
    } catch (_) {
      setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final serverUrl = ref.watch(authProvider).serverUrl;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('搜索')),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: '搜索漫画、小说...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onSubmitted: (_) => _search(),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // 标签筛选（横向滚动）
          if (_tags.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _tags.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final tag = _tags[i];
                  final selected = _selectedTag == tag.name;
                  return FilterChip(
                    label: Text(tag.name, style: const TextStyle(fontSize: 12)),
                    selected: selected,
                    onSelected: (v) {
                      setState(() => _selectedTag = v ? tag.name : null);
                      _search();
                    },
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
            ),

          // 分类筛选
          if (_categories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final cat = _categories[i];
                    final selected = _selectedCategory == cat.slug;
                    return FilterChip(
                      label: Text(cat.name, style: const TextStyle(fontSize: 12)),
                      selected: selected,
                      onSelected: (v) {
                        setState(() => _selectedCategory = v ? cat.slug : null);
                        _search();
                      },
                      visualDensity: VisualDensity.compact,
                    );
                  },
                ),
              ),
            ),

          const SizedBox(height: 8),

          // 搜索按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              onPressed: _searching ? null : _search,
              icon: _searching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search),
              label: const Text('搜索'),
            ),
          ),
          const SizedBox(height: 8),

          // 搜索结果
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      '输入关键词或选择标签搜索',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final comic = _results[index];
                      return _SearchResultItem(
                        comic: comic,
                        serverUrl: serverUrl,
                        onTap: () => context.push('/comic/${comic.id}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultItem extends StatelessWidget {
  final Comic comic;
  final String serverUrl;
  final VoidCallback onTap;

  const _SearchResultItem({
    required this.comic,
    required this.serverUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final thumbUrl = getImageUrl(serverUrl, comic.id, thumbnail: true);
    final cs = Theme.of(context).colorScheme;

    return ListTile(
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
      title: Text(comic.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          if (comic.author != null && comic.author!.isNotEmpty) comic.author!,
          '${comic.pageCount}页',
          if (comic.isNovel) '小说',
        ].join(' · '),
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
      ),
      trailing: comic.isFavorite
          ? const Icon(Icons.favorite, color: Colors.red, size: 18)
          : null,
      onTap: onTap,
    );
  }
}
