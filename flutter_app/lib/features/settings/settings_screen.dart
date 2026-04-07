import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers/auth_provider.dart';
import '../../data/api/api_client.dart';
import '../metadata/metadata_screen.dart';

/// 设置页面
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // 用户信息
          if (user != null) ...[
            _buildSectionTitle(context, '账户'),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: cs.primaryContainer,
                child: Text(
                  user.nickname.isNotEmpty
                      ? user.nickname[0].toUpperCase()
                      : user.username[0].toUpperCase(),
                  style: TextStyle(color: cs.onPrimaryContainer),
                ),
              ),
              title: Text(user.nickname.isNotEmpty ? user.nickname : user.username),
              subtitle: Text(
                [
                  '@${user.username}',
                  user.isAdmin ? '管理员' : '普通用户',
                ].join(' · '),
              ),
            ),
          ],

          const Divider(),
          _buildSectionTitle(context, '服务器'),

          // 服务器信息
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('服务器地址'),
            subtitle: Text(authState.serverUrl),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showServerInfo(context, ref),
          ),

          const Divider(),
          _buildSectionTitle(context, '关于'),

          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('版本'),
            subtitle: const Text('1.0.0'),
          ),

          ListTile(
            leading: const Icon(Icons.code_outlined),
            title: const Text('NowenReader'),
            subtitle: const Text('漫画/小说阅读器'),
          ),

          const Divider(),
          _buildSectionTitle(context, '数据管理'),

          // 批量刮削元数据
          ListTile(
            leading: const Icon(Icons.auto_fix_high),
            title: const Text('批量刮削元数据'),
            subtitle: const Text('从在线数据源自动获取元数据'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => const BatchMetadataDialog(),
              );
            },
          ),

          const Divider(),

          // 退出登录
          ListTile(
            leading: Icon(Icons.logout, color: cs.error),
            title: Text('退出登录', style: TextStyle(color: cs.error)),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('确认退出'),
                  content: const Text('确定要退出登录吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('退出'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              }
            },
          ),

          // 切换服务器
          ListTile(
            leading: Icon(Icons.swap_horiz, color: cs.onSurfaceVariant),
            title: const Text('切换服务器'),
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
              await saveServerUrl('');
              ref.invalidate(serverUrlProvider);
              if (context.mounted) context.go('/server');
            },
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  void _showServerInfo(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) {
        final serverUrl = ref.read(authProvider).serverUrl;
        return AlertDialog(
          title: const Text('服务器信息'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('地址: $serverUrl'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }
}
