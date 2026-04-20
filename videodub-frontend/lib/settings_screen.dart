import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_provider.dart';
import 'user_service.dart';
import 'api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _uidVisible = false;
  String _defaultSourceLanguage = 'English';
  String _defaultDubLanguage = 'Hindi';
  String _userId = '';
  final String _appVersion = 'v0.1.0 prototype';
  String _serverUrl = 'http://192.168.18.3:8000';

  final List<String> _languages = [
    'English', 'Spanish', 'French', 'German', 'Arabic',
    'Hindi', 'Portuguese', 'Japanese', 'Chinese',
    'Italian', 'Russian', 'Turkish', 'Korean',
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final userService = await UserService.getInstance();
    final userId = await userService.getUserId();
    setState(() {
      _defaultSourceLanguage = prefs.getString('default_source_language') ?? 'English';
      _defaultDubLanguage = prefs.getString('default_dub_language') ?? 'Hindi';
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _userId = userId;
      _serverUrl = ApiService.instance.baseUrl;
    });
  }

  Future<void> _savePreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is String) await prefs.setString(key, value);
    if (value is bool) await prefs.setBool(key, value);
  }

  void _copyUserId() {
    Clipboard.setData(ClipboardData(text: _userId));
    _showSnackBar('User ID copied to clipboard');
  }

  void _showSnackBar(String message) {
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

  void _showLanguagePicker({
    required String title,
    required String current,
    required String prefKey,
    required ValueChanged<String> onSelected,
    String? excludeLanguage,
  }) {
    final theme = ThemeScope.of(context);
    final filteredLanguages = excludeLanguage != null
        ? _languages.where((l) => l != excludeLanguage).toList()
        : _languages;
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
                itemCount: filteredLanguages.length,
                itemBuilder: (context, index) {
                  final lang = filteredLanguages[index];
                  final isSelected = lang == current;
                  return ListTile(
                    onTap: () {
                      onSelected(lang);
                      _savePreference(prefKey, lang);
                      Navigator.pop(context);
                    },
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

  void _showServerUrlDialog() {
    final theme = ThemeScope.of(context);
    final controller = TextEditingController(text: _serverUrl);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('API Server URL',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: theme.text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(fontSize: 13, color: theme.text, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'http://192.168.x.x:8000',
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
            const SizedBox(height: 8),
            Text('Enter your server IP and port. Make sure your phone and server are on the same network.',
                style: TextStyle(fontSize: 11, color: theme.textHint, height: 1.5)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: theme.textHint)),
          ),
          TextButton(
            onPressed: () async {
              final url = controller.text.trim();
              if (url.isEmpty) return;
              await ApiService.instance.setBaseUrl(url);
              setState(() => _serverUrl = url);
              if (context.mounted) Navigator.pop(context);
              _showSnackBar('Server URL updated');
            },
            child: const Text('Save',
                style: TextStyle(color: AppColors.purple, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog() {
    final theme = ThemeScope.of(context);
    _showConfirmDialog(
      theme: theme,
      title: 'Clear cache',
      message: 'Removes cached thumbnails and temp files. Your videos and settings are not affected.',
      confirmLabel: 'Clear cache',
      isDanger: false,
      onConfirm: () async {
        try {
          final dir = await getApplicationDocumentsDirectory();
          final cacheDir = Directory('${dir.path}/cache');
          if (await cacheDir.exists()) await cacheDir.delete(recursive: true);
        } catch (_) {}
        _showSnackBar('Cache cleared');
      },
    );
  }

  void _showResetAppDialog() {
    final theme = ThemeScope.of(context);
    _showConfirmDialog(
      theme: theme,
      title: 'Reset app',
      message: 'Wipes everything — your User ID, queue, preferences, and all local data. You will lose access to all your dubbed videos permanently. This cannot be undone.',
      confirmLabel: 'Reset everything',
      isDanger: true,
      onConfirm: () async {
        try {
          // Delete all stored video files
          final dir = await getApplicationDocumentsDirectory();
          final videosDir = Directory('${dir.path}/videos');
          if (await videosDir.exists()) await videosDir.delete(recursive: true);
        } catch (_) {}
        // Clear all preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        // Generate new user ID
        final userService = await UserService.getInstance();
        final newId = await userService.resetUserId();
        setState(() {
          _userId = newId;
          _defaultSourceLanguage = 'English';
          _defaultDubLanguage = 'Hindi';
          _notificationsEnabled = true;
        });
        _showSnackBar('App has been reset');
      },
    );
  }

  void _showConfirmDialog({
    required ThemeProvider theme,
    required String title,
    required String message,
    required String confirmLabel,
    required bool isDanger,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDanger ? AppColors.danger : theme.text)),
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
            child: Text(confirmLabel,
                style: TextStyle(
                    color: isDanger ? AppColors.danger : AppColors.purple,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);

    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text('Settings',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w500,
                        color: theme.text, letterSpacing: -0.3)),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    _SectionLabel(label: 'APPEARANCE', theme: theme),
                    _SettingsCard(theme: theme, children: [
                      Builder(builder: (context) {
                        final t = ThemeScope.of(context);
                        return _ToggleRow(
                          icon: Icons.settings_brightness_rounded,
                          label: 'Theme',
                          subtitle: t.isDarkMode ? 'Dark mode' : 'Light mode',
                          value: t.isDarkMode,
                          onChanged: (_) async {
                            t.toggleTheme();
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('is_dark_mode', t.isDarkMode);
                          },
                          theme: t,
                        );
                      }),
                    ]),

                    const SizedBox(height: 20),

                    _SectionLabel(label: 'ACCOUNT', theme: theme),
                    _SettingsCard(theme: theme, children: [
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              _IconBox(icon: Icons.fingerprint_rounded, theme: theme),
                              const SizedBox(width: 10),
                              Text('User ID',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: theme.text)),
                            ]),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: theme.bg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: theme.border, width: 0.5),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _uidVisible ? _userId : '••••••••••••••••',
                                      style: TextStyle(
                                          fontSize: 13, fontFamily: 'monospace',
                                          color: _uidVisible ? AppColors.teal : theme.textHint,
                                          letterSpacing: 0.5),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => setState(() => _uidVisible = !_uidVisible),
                                    child: Icon(
                                        _uidVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                        size: 18, color: theme.textHint),
                                  ),
                                  const SizedBox(width: 12),
                                  GestureDetector(
                                    onTap: _copyUserId,
                                    child: Icon(Icons.copy_rounded, size: 16, color: theme.textHint),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]),

                    const SizedBox(height: 20),

                    _SectionLabel(label: 'SERVER', theme: theme),
                    _SettingsCard(theme: theme, children: [
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              _IconBox(icon: Icons.dns_rounded, theme: theme),
                              const SizedBox(width: 10),
                              Text('API Server URL',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: theme.text)),
                            ]),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: theme.bg,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: theme.border, width: 0.5),
                                    ),
                                    child: Text(_serverUrl,
                                        style: TextStyle(fontSize: 12, fontFamily: 'monospace',
                                            color: AppColors.teal, letterSpacing: 0.3),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _showServerUrlDialog(),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: AppColors.purple,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text('Change',
                                        style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('Default: http://192.168.18.3:8000',
                                style: TextStyle(fontSize: 10, color: theme.textFaint)),
                          ],
                        ),
                      ),
                    ]),

                    const SizedBox(height: 20),

                    _SectionLabel(label: 'PREFERENCES', theme: theme),
                    _SettingsCard(theme: theme, children: [
                      _ToggleRow(
                        icon: Icons.notifications_rounded,
                        label: 'Notifications',
                        subtitle: 'When video is ready',
                        value: _notificationsEnabled,
                        onChanged: (val) {
                          setState(() => _notificationsEnabled = val);
                          _savePreference('notifications_enabled', val);
                        },
                        theme: theme,
                        hasDivider: true,
                      ),
                      _TappableRow(
                        icon: Icons.record_voice_over_rounded,
                        label: 'Default source language',
                        subtitle: _defaultSourceLanguage,
                        onTap: () => _showLanguagePicker(
                          title: 'Default source language',
                          current: _defaultSourceLanguage,
                          prefKey: 'default_source_language',
                          excludeLanguage: _defaultDubLanguage,
                          onSelected: (lang) => setState(() => _defaultSourceLanguage = lang),
                        ),
                        theme: theme,
                        hasDivider: true,
                      ),
                      _TappableRow(
                        icon: Icons.language_rounded,
                        label: 'Default dubbing language',
                        subtitle: _defaultDubLanguage,
                        onTap: () => _showLanguagePicker(
                          title: 'Default dubbing language',
                          current: _defaultDubLanguage,
                          prefKey: 'default_dub_language',
                          excludeLanguage: _defaultSourceLanguage,
                          onSelected: (lang) => setState(() => _defaultDubLanguage = lang),
                        ),
                        theme: theme,
                      ),
                    ]),

                    const SizedBox(height: 20),

                    _SectionLabel(label: 'MORE', theme: theme),
                    _SettingsCard(theme: theme, children: [
                      _TappableRow(
                        icon: Icons.info_outline_rounded,
                        label: 'About & Help',
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const AboutScreen())),
                        theme: theme,
                        hasDivider: true,
                      ),
                      _TappableRow(
                        icon: Icons.cleaning_services_rounded,
                        label: 'Clear cache',
                        subtitle: 'Removes thumbnails and temp files',
                        onTap: _showClearCacheDialog,
                        theme: theme,
                        hasDivider: true,
                      ),
                      _TappableRow(
                        icon: Icons.delete_forever_rounded,
                        label: 'Reset app',
                        subtitle: 'Wipes everything including your ID',
                        onTap: _showResetAppDialog,
                        theme: theme,
                        isDanger: true,
                      ),
                    ]),

                    const SizedBox(height: 24),
                    Center(
                      child: Text('VideoDub $_appVersion',
                          style: TextStyle(fontSize: 11, color: theme.textFaint)),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Components ────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final ThemeProvider theme;
  const _SectionLabel({required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(label,
          style: TextStyle(fontSize: 11, color: theme.textHint, letterSpacing: 0.08, fontWeight: FontWeight.w500)),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  final ThemeProvider theme;
  const _SettingsCard({required this.children, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border, width: 0.5),
      ),
      child: Column(children: children),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final ThemeProvider theme;
  final bool isDanger;
  const _IconBox({required this.icon, required this.theme, this.isDanger = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30, height: 30,
      decoration: BoxDecoration(
        color: isDanger ? AppColors.danger.withOpacity(0.1) : theme.card,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 16, color: isDanger ? AppColors.danger : AppColors.purple),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final ThemeProvider theme;
  final bool hasDivider;

  const _ToggleRow({
    required this.icon, required this.label, this.subtitle,
    required this.value, required this.onChanged,
    required this.theme, this.hasDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              _IconBox(icon: icon, theme: theme),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: theme.text)),
                    if (subtitle != null)
                      Text(subtitle!, style: TextStyle(fontSize: 11, color: theme.textHint)),
                  ],
                ),
              ),
              Switch(
                value: value, onChanged: onChanged,
                activeColor: AppColors.purple,
                activeTrackColor: AppColors.purple.withOpacity(0.3),
                inactiveThumbColor: theme.textHint,
                inactiveTrackColor: theme.border,
              ),
            ],
          ),
        ),
        if (hasDivider)
          Divider(height: 0.5, thickness: 0.5, color: theme.border, indent: 14, endIndent: 14),
      ],
    );
  }
}

