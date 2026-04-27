import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/api/api_client.dart';
import '../../widgets/authenticated_image.dart';
import '../../widgets/comic_list_tile.dart';
import '../../data/models/comic.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/comic_provider.dart';
import '../../data/api/comic_api.dart';

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
      // 直接调用 API，不污染首页的 comicListProvider 状态
      final api = ref.read(comicApiProvider);
      final data = await api.listComics(
        search: query.isNotEmpty ? query : null,
        tag: _selectedTag,
        category: _selectedCategory,
      );
      final list = (data['comics'] as List<dynamic>?)
              ?.map((e) => Comic.fromJson(e))
              .toList() ??
          [];
      setState(() {
        _results = list;
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
    final viewMode = ref.watch(viewModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索'),
        actions: [
          // 视图模式切换按钮
          IconButton(
            icon: Icon(
              viewMode == ViewMode.grid ? Icons.view_list : Icons.grid_view,
            ),
            tooltip: viewMode == ViewMode.grid ? '切换列表模式' : '切换网格模式',
            onPressed: () {
              ref.read(viewModeProvider.notifier).state =
                  viewMode == ViewMode.grid ? ViewMode.list : ViewMode.grid;
            },
          ),
        ],
      ),
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
                : viewMode == ViewMode.list
                    ? ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final comic = _results[index];
                          return ComicListTile(
                            comic: comic,
                            serverUrl: serverUrl,
                            onTap: () => context.push('/comic/${comic.id}'),
                          );
                        },
                      )
                    : _buildSearchGrid(context, serverUrl),
          ),
        ],
      ),
    );
  }

  /// 搜索结果网格视图
  Widget _buildSearchGrid(BuildContext context, String serverUrl) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 900
        ? 6
        : width > 600
            ? 4
            : width > 400
                ? 3
                : 2;

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.65,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final comic = _results[index];
        return _SearchGridCard(
          comic: comic,
          serverUrl: serverUrl,
          onTap: () => context.push('/comic/${comic.id}'),
        );
      },
    );
  }
}

/// 搜索结果网格卡片
class _SearchGridCard extends StatelessWidget {
  final Comic comic;
  final String serverUrl;
  final VoidCallback onTap;

  const _SearchGridCard({
    required this.comic,
    required this.serverUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final thumbUrl = getImageUrl(serverUrl, comic.id, thumbnail: true);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AuthenticatedImage(
                    imageUrl: thumbUrl,
                    fit: BoxFit.cover,
                    placeholder: Container(
                      color: cs.surfaceContainerHighest,
                      child: const Center(
                        child: Icon(Icons.image_outlined, size: 32),
                      ),
                    ),
                    errorWidget: Container(
                      color: cs.surfaceContainerHighest,
                      child: Center(
                        child: Icon(Icons.broken_image_outlined,
                            size: 32, color: cs.onSurfaceVariant),
                      ),
                    ),
                  ),
                  if (comic.isFavorite)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Icon(
                        Icons.favorite,
                        color: Colors.red,
                        size: 18,
                        shadows: const [
                          Shadow(blurRadius: 4, color: Colors.black54),
                        ],
                      ),
                    ),
                  if (comic.isNovel)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.tertiary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '小说',
                          style: TextStyle(
                            color: cs.onTertiary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Text(
                comic.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

