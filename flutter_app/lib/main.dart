import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'data/api/api_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化持久化 CookieJar（登录状态保持）
  await initCookieJar();
  // 适配安卓15 edge-to-edge
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));
  runApp(const ProviderScope(child: NowenReaderApp()));
}
