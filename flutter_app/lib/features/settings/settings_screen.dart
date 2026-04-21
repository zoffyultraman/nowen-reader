import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers/auth_provider.dart';
import '../../data/api/api_client.dart';
import '../../l10n/app_localizations.dart';
import '../metadata/metadata_screen.dart';

/// 设置页面
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final isAdmin = user?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          // 用户信息
          if (user != null) ...[
            _buildSectionTitle(context, l10n.account),
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
                  user.isAdmin ? l10n.admin : l10n.user,
                ].join(' · '),
              ),
            ),
          ],

          const Divider(),
          _buildSectionTitle(context, l10n.serverInfo),

          // 服务器信息
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: Text(l10n.serverAddress),
            subtitle: Text(authState.serverUrl),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showServerInfo(context, ref),
          ),

          const Divider(),
          _buildSectionTitle(context, l10n.dataManagement),

          // 收藏管理
          ListTile(
            leading: const Icon(Icons.favorite_outlined),
            title: Text(l10n.favorites),
            subtitle: const Text('查看和管理收藏的书籍'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/favorites'),
          ),

          // 标签与分类管理（管理员可见）
          if (isAdmin)
            ListTile(
              leading: const Icon(Icons.label_outlined),
              title: Text(l10n.tagManager),
              subtitle: const Text('管理标签和分类'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/tag-manager'),
            ),

          // 批量刮削元数据（管理员可见）
          if (isAdmin)
            ListTile(
              leading: const Icon(Icons.auto_fix_high),
              title: Text(l10n.batchScrapeMetadata),
              subtitle: Text(l10n.batchScrapeDesc),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => const BatchMetadataDialog(),
                );
              },
            ),

          const Divider(),
          _buildSectionTitle(context, l10n.about),

          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.version),
            subtitle: const Text('1.0.0'),
          ),

          ListTile(
            leading: const Icon(Icons.code_outlined),
            title: const Text('NowenReader'),
            subtitle: const Text('漫画/小说阅读器'),
          ),

          const Divider(),

          // 退出登录
          ListTile(
            leading: Icon(Icons.logout, color: cs.error),
            title: Text(l10n.logout, style: TextStyle(color: cs.error)),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l10n.logout),
                  content: Text(l10n.logoutConfirm),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(l10n.cancel),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(l10n.logout),
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
            title: Text(l10n.switchServer),
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
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) {
        final serverUrl = ref.read(authProvider).serverUrl;
        return AlertDialog(
          title: Text(l10n.serverInfo),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${l10n.serverAddress}: $serverUrl'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.close),
            ),
          ],
        );
      },
    );
  }
}
