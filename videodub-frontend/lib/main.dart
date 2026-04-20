import 'package:flutter/material.dart';
import 'splash_screen.dart';
import 'main_shell.dart';
import 'theme_provider.dart';
import 'user_service.dart';
import 'library_service.dart';
import 'notification_service.dart';
import 'background_worker.dart';
import 'api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final userService = await UserService.getInstance();
  await userService.getUserId();
  await ApiService.instance.init();
  await NotificationService.init();
  await BackgroundWorker.init();
  await LibraryService.instance.init();
  if (LibraryService.instance.inProgressJobs.isNotEmpty) {
    await BackgroundWorker.registerPolling();
  }
  runApp(const VideoDubApp());
}

class VideoDubApp extends StatefulWidget {
  const VideoDubApp({super.key});

  @override
  State<VideoDubApp> createState() => _VideoDubAppState();
}

class _VideoDubAppState extends State<VideoDubApp> {
  final ThemeProvider _themeProvider = ThemeProvider();
  bool _themeLoaded = false;

  @override
  void initState() {
    super.initState();
    _themeProvider.loadTheme().then((_) {
      setState(() => _themeLoaded = true);
    });
  }

  @override
  void dispose() {
    _themeProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_themeLoaded) return const SizedBox.shrink();
    return ThemeScope(
      provider: _themeProvider,
      child: ListenableBuilder(
        listenable: _themeProvider,
        builder: (context, _) {
          return MaterialApp(
            title: 'VideoDub',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: _themeProvider.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,
            home: const AppEntry(),
          );
        },
      ),
    );
  }
}

class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  bool _showSplash = true;

  void _onSplashComplete() {
    setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(onComplete: _onSplashComplete);
    }
    return const MainShell();
  }
}