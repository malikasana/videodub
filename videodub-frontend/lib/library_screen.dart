import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'theme_provider.dart';
import 'player_screen.dart';
import 'library_service.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _sortAZ = true;
  String? _activeItemId;
  final _service = LibraryService.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _service.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _service.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  List<VideoJob> get _sortedProgress {
    final list = List<VideoJob>.from(_service.inProgressJobs);
    list.sort((a, b) => _sortAZ
        ? a.name.compareTo(b.name)
        : b.name.compareTo(a.name));
    return list;
  }

  List<VideoJob> get _sortedDone {
    final list = List<VideoJob>.from(_service.doneJobs);
    list.sort((a, b) => _sortAZ
        ? a.name.compareTo(b.name)
        : b.name.compareTo(a.name));
    return list;
  }

  void _toggleSort() => setState(() => _sortAZ = !_sortAZ);
  void _activateItem(String id) => setState(() => _activeItemId = id);
  void _deactivateItem() => setState(() => _activeItemId = null);

  void _showRenameDialog(BuildContext context, VideoJob job) {
    final theme = ThemeScope.of(context);
    // Strip extension so user only edits the title
    final nameWithoutExt = job.name.contains('.')
        ? job.name.substring(0, job.name.lastIndexOf('.'))
        : job.name;
    final controller = TextEditingController(text: nameWithoutExt);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Rename video',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: theme.text)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(fontSize: 14, color: theme.text),
          decoration: InputDecoration(
            hintText: 'Video name',
            hintStyle: TextStyle(color: theme.textHint),
            filled: true,
            fillColor: theme.bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: theme.border, width: 0.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: theme.border, width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.purple, width: 1),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: theme.textHint)),
          ),
          TextButton(
            onPressed: () async {
              // Reattach .mp4 extension always
              final newName = '${controller.text.trim()}.mp4';
              await _service.renameJob(job.videoId, newName);
              if (context.mounted) Navigator.pop(context);
              _deactivateItem();
            },
            child: const Text('Rename',
                style: TextStyle(color: AppColors.purple, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  void _showConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    required VoidCallback onConfirm,
  }) {
    final theme = ThemeScope.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.danger)),
        content: Text(message,
            style: TextStyle(fontSize: 13, color: theme.textMuted, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: theme.textHint)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text('Confirm',
                style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    final theme = ThemeScope.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: theme.text, fontSize: 13)),
        backgroundColor: theme.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final inProgress = _sortedProgress;
    final done = _sortedDone;

    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Text('Library',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w500,
                          color: theme.text,
                          letterSpacing: -0.3)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _toggleSort,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.border, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.sort_rounded, size: 14, color: AppColors.purple),
                          const SizedBox(width: 4),
                          Text(_sortAZ ? 'A→Z' : 'Z→A',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.purple,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: theme.border, width: 0.5)),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.purple,
                indicatorWeight: 2,
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: AppColors.purple,
                unselectedLabelColor: theme.textHint,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('In progress'),
                        const SizedBox(width: 6),
                        _TabBadge(count: inProgress.length, isActive: _tabController.index == 0),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Done'),
                        const SizedBox(width: 6),
                        _TabBadge(count: done.length, isActive: _tabController.index == 1),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // In Progress tab
                  inProgress.isEmpty
                      ? _EmptyState(message: 'No videos in progress', theme: theme)
                      : ListView.builder(
                          padding: const EdgeInsets.all(14),
                          itemCount: inProgress.length,
                          itemBuilder: (context, index) {
                            final job = inProgress[index];
                            final isActive = _activeItemId == job.videoId;
                            return _InProgressItem(
                              job: job,
                              theme: theme,
                              isActive: isActive,
                              onLongPress: () => _activateItem(job.videoId),
                              onTapBody: _deactivateItem,
                              onDelete: () {
                                _deactivateItem();
                                _showConfirmDialog(
                                  context: context,
                                  title: 'Cancel processing',
                                  message: 'This will cancel the dubbing and delete the video. Cannot be undone.',
                                  confirmLabel: 'Cancel & delete',
                                  onConfirm: () async {
                                    await _service.cancelJob(job.videoId);
                                  },
                                );
                              },
                            );
                          },
                        ),

                  // Done tab
                  done.isEmpty
                      ? _EmptyState(message: 'No dubbed videos yet', theme: theme)
                      : ListView.builder(
                          padding: const EdgeInsets.all(14),
                          itemCount: done.length,
                          itemBuilder: (context, index) {
                            final job = done[index];
                            final isActive = _activeItemId == job.videoId;
                            return _DoneItem(
                              job: job,
                              theme: theme,
                              isActive: isActive,
                              onTap: () {
                                if (isActive) {
                                  _deactivateItem();
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PlayerScreen(video: {
                                        'name': job.name,
                                        'language': job.targetLanguage,
                                        'dubbedPath': job.dubbedPath,
                                        'originalPath': job.originalPath,
                                      }),
                                    ),
                                  );
                                }
                              },
                              onLongPress: () => _activateItem(job.videoId),
                              onRename: () => _showRenameDialog(context, job),
                              onDownload: () async {
                                _deactivateItem();
                                final path = job.dubbedPath;
                                if (path == null) return;
                                try {
                                  final downloadsDir = Directory('/storage/emulated/0/Download');
                                  if (!await downloadsDir.exists()) await downloadsDir.create(recursive: true);
                                  final destPath = '${downloadsDir.path}/${job.name}_dubbed.mp4';
                                  await File(path).copy(destPath);
                                  if (context.mounted) _showSnackBar(context, 'Saved to Downloads');
                                } catch (e) {
                                  if (context.mounted) _showSnackBar(context, 'Download failed');
                                }
                              },
                              onShare: () async {
                                _deactivateItem();
                                final path = job.dubbedPath;
                                if (path == null) return;
                                try {
                                  await Share.shareXFiles(
                                    [XFile(path)],
                                    text: 'Check out this dubbed video from VideoDub!',
                                  );
                                } catch (e) {
                                  if (context.mounted) _showSnackBar(context, 'Share failed');
                                }
                              },
                              onDelete: () {
                                _deactivateItem();
                                _showConfirmDialog(
                                  context: context,
                                  title: 'Delete video',
                                  message: 'This will permanently delete "${job.name}". Cannot be undone.',
                                  confirmLabel: 'Delete',
                                  onConfirm: () async {
                                    await _service.deleteDoneJob(job.videoId);
                                  },
                                );
                              },
                            );
                          },
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab Badge ─────────────────────────────────────────────────────

