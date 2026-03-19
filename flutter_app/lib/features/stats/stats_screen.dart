import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/comic.dart';
import '../../data/providers/comic_provider.dart';

/// 阅读统计页面
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('阅读统计')),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (stats) => RefreshIndicator(
          onRefresh: () => ref.refresh(statsProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 总览卡片
              _buildOverviewCards(context, stats),
              const SizedBox(height: 24),

              // 每日阅读时长
              Text('每日阅读', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _buildDailyChart(context, stats),
              const SizedBox(height: 24),

              // 最近阅读记录
              Text('最近阅读记录',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _buildRecentSessions(context, stats),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCards(BuildContext context, ReadingStats stats) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.timer_outlined,
            label: '总阅读时间',
            value: _formatDuration(stats.totalReadTime),
            color: cs.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.auto_stories_outlined,
            label: '阅读场次',
            value: '${stats.totalSessions}',
            color: cs.secondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.menu_book_outlined,
            label: '已读本数',
            value: '${stats.totalComicsRead}',
            color: cs.tertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildDailyChart(BuildContext context, ReadingStats stats) {
    if (stats.safeDailyStats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            '暂无每日统计数据',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    // 最近14天数据
    final recent = stats.safeDailyStats.take(14).toList().reversed.toList();
    // 优先用 duration 作为柱状图高度，如果全为0则用 sessions
    final allDurationZero = recent.every((d) => d.duration == 0);
    final maxVal = allDurationZero
        ? recent.fold<int>(0, (max, d) => d.sessions > max ? d.sessions : max)
        : recent.fold<int>(
            0, (max, d) => d.duration > max ? d.duration : max);

    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: recent.map((d) {
          final ratio = maxVal > 0 ? (allDurationZero ? d.sessions / maxVal : d.duration / maxVal) : 0.0;
          final cs = Theme.of(context).colorScheme;
          final tooltipMsg = allDurationZero
              ? '${d.date}\n${d.sessions} 次阅读'
              : '${d.date}\n${_formatDuration(d.duration)}';
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Tooltip(
                message: tooltipMsg,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: FractionallySizedBox(
                        heightFactor: ratio.clamp(0.05, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: cs.primary.withOpacity(0.8),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      d.date.length >= 2
                          ? d.date.substring(d.date.length - 2)
                          : d.date,
                      style: TextStyle(
                          fontSize: 10, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecentSessions(BuildContext context, ReadingStats stats) {
    if (stats.safeRecentSessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            '暂无阅读记录',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    // 只显示最近10条
    final sessions = stats.safeRecentSessions.take(10).toList();
    return Column(
      children: sessions.map((s) {
        return _RecentSessionTile(session: s);
      }).toList(),
    );
  }

  static String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return '${h}h ${m}m';
  }
}

/// 最近阅读记录条目
class _RecentSessionTile extends StatelessWidget {
  final RecentSession session;

  const _RecentSessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // 解析时间
    String timeStr = '';
    try {
      final dt = DateTime.parse(session.startedAt).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) {
        timeStr = '${diff.inMinutes}分钟前';
      } else if (diff.inHours < 24) {
        timeStr = '${diff.inHours}小时前';
      } else if (diff.inDays < 7) {
        timeStr = '${diff.inDays}天前';
      } else {
        timeStr =
            '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {
      timeStr = session.startedAt;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Icon(Icons.auto_stories, color: cs.primary, size: 20),
        ),
        title: Text(
          session.comicTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '第${session.startPage + 1}-${session.endPage + 1}页 · ${_formatDuration(session.duration)}',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        trailing: Text(
          timeStr,
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
        onTap: () {
          context.push('/comic/${session.comicId}');
        },
      ),
    );
  }

  static String _formatDuration(int seconds) {
    if (seconds <= 0) return '未记录';
    if (seconds < 60) return '${seconds}秒';
    if (seconds < 3600) return '${seconds ~/ 60}分钟';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return '${h}小时${m}分钟';
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
