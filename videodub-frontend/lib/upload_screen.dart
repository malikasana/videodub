import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'theme_provider.dart';
import 'user_service.dart';
import 'api_service.dart';
import 'library_service.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _selectedVideo;
  String? _sourceLanguage;
  String? _targetLanguage;
  bool _isUploading = false;
  VideoPlayerController? _thumbController;
  bool _thumbReady = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  final List<String> _languages = [
    'English', 'Spanish', 'French', 'German', 'Arabic',
    'Hindi', 'Portuguese', 'Japanese', 'Chinese',
    'Italian', 'Russian', 'Turkish', 'Korean',
  ];

  List<String> get _targetLanguages =>
      _languages.where((l) => l != _sourceLanguage).toList();

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
    _loadDefaultLanguages();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _thumbController?.dispose();
    super.dispose();
  }

  Future<void> _loadDefaultLanguages() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sourceLanguage = prefs.getString('default_source_language');
      _targetLanguage = prefs.getString('default_dub_language');
      if (_sourceLanguage != null &&
          _targetLanguage != null &&
          _sourceLanguage == _targetLanguage) {
        _targetLanguage = null;
      }
    });
  }

  Future<void> _initThumbnail(String path) async {
    _thumbController?.dispose();
    _thumbController = VideoPlayerController.file(File(path));
    try {
      await _thumbController!.initialize();
      // Seek to first frame
      await _thumbController!.seekTo(Duration.zero);
      if (mounted) setState(() => _thumbReady = true);
    } catch (_) {
      if (mounted) setState(() => _thumbReady = false);
    }
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp4', 'mov', 'avi', 'mkv'],
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    final fileSize = File(file.path!).lengthSync();
    if (fileSize > 500 * 1024 * 1024) {
      if (mounted) _showSnackBar(ThemeScope.of(context), 'File too large. Max size is 500MB.');
      return;
    }

    final sizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(1);

    setState(() {
      _thumbReady = false;
      _selectedVideo = {
        'name': file.name,
        'path': file.path!,
        'size': '$sizeMB MB',
      };
      if (_sourceLanguage != null &&
          _targetLanguage != null &&
          _sourceLanguage == _targetLanguage) {
        _targetLanguage = null;
      }
    });

    await _initThumbnail(file.path!);
    _fadeController.reset();
    _fadeController.forward();
  }

  void _discardVideo() {
    _thumbController?.dispose();
    _thumbController = null;
    setState(() {
      _selectedVideo = null;
      _isUploading = false;
      _thumbReady = false;
    });
    _loadDefaultLanguages();
    _fadeController.reset();
    _fadeController.forward();
  }

  void _showLanguagePicker({
    required ThemeProvider theme,
    required String title,
    required List<String> options,
    required String? current,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: theme.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: theme.text)),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final lang = options[index];
                  final isSelected = lang == current;
                  return ListTile(
                    onTap: () { onSelected(lang); Navigator.pop(context); },
                    title: Text(lang,
                        style: TextStyle(
                            fontSize: 14,
                            color: isSelected ? AppColors.purple : theme.text,
                            fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400)),
                    trailing: isSelected
                        ? const Icon(Icons.check_rounded, color: AppColors.purple, size: 18)
                        : null,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Future<void> _sendForDubbing(ThemeProvider theme) async {
    if (_sourceLanguage == null || _targetLanguage == null) return;
    if (_selectedVideo == null) return;

    setState(() => _isUploading = true);

    final userService = await UserService.getInstance();
    final userId = await userService.getUserId();
    final videoFile = File(_selectedVideo!['path']);

    final result = await ApiService.instance.uploadVideo(
      userId: userId,
      videoFile: videoFile,
      originalName: _selectedVideo!['name'],
    );

    if (!mounted) return;
    setState(() => _isUploading = false);

    if (result.success) {
      await LibraryService.instance.addJob(
        videoId: result.videoId!,
        name: _selectedVideo!['name'],
        sourceLanguage: _sourceLanguage!,
        targetLanguage: _targetLanguage!,
        originalPath: _selectedVideo!['path'],
      );
      _discardVideo();
      _showSnackBar(theme, 'Video sent! You\'ll be notified when it\'s ready.');
    } else {
      _showSnackBar(theme, result.error ?? 'Upload failed. Please try again.');
    }
  }

  void _showSnackBar(ThemeProvider theme, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: theme.text, fontSize: 13)),
        backgroundColor: theme.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: _selectedVideo == null
              ? _buildEmptyState(theme)
              : _buildSelectedState(theme),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _buildTitle(theme),
          const Spacer(),
          _buildUploadZone(theme),
          const SizedBox(height: 16),
          _buildGuideCard(theme),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildUploadZone(ThemeProvider theme) {
    return GestureDetector(
      onTap: _pickVideo,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.border, width: 1.5),
        ),
        child: Column(
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: theme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.border, width: 0.5),
              ),
              child: const Icon(Icons.upload_rounded, size: 28, color: AppColors.purple),
            ),
            const SizedBox(height: 16),
            Text('Tap to select a video',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: theme.text)),
            const SizedBox(height: 6),
            Text('MP4, MOV, AVI  •  Max 500MB',
                style: TextStyle(fontSize: 12, color: theme.textHint)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 11),
              decoration: BoxDecoration(color: AppColors.purple, borderRadius: BorderRadius.circular(10)),
              child: const Text('Choose video',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideCard(ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.border, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 15, color: theme.textHint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Select a video, tell us what language it\'s in, then choose the target language. We\'ll handle the rest.',
              style: TextStyle(fontSize: 12, color: theme.textHint, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedState(ThemeProvider theme) {
    final canSend = _sourceLanguage != null && _targetLanguage != null && !_isUploading;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitle(theme),
              const Spacer(),
              GestureDetector(
                onTap: _isUploading ? null : _discardVideo,
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.border, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.close_rounded, size: 13,
                          color: _isUploading ? theme.textFaint : AppColors.danger),
                      const SizedBox(width: 4),
                      Text('Discard',
                          style: TextStyle(fontSize: 11,
                              color: _isUploading ? theme.textFaint : AppColors.danger,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildThumbnail(theme),
          const SizedBox(height: 20),
          _buildLanguageLabel('SOURCE LANGUAGE', theme),
          const SizedBox(height: 8),
          _buildLanguageSelector(
            theme: theme,
            value: _sourceLanguage,
            hint: 'What language is this video in?',
            enabled: !_isUploading,
            onTap: _isUploading ? null : () => _showLanguagePicker(
              theme: theme,
              title: 'Source language',
              options: _languages,
              current: _sourceLanguage,
              onSelected: (lang) => setState(() {
                _sourceLanguage = lang;
                if (_targetLanguage == lang) _targetLanguage = null;
              }),
            ),
          ),
          const SizedBox(height: 16),
          _buildLanguageLabel('TARGET LANGUAGE', theme),
          const SizedBox(height: 8),
          _buildLanguageSelector(
            theme: theme,
            value: _targetLanguage,
            hint: _sourceLanguage == null ? 'Select source language first' : 'Select target language',
            enabled: _sourceLanguage != null && !_isUploading,
            onTap: (_sourceLanguage == null || _isUploading) ? null : () => _showLanguagePicker(
              theme: theme,
              title: 'Target language',
              options: _targetLanguages,
              current: _targetLanguage,
              onSelected: (lang) => setState(() => _targetLanguage = lang),
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: canSend ? () => _sendForDubbing(theme) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: canSend ? AppColors.purple : theme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: canSend ? AppColors.purple : theme.border, width: 0.5),
              ),
              child: Center(
                child: _isUploading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Send for dubbing',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500,
                            color: canSend ? Colors.white : theme.textFaint)),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildLanguageLabel(String label, ThemeProvider theme) {
    return Text(label,
        style: TextStyle(fontSize: 11, color: theme.textHint, letterSpacing: 0.06, fontWeight: FontWeight.w500));
  }

  Widget _buildLanguageSelector({
    required ThemeProvider theme,
    required String? value,
    required String hint,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: enabled ? theme.surface : theme.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value != null ? AppColors.purple.withOpacity(0.5) : theme.border,
            width: value != null ? 1 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.language_rounded, size: 16,
                color: value != null ? AppColors.purple : enabled ? theme.textHint : theme.textFaint),
            const SizedBox(width: 10),
            Expanded(
              child: Text(value ?? hint,
                  style: TextStyle(fontSize: 14,
                      color: value != null ? theme.text : enabled ? theme.textHint : theme.textFaint)),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, size: 18,
                color: enabled ? theme.textHint : theme.textFaint),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(ThemeProvider theme) {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Real thumbnail or gradient fallback
            if (_thumbReady && _thumbController != null)
              VideoPlayer(_thumbController!)
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: theme.isDarkMode
                        ? [const Color(0xFF1A1A2E), const Color(0xFF2A1A3E)]
                        : [const Color(0xFFEEEDFE), const Color(0xFFDDDBF8)],
                  ),
                ),
              ),

            // Play icon overlay
            if (!_isUploading)
              Center(
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.purple.withOpacity(0.2),
                    border: Border.all(color: AppColors.purple.withOpacity(0.5), width: 1),
                  ),
                  child: const Icon(Icons.play_arrow_rounded, size: 24, color: AppColors.purple),
                ),
              ),

            // File name tag
            Positioned(
              bottom: 10, left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(_selectedVideo!['name'],
                    style: const TextStyle(fontSize: 11, color: Colors.white)),
              ),
            ),

            // Size tag
            Positioned(
              bottom: 10, right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(_selectedVideo!['size'],
                    style: const TextStyle(fontSize: 11, color: Colors.white)),
              ),
            ),

            // Uploading overlay
            if (_isUploading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppColors.purple, strokeWidth: 2),
                      SizedBox(height: 10),
                      Text('Uploading...', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle(ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Video',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w200,
                    fontStyle: FontStyle.italic, color: theme.text, letterSpacing: -1),
              ),
              const TextSpan(
                text: 'Dub',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700,
                    color: AppColors.purple, letterSpacing: -1),
              ),
            ],
          ),
        ),
        const Text('automatic dubbing',
            style: TextStyle(fontSize: 12, color: AppColors.purpleDark, letterSpacing: 0.02)),
      ],
    );
  }
}