class _TabBadge extends StatelessWidget {
  final int count;
  final bool isActive;
  const _TabBadge({required this.count, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.purple.withOpacity(0.15)
            : const Color(0xFF4A4A6A).withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$count',
          style: TextStyle(
              fontSize: 10,
              color: isActive ? AppColors.purple : const Color(0xFF4A4A6A),
              fontWeight: FontWeight.w500)),
    );
  }
}

// ── In Progress Item ──────────────────────────────────────────────

class _InProgressItem extends StatelessWidget {
  final VideoJob job;
  final ThemeProvider theme;
  final bool isActive;
  final VoidCallback onLongPress;
  final VoidCallback onTapBody;
  final VoidCallback onDelete;

  const _InProgressItem({
    required this.job,
    required this.theme,
    required this.isActive,
    required this.onLongPress,
    required this.onTapBody,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      onTap: onTapBody,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppColors.purple.withOpacity(0.4) : theme.border,
            width: isActive ? 1 : 0.5,
          ),
        ),
        child: Row(
          children: [
            _VideoThumbnail(path: job.originalPath, width: 48, height: 34, theme: theme),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(job.name,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: theme.text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${job.targetLanguage} • ${job.progress}%',
                      style: TextStyle(fontSize: 11, color: theme.textHint)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isActive
                  ? GestureDetector(
                      onTap: onDelete,
                      child: Container(
                        key: const ValueKey('delete'),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.danger),
                      ),
                    )
                  : SizedBox(
                      key: const ValueKey('spinner'),
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: job.progress > 0 ? job.progress / 100 : null,
                        color: AppColors.purple,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Done Item ─────────────────────────────────────────────────────

class _DoneItem extends StatelessWidget {
  final VideoJob job;
  final ThemeProvider theme;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onRename;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const _DoneItem({
    required this.job,
    required this.theme,
    required this.isActive,
    required this.onTap,
    required this.onLongPress,
    required this.onRename,
    required this.onDownload,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppColors.purple.withOpacity(0.4) : theme.border,
            width: isActive ? 1 : 0.5,
          ),
        ),
        child: Row(
          children: [
            _VideoThumbnail(path: job.originalPath, width: 58, height: 38, theme: theme, showPlay: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(job.name,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: theme.text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(job.targetLanguage,
                      style: TextStyle(fontSize: 11, color: theme.textHint)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isActive
                  ? Row(
                      key: const ValueKey('actions'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ActionBtn(icon: Icons.drive_file_rename_outline_rounded, color: AppColors.purple, onTap: onRename),
                        const SizedBox(width: 6),
                        _ActionBtn(icon: Icons.download_rounded, color: AppColors.teal, onTap: onDownload),
                        const SizedBox(width: 6),
                        _ActionBtn(icon: Icons.share_rounded, color: AppColors.purpleLight, onTap: onShare),
                        const SizedBox(width: 6),
                        _ActionBtn(icon: Icons.delete_outline_rounded, color: AppColors.danger, onTap: onDelete),
                      ],
                    )
                  : Container(
                      key: const ValueKey('dot'),
                      width: 7, height: 7,
                      decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Action Button ─────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }
}

// ── Video Thumbnail ──────────────────────────────────────────────

class _VideoThumbnail extends StatefulWidget {
  final String path;
  final double width;
  final double height;
  final ThemeProvider theme;
  final bool showPlay;

  const _VideoThumbnail({
    required this.path,
    required this.width,
    required this.height,
    required this.theme,
    this.showPlay = false,
  });

  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (widget.path.isEmpty || !File(widget.path).existsSync()) return;
    try {
      final c = VideoPlayerController.file(File(widget.path));
      await c.initialize();
      await c.seekTo(Duration.zero);
      if (mounted) setState(() { _controller = c; _ready = true; });
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_ready && _controller != null)
              VideoPlayer(_controller!)
            else
              Container(
                color: widget.theme.card,
                child: Icon(
                  widget.showPlay ? Icons.play_circle_fill_rounded : Icons.videocam_outlined,
                  size: widget.showPlay ? 20 : 16,
                  color: widget.showPlay ? AppColors.purple : AppColors.purpleDark,
                ),
              ),
            if (_ready && widget.showPlay)
              Center(
                child: Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.4),
                  ),
                  child: const Icon(Icons.play_arrow_rounded, size: 14, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String message;
  final ThemeProvider theme;

  const _EmptyState({required this.message, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_library_outlined, size: 40, color: theme.textHint),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(fontSize: 14, color: theme.textHint)),
        ],
      ),
    );
  }
}