import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'theme_provider.dart';

class PlayerScreen extends StatefulWidget {
  final Map<String, dynamic> video;
  const PlayerScreen({super.key, required this.video});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isDubbed = true;
  bool _showControls = true;
  bool _isFullscreen = false;
  bool _isInitialized = false;
  bool _isSwitching = false;
  bool _isMuted = false;
  double _speed = 1.0;
  double _volume = 1.0;
  Timer? _hideTimer;

  late AnimationController _controlsController;
  late Animation<double> _controlsFade;

  final List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  String? get _dubbedPath => widget.video['dubbedPath'];
  String? get _originalPath => widget.video['originalPath'];
  bool get _hasOriginal =>
      _originalPath != null && File(_originalPath!).existsSync();

  @override
  void initState() {
    super.initState();
    _controlsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    );
    _controlsFade =
        CurvedAnimation(parent: _controlsController, curve: Curves.easeOut);
    _initPlayer(_dubbedPath);
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controlsController.dispose();
    final c = _controller;
    _controller = null;
    c?.removeListener(_onVideoUpdate);
    c?.dispose();
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  void _onVideoUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _initPlayer(String? path) async {
    if (path == null || !File(path).existsSync()) return;

    final wasPlaying = _controller?.value.isPlaying ?? false;
    final position = _controller?.value.isInitialized == true
        ? _controller!.value.position
        : Duration.zero;

    final newController = VideoPlayerController.file(File(path));

    try {
      await newController.initialize();
      if (!mounted) {
        newController.dispose();
        return;
      }
      await newController.seekTo(position);
      await newController.setPlaybackSpeed(_speed);
      await newController.setVolume(_isMuted ? 0 : _volume);
      if (wasPlaying) await newController.play();

      // Swap controllers safely
      final oldController = _controller;
      oldController?.removeListener(_onVideoUpdate);

      newController.addListener(_onVideoUpdate);

      if (mounted) {
        setState(() {
          _controller = newController;
          _isInitialized = true;
          _isSwitching = false;
        });
      }

      // Dispose old after swap
      oldController?.dispose();
    } catch (e) {
      newController.dispose();
      if (mounted) setState(() { _isInitialized = false; _isSwitching = false; });
    }
  }

