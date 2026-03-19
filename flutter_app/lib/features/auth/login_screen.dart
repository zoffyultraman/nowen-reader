import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers/auth_provider.dart';

/// 登录 & 注册页面
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  bool _isRegister = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // 如果需要初始设置，默认显示注册
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(authProvider);
      if (state.needsSetup) {
        setState(() => _isRegister = true);
      }
    });
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _nicknameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final nickname = _nicknameCtrl.text.trim();

    if (username.isEmpty || password.isEmpty) return;

    ref.read(authProvider.notifier).clearError();

    bool ok;
    if (_isRegister) {
      ok = await ref
          .read(authProvider.notifier)
          .register(username, password, nickname);
    } else {
      ok = await ref.read(authProvider.notifier).login(username, password);
    }

    if (ok && mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.menu_book_rounded, size: 64, color: cs.primary),
                const SizedBox(height: 12),
                Text(
                  authState.needsSetup ? '创建管理员账户' : (_isRegister ? '注册' : '登录'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (authState.needsSetup) ...[
                  const SizedBox(height: 8),
                  Text(
                    '这是首次使用，请创建管理员账户',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 32),

                // 用户名
                TextField(
                  controller: _usernameCtrl,
                  decoration: const InputDecoration(
                    labelText: '用户名',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),

                // 昵称（注册时显示）
                if (_isRegister) ...[
                  TextField(
                    controller: _nicknameCtrl,
                    decoration: const InputDecoration(
                      labelText: '昵称（可选）',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                ],

                // 密码
                TextField(
                  controller: _passwordCtrl,
                  decoration: InputDecoration(
                    labelText: '密码',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  obscureText: _obscurePassword,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 20),

                // 错误提示
                if (authState.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      authState.error!,
                      style: TextStyle(color: cs.error),
                    ),
                  ),

                // 提交按钮
                FilledButton(
                  onPressed: authState.isLoading ? null : _submit,
                  child: authState.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isRegister ? '注册' : '登录'),
                ),
                const SizedBox(height: 12),

                // 切换登录/注册
                if (!authState.needsSetup)
                  TextButton(
                    onPressed: () => setState(() {
                      _isRegister = !_isRegister;
                      ref.read(authProvider.notifier).clearError();
                    }),
                    child: Text(_isRegister ? '已有账户？去登录' : '没有账户？去注册'),
                  ),

                // 切换服务器
                TextButton.icon(
                  onPressed: () => context.go('/server'),
                  icon: const Icon(Icons.dns_outlined, size: 18),
                  label: const Text('切换服务器'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
