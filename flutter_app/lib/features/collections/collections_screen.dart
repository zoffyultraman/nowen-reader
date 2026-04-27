import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/api/comic_api.dart';
import '../../data/models/comic.dart';
import '../../data/providers/auth_provider.dart';
import '../../widgets/authenticated_image.dart';

/// 排序字段
enum CollectionSortField { name, comicCount, updatedAt, createdAt }

/// 合集管理页面
class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key});

  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends ConsumerState<CollectionsScreen> {
  List<ComicGroup> _groups = [];
  bool _loading = true;
  bool _isGridView = true;
  String _searchQuery = '';
  String _contentFilter = ''; // "" = 全部, "comic", "novel"
  CollectionSortField _sortField = CollectionSortField.name;
  bool _sortAsc = true;

  // 创建对话框
  final _createController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  @override
  void dispose() {
    _createController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(comicApiProvider);
      final data = await api.getGroups(contentType: _contentFilter.isEmpty ? null : _contentFilter);
      setState(() {
        _groups = data.map((e) => ComicGroup.fromJson(e)).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  /// 过滤 + 排序后的列表
  List<ComicGroup> get _filteredAndSorted {
    var result = List<ComicGroup>.from(_groups);

    // 搜索过滤
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((g) => g.name.toLowerCase().contains(q)).toList();
    }

    // 排序
    result.sort((a, b) {
      int cmp;
      switch (_sortField) {
        case CollectionSortField.name:
          cmp = a.name.compareTo(b.name);
        case CollectionSortField.comicCount:
          cmp = a.comicCount.compareTo(b.comicCount);
        case CollectionSortField.updatedAt:
          cmp = a.updatedAt.compareTo(b.updatedAt);
        case CollectionSortField.createdAt:
          cmp = a.createdAt.compareTo(b.createdAt);
      }
      return _sortAsc ? cmp : -cmp;
    });

    return result;
  }

  /// 创建合集
  Future<void> _createCollection(String name) async {
    if (name.trim().isEmpty) return;
    try {
      final api = ref.read(comicApiProvider);
      await api.createGroup(name.trim());
      _createController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('合集已创建')),
        );
      }
      _loadGroups();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e')),
        );
      }
    }
  }

  /// 删除合集
  Future<void> _deleteCollection(int groupId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除合集「$name」吗？\n合集内的作品不会被删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final api = ref.read(comicApiProvider);
      await api.deleteGroup(groupId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('合集已删除')),
        );
      }
      _loadGroups();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  /// 显示创建对话框
  void _showCreateDialog() {
    _createController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建合集'),
        content: TextField(
          controller: _createController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入合集名称...',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (val) {
            Navigator.pop(ctx);
            _createCollection(val);
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _createCollection(_createController.text);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  /// 显示排序选项
  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('排序方式', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            _buildSortOption('按名称', CollectionSortField.name),
            _buildSortOption('按作品数', CollectionSortField.comicCount),
            _buildSortOption('按更新时间', CollectionSortField.updatedAt),
            _buildSortOption('按创建时间', CollectionSortField.createdAt),
            const Divider(),
            ListTile(
              leading: Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward),
              title: Text(_sortAsc ? '升序' : '降序'),
              onTap: () {
                setState(() => _sortAsc = !_sortAsc);
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String label, CollectionSortField field) {
    final isSelected = _sortField == field;
    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(label),
      onTap: () {
        setState(() => _sortField = field);
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final serverUrl = ref.watch(authProvider).serverUrl;
    final filtered = _filteredAndSorted;

    return Scaffold(
      appBar: AppBar(
        title: const Text('合集管理'),
        actions: [
          // 视图切换
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            tooltip: _isGridView ? '列表视图' : '网格视图',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          // 排序
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: '排序',
            onPressed: _showSortMenu,
          ),
          // 创建
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新建合集',
            onPressed: _showCreateDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏 + 内容类型筛选
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜索合集...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                isDense: true,
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // 内容类型筛选 Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('漫画', 'comic'),
                const SizedBox(width: 8),
                _buildFilterChip('小说', 'novel'),
                const Spacer(),
                // 合集数量
                Text(
                  '${filtered.length} 个合集',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 内容区域
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadGroups,
                        child: _isGridView
                            ? _buildGridView(filtered, serverUrl)
                            : _buildListView(filtered, serverUrl),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _contentFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _contentFilter = isSelected ? '' : value);
        _loadGroups();
      },
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.layers_outlined, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            '还没有合集',
            style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右上角 + 创建合集来整理你的书库',
            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }

  /// 网格视图
  Widget _buildGridView(List<ComicGroup> groups, String serverUrl) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: groups.length,
      itemBuilder: (context, index) => _buildGridItem(groups[index], serverUrl),
    );
  }

  Widget _buildGridItem(ComicGroup group, String serverUrl) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => context.push('/group/${group.id}'),
      onLongPress: () => _showGroupActions(group),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 封面
            Expanded(
              child: group.coverUrl.isNotEmpty
                  ? AuthenticatedImage(
                      imageUrl: group.coverUrl.startsWith('http')
                          ? group.coverUrl
                          : '$serverUrl${group.coverUrl}',
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: cs.surfaceContainerHighest,
                      child: Icon(Icons.layers, size: 48, color: cs.onSurfaceVariant.withOpacity(0.4)),
                    ),
            ),
            // 信息
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${group.comicCount} 部作品',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 列表视图
  Widget _buildListView(List<ComicGroup> groups, String serverUrl) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: groups.length,
      itemBuilder: (context, index) => _buildListItem(groups[index], serverUrl),
    );
  }

  Widget _buildListItem(ComicGroup group, String serverUrl) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 48,
          height: 48,
          child: group.coverUrl.isNotEmpty
              ? AuthenticatedImage(
                  imageUrl: group.coverUrl.startsWith('http')
                      ? group.coverUrl
                      : '$serverUrl${group.coverUrl}',
                  fit: BoxFit.cover,
                )
              : Container(
                  color: cs.surfaceContainerHighest,
                  child: Icon(Icons.layers, size: 24, color: cs.onSurfaceVariant.withOpacity(0.4)),
                ),
        ),
      ),
      title: Text(group.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${group.comicCount} 部作品${group.author.isNotEmpty ? ' · ${group.author}' : ''}',
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/group/${group.id}'),
      onLongPress: () => _showGroupActions(group),
    );
  }

  /// 长按操作菜单
  void _showGroupActions(ComicGroup group) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('查看详情'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/group/${group.id}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除合集', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteCollection(group.id, group.name);
              },
            ),
          ],
        ),
      ),
    );
  }
}
