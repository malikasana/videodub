import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'settings_screen.dart';
import 'library_screen.dart';
import 'upload_screen.dart';
import 'theme_provider.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    UploadScreen(),
    LibraryScreen(),
    SettingsScreen(),
  ];

  void _onTabTapped(int index) {
    HapticFeedback.lightImpact();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: theme.bg,
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(top: BorderSide(color: theme.border, width: 0.5)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              _NavItem(index: 0, currentIndex: currentIndex, label: 'Upload', icon: _NavIcon.upload, onTap: onTap),
              _NavItem(index: 1, currentIndex: currentIndex, label: 'Library', icon: _NavIcon.library, onTap: onTap),
              _NavItem(index: 2, currentIndex: currentIndex, label: 'Settings', icon: _NavIcon.settings, onTap: onTap),
            ],
          ),
        ),
      ),
    );
  }
}

enum _NavIcon { upload, library, settings }

class _NavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final String label;
  final _NavIcon icon;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final isActive = index == currentIndex;
    final color = isActive ? AppColors.purple : theme.textHint;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              width: isActive ? 20 : 0,
              height: 2,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: AppColors.purple,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _buildIcon(color, isActive),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
                color: color,
                letterSpacing: 0.3,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(Color color, bool isActive) {
    switch (icon) {
      case _NavIcon.upload:
        return _UploadNavIcon(color: color, key: ValueKey(isActive));
      case _NavIcon.library:
        return _LibraryNavIcon(color: color, key: ValueKey(isActive));
      case _NavIcon.settings:
        return _SettingsNavIcon(color: color, key: ValueKey(isActive));
    }
  }
}

class _UploadNavIcon extends StatelessWidget {
  final Color color;
  const _UploadNavIcon({required this.color, super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _UploadIconPainter(color: color)),
    );
  }
}

class _UploadIconPainter extends CustomPainter {
  final Color color;
  _UploadIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width / 2;
    canvas.drawLine(Offset(cx, size.height * 0.58), Offset(cx, size.height * 0.18), paint);
    canvas.drawLine(Offset(cx, size.height * 0.18), Offset(cx - size.width * 0.22, size.height * 0.4), paint);
    canvas.drawLine(Offset(cx, size.height * 0.18), Offset(cx + size.width * 0.22, size.height * 0.4), paint);
    canvas.drawRRect(
      RRect.fromLTRBR(size.width * 0.15, size.height * 0.72, size.width * 0.85, size.height * 0.88, const Radius.circular(3)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_UploadIconPainter old) => old.color != color;
}

class _LibraryNavIcon extends StatelessWidget {
  final Color color;
  const _LibraryNavIcon({required this.color, super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _LibraryIconPainter(color: color)),
    );
  }
}

class _LibraryIconPainter extends CustomPainter {
  final Color color;
  _LibraryIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    const r = Radius.circular(2.5);
    final w = size.width;
    final h = size.height;
    canvas.drawRRect(RRect.fromLTRBR(w * 0.1, h * 0.1, w * 0.46, h * 0.46, r), paint);
    canvas.drawRRect(RRect.fromLTRBR(w * 0.54, h * 0.1, w * 0.9, h * 0.46, r), paint);
    canvas.drawRRect(RRect.fromLTRBR(w * 0.1, h * 0.54, w * 0.46, h * 0.9, r), paint);
    canvas.drawRRect(RRect.fromLTRBR(w * 0.54, h * 0.54, w * 0.9, h * 0.9, r), paint);
  }

  @override
  bool shouldRepaint(_LibraryIconPainter old) => old.color != color;
}

class _SettingsNavIcon extends StatelessWidget {
  final Color color;
  const _SettingsNavIcon({required this.color, super.key});

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.settings_rounded, color: color, size: 22);
  }
}