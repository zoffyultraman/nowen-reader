import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';

import '../../data/api/api_client.dart';
import '../../data/api/comic_api.dart';
import '../../data/providers/auth_provider.dart';
import '../../widgets/authenticated_image.dart';
import '../../widgets/reader_settings_panel.dart';

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
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 0;
  int _totalPages = 0;
  bool _showOverlay = false;
  bool _loading = true;
  int? _sessionId;
  DateTime? _sessionStart;

  // 设置
  ReaderSettings _settings = const ReaderSettings();

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
    _loadSettings();
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
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final s = await ReaderSettings.load();
    if (mounted) setState(() => _settings = s);
  }

  Future<void> _loadPages() async {
    try {
      final api = ref.read(comicApiProvider);
      final data = await api.getPages(widget.comicId);
      if (!mounted) return;
      setState(() {
        _totalPages = data['totalPages'] ?? 0;
        _loading = false;
      });
      _startSession();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
      final interval = _settings.autoPageInterval > 0
          ? _settings.autoPageInterval
          : 10;
      _autoPageTimer = Timer.periodic(Duration(seconds: interval), (_) {
        if (_currentPage < _totalPages - 1) {
          if (_settings.mode == ComicReadingMode.webtoon) {
            // 长条模式 — 滚动
            _scrollController.animateTo(
              _scrollController.offset + 500,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            );
          } else {
            _pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        } else {
          _autoPageTimer?.cancel();
          setState(() => _autoPage = false);
        }
      });
    } else {
      _autoPageTimer?.cancel();
    }
  }

  void _onSettingsChanged(ReaderSettings s) {
    // 如果模式变了，需要重置自动翻页
    if (s.mode != _settings.mode) {
      _autoPageTimer?.cancel();
      _autoPage = false;
    }
    setState(() => _settings = s);
  }

  void _showSettings() {
    ReaderSettingsPanel.show(
      context,
      settings: _settings,
      onChanged: _onSettingsChanged,
    );
  }

  PhotoViewComputedScale _getInitialScale() {
    switch (_settings.fitMode) {
      case FitMode.width:
        return PhotoViewComputedScale.covered;
      case FitMode.height:
        return PhotoViewComputedScale.contained;
      case FitMode.contain:
        return PhotoViewComputedScale.contained;
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
          // 主体 — 根据阅读模式切换
          GestureDetector(
            onTap: _toggleOverlay,
            child: _settings.mode == ComicReadingMode.webtoon
                ? _buildWebtoonView(serverUrl)
                : _buildPageView(serverUrl),
          ),

          // 顶部 & 底部覆盖层
          if (_showOverlay) ...[
            _buildTopOverlay(),
            _buildBottomOverlay(),
          ],
        ],
      ),
    );
  }

  /// 单页翻页模式
  Widget _buildPageView(String serverUrl) {
    return PageView.builder(
      controller: _pageController,
      itemCount: _totalPages,
      onPageChanged: _onPageChanged,
      reverse: _settings.direction == ReadingDirection.rtl,
      scrollDirection: _settings.direction == ReadingDirection.ttb
          ? Axis.vertical
          : Axis.horizontal,
      itemBuilder: (context, index) {
        final imageUrl =
            getImageUrl(serverUrl, widget.comicId, page: index);
        return PhotoView(
          imageProvider: AuthenticatedImageProvider(imageUrl),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 3,
          initialScale: _getInitialScale(),
          backgroundDecoration:
              const BoxDecoration(color: Colors.black),
          loadingBuilder: (_, event) => Center(
            child: CircularProgressIndicator(
              value: event?.expectedTotalBytes != null
                  ? event!.cumulativeBytesLoaded /
                      event.expectedTotalBytes!
                  : null,
            ),
          ),
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image,
                color: Colors.white54, size: 48),
          ),
        );
      },
    );
  }

  /// 长条滚动模式（Webtoon）
  Widget _buildWebtoonView(String serverUrl) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          // 根据滚动位置估算当前页码
          final viewportHeight = notification.metrics.viewportDimension;
          if (viewportHeight > 0) {
            final page =
                (notification.metrics.pixels / viewportHeight).floor();
            if (page != _currentPage && page >= 0 && page < _totalPages) {
              setState(() => _currentPage = page);
              if (page % 5 == 0) _saveProgress();
            }
          }
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _totalPages,
        itemBuilder: (context, index) {
          final imageUrl =
              getImageUrl(serverUrl, widget.comicId, page: index);
          return AuthenticatedImage(
            imageUrl: imageUrl,
            fit: _settings.fitMode == FitMode.width
                ? BoxFit.fitWidth
                : BoxFit.contain,
            placeholder: SizedBox(
              height: MediaQuery.of(context).size.height,
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: SizedBox(
              height: 200,
              child: const Center(
                child: Icon(Icons.broken_image,
                    color: Colors.white54, size: 48),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 顶部工具栏
  Widget _buildTopOverlay() {
    return Positioned(
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
              // 返回按钮
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              // 页码
              Expanded(
                child: _settings.showPageNumber
                    ? Text(
                        '${_currentPage + 1} / $_totalPages',
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      )
                    : const SizedBox.shrink(),
              ),
              // 自动翻页
              if (_settings.autoPageInterval > 0)
                IconButton(
                  icon: Icon(
                    _autoPage ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  tooltip: _autoPage ? '停止自动翻页' : '自动翻页',
                  onPressed: _toggleAutoPage,
                ),
              // 设置按钮
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white),
                tooltip: '阅读设置',
                onPressed: _showSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 底部进度条
  Widget _buildBottomOverlay() {
    return Positioned(
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
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text('${_currentPage + 1}',
                    style: const TextStyle(color: Colors.white)),
                Expanded(
                  child: Slider(
                    value: _currentPage.toDouble(),
                    min: 0,
                    max: (_totalPages - 1)
                        .toDouble()
                        .clamp(0, double.infinity),
                    onChanged: (v) {
                      final page = v.toInt();
                      if (_settings.mode == ComicReadingMode.webtoon) {
                        // 长条模式滚动到对应位置
                        final viewportH =
                            MediaQuery.of(context).size.height;
                        _scrollController.jumpTo(page * viewportH);
                        setState(() => _currentPage = page);
                      } else {
                        _pageController.jumpToPage(page);
                      }
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
    );
  }
}
