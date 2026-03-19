import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/comic.dart';
import '../../data/providers/comic_provider.dart';

/// 阅读统计页面
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);
    final cs = Theme.of(context).colorScheme;

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
    if (stats.dailyStats.isEmpty) {
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

    // 最近14天数据
    final recent = stats.dailyStats.take(14).toList().reversed.toList();
    final maxDuration =
        recent.fold<int>(0, (max, d) => d.duration > max ? d.duration : max);

    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: recent.map((d) {
          final ratio = maxDuration > 0 ? d.duration / maxDuration : 0.0;
          final cs = Theme.of(context).colorScheme;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Tooltip(
                message: '${d.date}\n${_formatDuration(d.duration)}',
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
                      d.date.substring(d.date.length - 2),
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

  static String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return '${h}h ${m}m';
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
