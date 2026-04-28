import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/api/api_client.dart';
import '../../widgets/authenticated_image.dart';
import '../../widgets/continue_reading.dart';
import '../../widgets/comic_list_tile.dart';
import '../../data/models/comic.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/comic_provider.dart';
import '../../widgets/animations.dart';

/// 首页 — 极简优雅的书库浏览
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentParams = ref.read(comicListProvider).params;
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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(comicListProvider.notifier).loadComics();
        },
        color: cs.primary,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // ─── 优雅的顶部区域 ───
            SliverAppBar(
              floating: true,
              snap: true,
              title: const Text('书库'),
              actions: [
                // 合集入口
                _ActionIcon(
                  icon: Icons.collections_bookmark_outlined,
                  tooltip: '合集',
                  onTap: () => context.push('/collections'),
                ),
                // 视图模式切换
                _ActionIcon(
                  icon: viewMode == ViewMode.grid
                      ? Icons.view_agenda_outlined
                      : Icons.grid_view_rounded,
                  tooltip: viewMode == ViewMode.grid ? '列表视图' : '网格视图',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(viewModeProvider.notifier).state =
                        viewMode == ViewMode.grid ? ViewMode.list : ViewMode.grid;
                  },
                ),
                // 排序
                PopupMenuButton<String>(
                  icon: const Icon(Icons.swap_vert_rounded),
                  tooltip: '排序',
                  position: PopupMenuPosition.under,
                  onSelected: (sort) {
                    final current = state.params;
                    String order = 'desc';
                    if (sort == 'title') order = 'asc';
                    ref.read(comicListProvider.notifier).updateParams(
                          current.copyWith(sort: sort, order: order, page: 1),
                        );
                  },
                  itemBuilder: (_) => [
                    _buildSortItem('addedAt', '最近添加', Icons.schedule_rounded, state.params.sort),
                    _buildSortItem('title', '标题', Icons.sort_by_alpha_rounded, state.params.sort),
                    _buildSortItem('lastReadAt', '最近阅读', Icons.auto_stories_outlined, state.params.sort),
                    _buildSortItem('rating', '评分', Icons.star_outline_rounded, state.params.sort),
                    _buildSortItem('pageCount', '页数', Icons.description_outlined, state.params.sort),
                  ],
                ),
                // 筛选
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.tune_rounded,
                    color: (state.params.type != null || (state.params.favoritesOnly == true))
                        ? cs.primary
                        : null,
                  ),
                  tooltip: '筛选',
                  position: PopupMenuPosition.under,
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
                    _buildFilterItem('all', '全部', Icons.apps_rounded, state.params),
                    _buildFilterItem('comic', '漫画', Icons.photo_library_outlined, state.params),
                    _buildFilterItem('novel', '小说', Icons.menu_book_outlined, state.params),
                    _buildFilterItem('favorites', '收藏', Icons.favorite_rounded, state.params),
                  ],
                ),
                const SizedBox(width: 4),
              ],
            ),

            // ─── 继续阅读 ───
            const SliverToBoxAdapter(
              child: ContinueReading(),
            ),

            // ─── 内容区域 ───
            if (state.comics.isEmpty && state.isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: _LoadingIndicator(),
                ),
              )
            else if (state.comics.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(),
              )
            else if (viewMode == ViewMode.grid)
              _buildGrid(context, state, authState)
            else
              _buildList(context, state, authState),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildSortItem(
      String value, String label, IconData icon, String? currentSort) {
    final isSelected = currentSort == value;
    final cs = Theme.of(context).colorScheme;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: isSelected ? cs.primary : cs.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? cs.primary : null,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            Icon(Icons.check_rounded, size: 18, color: cs.primary),
          ],
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildFilterItem(
      String value, String label, IconData icon, ComicListParams params) {
    final isSelected = (value == 'all' && params.type == null && params.favoritesOnly != true) ||
        (value == 'favorites' && params.favoritesOnly == true) ||
        (value != 'all' && value != 'favorites' && params.type == value);
    final cs = Theme.of(context).colorScheme;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isSelected
                ? (value == 'favorites' ? Colors.redAccent : cs.primary)
                : cs.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? cs.primary : null,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            Icon(Icons.check_rounded, size: 18, color: cs.primary),
          ],
        ],
      ),
    );
  }

  Widget _buildGrid(
      BuildContext context, ComicListState state, AuthState authState) {
    final serverUrl = authState.serverUrl;
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 900
        ? 6
        : width > 600
            ? 4
            : width > 400
                ? 3
                : 2;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 0.62,
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index >= state.comics.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: _LoadingIndicator(),
                ),
              );
            }
            return StaggeredFadeSlide(
              index: index,
              child: _ComicCard(
                comic: state.comics[index],
                serverUrl: serverUrl,
                onTap: () => context.push('/comic/${state.comics[index].id}'),
                onFavoriteToggle: () => ref
                    .read(comicListProvider.notifier)
                    .toggleFavorite(state.comics[index].id),
              ),
            );
          },
          childCount: state.comics.length + (state.hasMore ? 1 : 0),
        ),
      ),
    );
  }

  Widget _buildList(
      BuildContext context, ComicListState state, AuthState authState) {
    final serverUrl = authState.serverUrl;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index >= state.comics.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: _LoadingIndicator(),
                ),
              );
            }
            return ComicListTile(
              comic: state.comics[index],
              serverUrl: serverUrl,
              onTap: () => context.push('/comic/${state.comics[index].id}'),
              onFavoriteToggle: () => ref
                  .read(comicListProvider.notifier)
                  .toggleFavorite(state.comics[index].id),
            );
          },
          childCount: state.comics.length + (state.hasMore ? 1 : 0),
        ),
      ),
    );
  }
}