  // ── Controls visibility ──────────────────────────────────────────

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _showControls) {
        setState(() => _showControls = false);
        _controlsController.reverse();
      }
    });
  }

  void _onTapVideo() {
    _hideTimer?.cancel();
    final nowShowing = !_showControls;
    setState(() => _showControls = nowShowing);
    if (nowShowing) {
      _controlsController.forward();
      _startHideTimer();
    } else {
      _controlsController.reverse();
    }
  }

  // ── Playback controls ────────────────────────────────────────────

  void _togglePlay() {
    if (_controller == null) return;
    _hideTimer?.cancel();
    if (_controller!.value.isPlaying) {
      _controller!.pause();
      // Don't auto hide when paused
    } else {
      _controller!.play();
      _startHideTimer();
    }
  }

  Future<void> _toggleAudio() async {
    if (_isSwitching) return;
    setState(() => _isSwitching = true);
    final newDubbed = !_isDubbed;
    setState(() => _isDubbed = newDubbed);
    await _initPlayer(newDubbed ? _dubbedPath : _originalPath);
  }

  void _onSeek(double val) {
    if (_controller == null || !_isInitialized) return;
    _controller!.seekTo(_controller!.value.duration * val);
    _startHideTimer();
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _controller?.setVolume(_isMuted ? 0 : _volume);
  }

  void _onVolume(double val) {
    setState(() {
      _volume = val;
      _isMuted = val == 0;
    });
    _controller?.setVolume(val);
  }

  void _cycleSpeed() {
    final idx = _speeds.indexOf(_speed);
    setState(() => _speed = _speeds[(idx + 1) % _speeds.length]);
    _controller?.setPlaybackSpeed(_speed);
    _startHideTimer();
  }

  void _skipForward() {
    if (_controller == null) return;
    _controller!.seekTo(_controller!.value.position + const Duration(seconds: 10));
    _startHideTimer();
  }

  void _skipBackward() {
    if (_controller == null) return;
    final pos = _controller!.value.position - const Duration(seconds: 10);
    _controller!.seekTo(pos.isNegative ? Duration.zero : pos);
    _startHideTimer();
  }

  void _enterFullscreen() {
    setState(() => _isFullscreen = true);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _exitFullscreen() {
    setState(() => _isFullscreen = false);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  // ── Download / Share ─────────────────────────────────────────────

  Future<void> _downloadVideo() async {
    // Always download dubbed
    final path = _dubbedPath;
    if (path == null) return;
    try {
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (!await downloadsDir.exists()) await downloadsDir.create(recursive: true);
      final fileName = '${widget.video['name'] ?? 'video'}_dubbed.mp4';
      await File(path).copy('${downloadsDir.path}/$fileName');
      if (mounted) _showSnackBar(ThemeScope.of(context), 'Saved to Downloads');
    } catch (e) {
      if (mounted) _showSnackBar(ThemeScope.of(context), 'Download failed');
    }
  }

  Future<void> _shareVideo() async {
    final path = _dubbedPath;
    if (path == null) return;
    try {
      await Share.shareXFiles(
        [XFile(path)],
        text: 'Check out this dubbed video from VideoDub!',
      );
    } catch (e) {
      if (mounted) _showSnackBar(ThemeScope.of(context), 'Share failed');
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  double get _progress {
    if (_controller == null || !_isInitialized) return 0;
    final dur = _controller!.value.duration.inMilliseconds;
    if (dur == 0) return 0;
    return (_controller!.value.position.inMilliseconds / dur).clamp(0.0, 1.0);
  }

  void _showSnackBar(ThemeProvider theme, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: TextStyle(color: theme.text, fontSize: 13)),
      backgroundColor: theme.surface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    if (_isFullscreen) return _buildFullscreen(theme);
    return _buildNormal(theme);
  }

  // ── Normal View ───────────────────────────────────────────────────

  Widget _buildNormal(ThemeProvider theme) {
    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  _IconBtn(icon: Icons.arrow_back_ios_rounded,
                      onTap: () => Navigator.pop(context), theme: theme),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.video['name'] ?? 'Video',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: theme.text),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('${_isDubbed ? 'Dubbed' : 'Original'} • ${widget.video['language'] ?? ''}',
                            style: TextStyle(fontSize: 11, color: theme.textHint)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _IconBtn(icon: Icons.download_rounded, onTap: _downloadVideo, theme: theme),
                  const SizedBox(width: 6),
                  _IconBtn(icon: Icons.share_rounded, onTap: _shareVideo, theme: theme),
                ],
              ),
            ),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Video
                  GestureDetector(
                    onTap: _onTapVideo,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                          color: Colors.black, borderRadius: BorderRadius.circular(14)),
                      child: AspectRatio(
                        aspectRatio: _isInitialized ? _controller!.value.aspectRatio : 16 / 9,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Video or loader
                              if (_isInitialized)
                                VideoPlayer(_controller!)
                              else
                                const ColoredBox(color: Colors.black,
                                  child: Center(child: CircularProgressIndicator(
                                      color: AppColors.purple, strokeWidth: 2))),

                              // Switching overlay
                              if (_isSwitching)
                                const ColoredBox(color: Colors.black45,
                                  child: Center(child: CircularProgressIndicator(
                                      color: AppColors.purple, strokeWidth: 2))),

                              // Controls
                              FadeTransition(
                                opacity: _controlsFade,
                                child: ColoredBox(
                                  color: Colors.black38,
                                  child: Stack(
                                    children: [
                                      // Center controls — truly centered in full video area
                                      Center(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            _SkipBtn(forward: false, onTap: _skipBackward),
                                            const SizedBox(width: 24),
                                            GestureDetector(
                                              onTap: _togglePlay,
                                              child: Container(
                                                width: 52, height: 52,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: AppColors.purple.withOpacity(0.3),
                                                  border: Border.all(
                                                      color: AppColors.purple.withOpacity(0.8), width: 1.5),
                                                ),
                                                child: Icon(
                                                  _controller?.value.isPlaying == true
                                                      ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                                  color: Colors.white, size: 28,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 24),
                                            _SkipBtn(forward: true, onTap: _skipForward),
                                          ],
                                        ),
                                      ),

                                      // Bottom bar — pinned to bottom
                                      Positioned(
                                        bottom: 0, left: 0, right: 0,
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SliderTheme(
                                                data: SliderTheme.of(context).copyWith(
                                                  trackHeight: 2.5,
                                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                                                  activeTrackColor: AppColors.purple,
                                                  inactiveTrackColor: Colors.white24,
                                                  thumbColor: AppColors.purple,
                                                  overlayColor: AppColors.purple.withOpacity(0.2),
                                                ),
                                                child: Slider(value: _progress, onChanged: _onSeek),
                                              ),
                                              Row(
                                                children: [
                                                  Text(
                                                    _isInitialized
                                                      ? '${_fmt(_controller!.value.position)} / ${_fmt(_controller!.value.duration)}'
                                                      : '0:00 / 0:00',
                                                    style: const TextStyle(fontSize: 9, color: Colors.white60),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  GestureDetector(
                                                    onTap: _toggleMute,
                                                    child: Icon(
                                                      _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                                      color: Colors.white54, size: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 2),
                                                  SizedBox(
                                                    width: 50,
                                                    child: SliderTheme(
                                                      data: SliderTheme.of(context).copyWith(
                                                        trackHeight: 2,
                                                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                                                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                                                        activeTrackColor: AppColors.purple,
                                                        inactiveTrackColor: Colors.white24,
                                                        thumbColor: AppColors.purple,
                                                        overlayColor: AppColors.purple.withOpacity(0.2),
                                                      ),
                                                      child: Slider(value: _isMuted ? 0 : _volume, onChanged: _onVolume),
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  GestureDetector(
                                                    onTap: _cycleSpeed,
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                      decoration: BoxDecoration(
                                                          color: Colors.white12,
                                                          borderRadius: BorderRadius.circular(5)),
                                                      child: Text('${_speed}x',
                                                          style: const TextStyle(
                                                              fontSize: 9, color: Colors.white70,
                                                              fontWeight: FontWeight.w500)),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  GestureDetector(
                                                    onTap: _enterFullscreen,
                                                    child: const Icon(Icons.fullscreen_rounded,
                                                        color: Colors.white70, size: 18),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Audio toggle
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _AudioToggle(
                      isDubbed: _isDubbed,
                      isSwitching: _isSwitching,
                      onToggle: (_hasOriginal && !_isSwitching) ? _toggleAudio : null,
                      theme: theme,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Fullscreen ────────────────────────────────────────────────────

  Widget _buildFullscreen(ThemeProvider theme) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _onTapVideo,
        child: Stack(
          children: [
            if (_isInitialized)
              Center(child: VideoPlayer(_controller!))
            else
              const Center(child: CircularProgressIndicator(color: AppColors.purple)),

            if (_isSwitching)
              const Center(child: CircularProgressIndicator(color: AppColors.purple)),

            FadeTransition(
              opacity: _controlsFade,
              child: Stack(
                children: [
                  // Top
                  Positioned(top: 0, left: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                      decoration: const BoxDecoration(gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.black54, Colors.transparent])),
                      child: Row(children: [
                        GestureDetector(
                          onTap: () { _exitFullscreen(); Navigator.pop(context); },
                          child: Container(width: 30, height: 30,
                            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 14)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(widget.video['name'] ?? 'Video',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                        GestureDetector(onTap: _downloadVideo,
                          child: Container(width: 30, height: 30,
                            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.download_rounded, color: Colors.white, size: 15))),
                        const SizedBox(width: 8),
                        GestureDetector(onTap: _shareVideo,
                          child: Container(width: 30, height: 30,
                            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.share_rounded, color: Colors.white, size: 15))),
                      ]),
                    ),
                  ),

                  // Center
                  Center(child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SkipBtn(forward: false, large: true, onTap: _skipBackward),
                      const SizedBox(width: 32),
                      GestureDetector(onTap: _togglePlay,
                        child: Container(width: 64, height: 64,
                          decoration: BoxDecoration(shape: BoxShape.circle,
                            color: AppColors.purple.withOpacity(0.3),
                            border: Border.all(color: AppColors.purple.withOpacity(0.8), width: 1.5)),
                          child: Icon(
                            _controller?.value.isPlaying == true
                                ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white, size: 34))),
                      const SizedBox(width: 32),
                      _SkipBtn(forward: true, large: true, onTap: _skipForward),
                    ],
                  )),

                  // Bottom
                  Positioned(bottom: 0, left: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      decoration: const BoxDecoration(gradient: LinearGradient(
                        begin: Alignment.bottomCenter, end: Alignment.topCenter,
                        colors: [Colors.black54, Colors.transparent])),
                      child: Column(children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                            activeTrackColor: AppColors.purple,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: AppColors.purple,
                            overlayColor: AppColors.purple.withOpacity(0.2),
                          ),
                          child: Slider(value: _progress, onChanged: _onSeek),
                        ),
                        Row(children: [
                          Text(
                            _isInitialized
                              ? '${_fmt(_controller!.value.position)} / ${_fmt(_controller!.value.duration)}'
                              : '0:00 / 0:00',
                            style: const TextStyle(fontSize: 10, color: Colors.white60)),
                          const Spacer(),
                          GestureDetector(onTap: _toggleMute,
                            child: Icon(_isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                color: Colors.white54, size: 14)),
                          const SizedBox(width: 4),
                          SizedBox(width: 80,
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 2,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                                activeTrackColor: AppColors.purple,
                                inactiveTrackColor: Colors.white24,
                                thumbColor: AppColors.purple,
                                overlayColor: AppColors.purple.withOpacity(0.2),
                              ),
                              child: Slider(value: _isMuted ? 0 : _volume, onChanged: _onVolume))),
                          const SizedBox(width: 12),
                          GestureDetector(onTap: _cycleSpeed,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(6)),
                              child: Text('${_speed}x',
                                  style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w500)))),
                          const SizedBox(width: 12),
                          if (_hasOriginal)
                            Container(
                              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.all(3),
                              child: Row(children: [
                                _AudioChip(label: 'Dub', active: _isDubbed, onTap: _toggleAudio),
                                _AudioChip(label: 'Orig', active: !_isDubbed, onTap: _toggleAudio),
                              ])),
                          const SizedBox(width: 10),
                          GestureDetector(onTap: _exitFullscreen,
                            child: const Icon(Icons.fullscreen_exit_rounded, color: Colors.white70, size: 22)),
                        ]),
                      ]),
                    ),
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

// ── Components ────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final ThemeProvider theme;
  const _IconBtn({required this.icon, required this.onTap, required this.theme});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: theme.border, width: 0.5),
        ),
        child: Icon(icon, size: 15, color: AppColors.purple),
      ),
    );
  }
}

class _SkipBtn extends StatelessWidget {
  final bool forward;
  final VoidCallback onTap;
  final bool large;
  const _SkipBtn({required this.forward, required this.onTap, this.large = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(forward ? Icons.skip_next_rounded : Icons.skip_previous_rounded,
              color: Colors.white70, size: large ? 26 : 22),
          Text('10s', style: TextStyle(fontSize: large ? 9 : 8, color: Colors.white54)),
        ],
      ),
    );
  }
}

class _AudioToggle extends StatelessWidget {
  final bool isDubbed;
  final bool isSwitching;
  final VoidCallback? onToggle;
  final ThemeProvider theme;
  const _AudioToggle({
    required this.isDubbed,
    required this.isSwitching,
    required this.onToggle,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final canToggle = onToggle != null && !isSwitching;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('AUDIO',
            style: TextStyle(fontSize: 11, color: theme.textHint,
                letterSpacing: 0.06, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.border, width: 0.5),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: (isDubbed || !canToggle) ? null : onToggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isDubbed ? AppColors.purple : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Center(child: Text('Dubbed',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                            color: isDubbed ? Colors.white : theme.textHint))),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: (!isDubbed || !canToggle) ? null : onToggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !isDubbed ? AppColors.purple : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Center(child: isSwitching
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.purple))
                        : Text(onToggle != null ? 'Original' : 'Original (N/A)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                                color: !isDubbed ? Colors.white : theme.textHint))),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AudioChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _AudioChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: active ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.purple : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
                color: active ? Colors.white : Colors.white38)),
      ),
    );
  }
}