import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/api/api_client.dart';
import '../../widgets/authenticated_image.dart';
import '../../widgets/continue_reading.dart';
import '../../widgets/comic_list_tile.dart';
import '../../data/models/comic.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/comic_provider.dart';

/// 首页 - 漫画列表
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // 首次加载 - 使用默认参数，确保首页始终显示默认状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentParams = ref.read(comicListProvider).params;
      // 如果当前参数中包含搜索条件，则重置为默认参数重新加载
      if (currentParams.search != null ||
          currentParams.tag != null ||
          currentParams.category != null) {
        ref.read(comicListProvider.notifier).loadComics(
              params: ComicListParams(
                sort: currentParams.sort,
                order: currentParams.order,
                type: currentParams.type,
                favoritesOnly: currentParams.favoritesOnly,
              ),
            );
      } else {
        ref.read(comicListProvider.notifier).loadComics();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(comicListProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(comicListProvider);
    final authState = ref.watch(authProvider);
    final viewMode = ref.watch(viewModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('NowenReader'),
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
          // 排序按钮
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: '排序',
            onSelected: (sort) {
              final current = state.params;
              String order = 'desc';
              if (sort == 'title') order = 'asc';
              ref.read(comicListProvider.notifier).updateParams(
                    current.copyWith(sort: sort, order: order, page: 1),
                  );
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'addedAt', child: Text('添加时间')),
              const PopupMenuItem(value: 'title', child: Text('标题')),
              const PopupMenuItem(value: 'lastReadAt', child: Text('最近阅读')),
              const PopupMenuItem(value: 'rating', child: Text('评分')),
              const PopupMenuItem(value: 'pageCount', child: Text('页数')),
            ],
          ),
          // 筛选类型
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: '筛选',
            onSelected: (filter) {
              final current = state.params;
              if (filter == 'all') {
                ref.read(comicListProvider.notifier).updateParams(
                      current.copyWith(
                        clearType: true,
                        favoritesOnly: false,
                        page: 1,
                      ),
                    );
              } else if (filter == 'favorites') {
                ref.read(comicListProvider.notifier).updateParams(
                      current.copyWith(favoritesOnly: true, page: 1),
                    );
              } else {
                ref.read(comicListProvider.notifier).updateParams(
                      current.copyWith(type: filter, favoritesOnly: false, page: 1),
                    );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'all', child: Text('全部')),
              const PopupMenuItem(value: 'comic', child: Text('漫画')),
              const PopupMenuItem(value: 'novel', child: Text('小说')),
              const PopupMenuItem(value: 'favorites', child: Text('⭐ 收藏')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(comicListProvider.notifier).loadComics();
        },
        child: state.comics.isEmpty && state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.comics.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.library_books_outlined,
                            size: 64,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text('暂无内容',
                            style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                  )
                : _buildContent(context, state, authState),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, ComicListState state, AuthState authState) {
    final serverUrl = authState.serverUrl;
    final viewMode = ref.watch(viewModeProvider);

    // 根据屏幕宽度决定列数
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 900
        ? 6
        : width > 600
            ? 4
            : width > 400
                ? 3
                : 2;

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // 继续阅读横条
        const SliverToBoxAdapter(
          child: ContinueReading(),
        ),
        // 根据视图模式切换网格/列表
        if (viewMode == ViewMode.grid)
          SliverPadding(
            padding: const EdgeInsets.all(8),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 0.65,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index >= state.comics.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  return _ComicCard(
                    comic: state.comics[index],
                    serverUrl: serverUrl,
                    onTap: () =>
                        context.push('/comic/${state.comics[index].id}'),
                    onFavoriteToggle: () => ref
                        .read(comicListProvider.notifier)
                        .toggleFavorite(state.comics[index].id),
                  );
                },
                childCount: state.comics.length + (state.hasMore ? 1 : 0),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index >= state.comics.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  return ComicListTile(
                    comic: state.comics[index],
                    serverUrl: serverUrl,
                    onTap: () =>
                        context.push('/comic/${state.comics[index].id}'),
                    onFavoriteToggle: () => ref
                        .read(comicListProvider.notifier)
                        .toggleFavorite(state.comics[index].id),
                  );
                },
                childCount: state.comics.length + (state.hasMore ? 1 : 0),
              ),
            ),
          ),
      ],
    );
  }
}

/// 漫画卡片组件
class _ComicCard extends StatelessWidget {
  final Comic comic;
  final String serverUrl;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;

  const _ComicCard({
    required this.comic,
    required this.serverUrl,
    required this.onTap,
    required this.onFavoriteToggle,
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
            // 封面
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
                        valueColor:
                            AlwaysStoppedAnimation(cs.primary),
                      ),
                    ),
                  // 收藏图标
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: onFavoriteToggle,
                      child: Icon(
                        comic.isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: comic.isFavorite ? Colors.red : Colors.white70,
                        size: 20,
                        shadows: const [
                          Shadow(blurRadius: 4, color: Colors.black54),
                        ],
                      ),
                    ),
                  ),
                  // 类型标识
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
            // 标题
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