/// 顶部操作图标按钮
class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onTap,
      style: IconButton.styleFrom(
        padding: const EdgeInsets.all(8),
      ),
    );
  }
}

/// 精致的加载指示器
class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
      ),
    );
  }
}

/// 空状态
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.library_books_outlined,
              size: 36,
              color: cs.primary.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '书库空空如也',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '添加一些漫画或小说开始阅读吧',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant.withOpacity(0.6),
                ),
          ),
        ],
      ),
    );
  }
}

/// 漫画卡片组件 — 精致的封面卡片
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

    return PressableScale(
      onTap: onTap,
      scaleDown: 0.95,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 封面图片
                    AuthenticatedImage(
                      imageUrl: thumbUrl,
                      fit: BoxFit.cover,
                      placeholder: Container(
                        color: cs.surfaceContainerHighest,
                        child: Center(
                          child: Icon(Icons.image_outlined,
                              size: 28, color: cs.onSurfaceVariant.withOpacity(0.3)),
                        ),
                      ),
                      errorWidget: Container(
                        color: cs.surfaceContainerHighest,
                        child: Center(
                          child: Icon(Icons.broken_image_outlined,
                              size: 28, color: cs.onSurfaceVariant.withOpacity(0.3)),
                        ),
                      ),
                    ),

                    // 底部渐变
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 60,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black54, Colors.transparent],
                          ),
                        ),
                      ),
                    ),

                    // 阅读进度条
                    if (comic.progress > 0)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.black26,
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: comic.progress / 100,
                            child: Container(
                              decoration: BoxDecoration(
                                color: cs.primary,
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // 收藏图标
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onFavoriteToggle();
                        },
                        child: HeartBounce(
                          trigger: comic.isFavorite,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              comic.isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: comic.isFavorite
                                  ? const Color(0xFFFF6B6B)
                                  : Colors.white70,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 类型标识
                    if (comic.isNovel)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '小说',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // 标题
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
            child: Text(
              comic.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    height: 1.3,
                    color: cs.onSurface,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
