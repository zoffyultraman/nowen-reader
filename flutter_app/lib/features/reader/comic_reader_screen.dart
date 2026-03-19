import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';

import '../../data/api/api_client.dart';
import '../../data/api/comic_api.dart';
import '../../data/providers/auth_provider.dart';

/// 漫画阅读器
class ComicReaderScreen extends ConsumerStatefulWidget {
  final String comicId;
  final int initialPage;

  const ComicReaderScreen({
    super.key,
    required this.comicId,
    this.initialPage = 0,
  });

  @override
  ConsumerState<ComicReaderScreen> createState() => _ComicReaderScreenState();
}

class _ComicReaderScreenState extends ConsumerState<ComicReaderScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  int _totalPages = 0;
  bool _showOverlay = false;
  bool _loading = true;
  int? _sessionId;
  DateTime? _sessionStart;

  // 自动翻页
  Timer? _autoPageTimer;
  bool _autoPage = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: _currentPage);
    // 全屏沉浸模式
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadPages();
  }

  @override
  void dispose() {
    _autoPageTimer?.cancel();
    // 恢复系统UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // 保存进度 & 结束会话
    _saveProgress();
    _endSession();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadPages() async {
    try {
      final api = ref.read(comicApiProvider);
      final data = await api.getPages(widget.comicId);
      setState(() {
        _totalPages = data['pageCount'] ?? 0;
        _loading = false;
      });
      _startSession();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _startSession() async {
    try {
      final api = ref.read(comicApiProvider);
      _sessionId = await api.startSession(widget.comicId, _currentPage);
      _sessionStart = DateTime.now();
    } catch (_) {}
  }

  Future<void> _endSession() async {
    if (_sessionId == null || _sessionStart == null) return;
    final duration = DateTime.now().difference(_sessionStart!).inSeconds;
    try {
      final api = ref.read(comicApiProvider);
      await api.endSession(_sessionId!, _currentPage, duration);
    } catch (_) {}
  }

  Future<void> _saveProgress() async {
    try {
      final api = ref.read(comicApiProvider);
      await api.updateProgress(widget.comicId, _currentPage);
    } catch (_) {}
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    // 每翻5页自动保存
    if (page % 5 == 0) _saveProgress();
  }

  void _toggleOverlay() {
    setState(() => _showOverlay = !_showOverlay);
  }

  void _toggleAutoPage() {
    setState(() => _autoPage = !_autoPage);
    if (_autoPage) {
      _autoPageTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (_currentPage < _totalPages - 1) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        } else {
          _autoPageTimer?.cancel();
          setState(() => _autoPage = false);
        }
      });
    } else {
      _autoPageTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final serverUrl = ref.watch(authProvider).serverUrl;

    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 主体 - 页面视图
          GestureDetector(
            onTap: _toggleOverlay,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _totalPages,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final imageUrl =
                    getImageUrl(serverUrl, widget.comicId, page: index);
                return PhotoView(
                  imageProvider: CachedNetworkImageProvider(imageUrl),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 3,
                  initialScale: PhotoViewComputedScale.contained,
                  backgroundDecoration: const BoxDecoration(color: Colors.black),
                  loadingBuilder: (_, event) => Center(
                    child: CircularProgressIndicator(
                      value: event?.expectedTotalBytes != null
                          ? event!.cumulativeBytesLoaded /
                              event.expectedTotalBytes!
                          : null,
                    ),
                  ),
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
                  ),
                );
              },
            ),
          ),

          // 顶部覆盖层
          if (_showOverlay) ...[
            // 顶部栏
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          '${_currentPage + 1} / $_totalPages',
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _autoPage ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                        ),
                        tooltip: _autoPage ? '停止自动翻页' : '自动翻页',
                        onPressed: _toggleAutoPage,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 底部进度条
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Text('${_currentPage + 1}',
                            style: const TextStyle(color: Colors.white)),
                        Expanded(
                          child: Slider(
                            value: _currentPage.toDouble(),
                            min: 0,
                            max: (_totalPages - 1).toDouble().clamp(0, double.infinity),
                            onChanged: (v) {
                              _pageController.jumpToPage(v.toInt());
                            },
                          ),
                        ),
                        Text('$_totalPages',
                            style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