class _TappableRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final ThemeProvider theme;
  final bool isDanger;
  final bool hasDivider;

  const _TappableRow({
    required this.icon, required this.label, this.subtitle,
    required this.onTap, required this.theme,
    this.isDanger = false, this.hasDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDanger ? AppColors.danger : theme.text;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                _IconBox(icon: icon, theme: theme, isDanger: isDanger),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
                      if (subtitle != null)
                        Text(subtitle!, style: TextStyle(fontSize: 11, color: theme.textHint)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 18,
                    color: isDanger ? AppColors.danger.withOpacity(0.5) : theme.textHint),
              ],
            ),
          ),
        ),
        if (hasDivider)
          Divider(height: 0.5, thickness: 0.5, color: theme.border, indent: 14, endIndent: 14),
      ],
    );
  }
}

// ── About Screen ──────────────────────────────────────────────────

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: theme.bg,
      appBar: AppBar(
        backgroundColor: theme.bg, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18, color: AppColors.purple),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('About & Help',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: theme.text)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AboutSection(title: 'What is VideoDub?',
                content: 'VideoDub is an automatic video dubbing app. Upload a video in any language and get it back dubbed in your target language — no manual work needed.',
                theme: theme),
            const SizedBox(height: 24),
            _AboutSection(title: 'How to upload a video',
                content: 'Go to the Upload tab, tap the upload button, and pick a video from your device. Select the source and target language, confirm, and the video is sent to the server. You\'ll get a notification when it\'s ready.',
                theme: theme),
            const SizedBox(height: 24),
            _AboutSection(title: 'Library',
                content: 'The Library has two tabs — In Progress shows videos being processed, Done shows completed videos. Long press any item to reveal actions like rename, download, share, or delete.',
                theme: theme),
            const SizedBox(height: 24),
            _AboutSection(title: 'Player',
                content: 'Tap any completed video in the Library to open the player. Watch the dubbed video, switch between original and dubbed audio, and download to your device.',
                theme: theme),
            const SizedBox(height: 24),
            _AboutSection(title: 'Your User ID',
                content: 'Your User ID is generated when you first install the app. It links your videos to your device. If you reset the app, your ID changes and you lose access to previous videos.',
                theme: theme),
            const SizedBox(height: 40),
            Center(child: Text('VideoDub v0.1.0 prototype',
                style: TextStyle(fontSize: 11, color: theme.textFaint))),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  final String title;
  final String content;
  final ThemeProvider theme;
  const _AboutSection({required this.title, required this.content, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.purple)),
        const SizedBox(height: 8),
        Text(content, style: TextStyle(fontSize: 13, color: theme.textMuted, height: 1.6)),
      ],
    );
  }
}