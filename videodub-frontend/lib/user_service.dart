import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class UserService {
  static const _keyUserId = 'user_id';
  static UserService? _instance;
  static SharedPreferences? _prefs;

  UserService._();

  static Future<UserService> getInstance() async {
    _instance ??= UserService._();
    _prefs ??= await SharedPreferences.getInstance();
    return _instance!;
  }

  // Gets existing user ID or generates a new one on first launch
  Future<String> getUserId() async {
    final existing = _prefs!.getString(_keyUserId);
    if (existing != null && existing.isNotEmpty) return existing;
    final newId = _generateUserId();
    await _prefs!.setString(_keyUserId, newId);
    return newId;
  }

  // Only called from settings reset — wipes ID and generates fresh one
  Future<String> resetUserId() async {
    final newId = _generateUserId();
    await _prefs!.setString(_keyUserId, newId);
    return newId;
  }

  String _generateUserId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    final part1 = List.generate(4, (_) => chars[rand.nextInt(chars.length)]).join();
    final part2 = List.generate(4, (_) => chars[rand.nextInt(chars.length)]).join();
    final part3 = List.generate(4, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'VD-$part1-$part2-$part3';
  }
}