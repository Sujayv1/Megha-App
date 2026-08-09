import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String farmLocation;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.farmLocation,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'farmLocation': farmLocation,
        'createdAt': createdAt.toIso8601String(),
      };

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '1',
      fullName: json['fullName']?.toString() ?? 'Farmer',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      farmLocation: json['farmLocation']?.toString() ?? 'India',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class AuthStorageService {
  AuthStorageService._();
  static final AuthStorageService instance = AuthStorageService._();

  static const String _keyIsLoggedIn = 'farmsense_is_logged_in';
  static const String _keyCurrentUser = 'farmsense_current_user';
  static const String _keyRegisteredUsers = 'farmsense_registered_users';

  /// Checks if a user is currently logged in.
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  /// Gets the currently logged in user profile.
  Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyCurrentUser);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return UserModel.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Performs user authentication (login).
  Future<UserModel> login({
    required String identifier, // email or phone
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final registeredStr = prefs.getStringList(_keyRegisteredUsers) ?? [];

    for (final str in registeredStr) {
      try {
        final map = jsonDecode(str) as Map<String, dynamic>;
        final storedEmail = map['email']?.toString().toLowerCase() ?? '';
        final storedPhone = map['phone']?.toString().trim() ?? '';
        final query = identifier.trim().toLowerCase();

        if (query == storedEmail || query == storedPhone) {
          final user = UserModel.fromJson(map);
          await prefs.setBool(_keyIsLoggedIn, true);
          await prefs.setString(_keyCurrentUser, jsonEncode(user.toJson()));
          return user;
        }
      } catch (_) {}
    }

    // Default mock user if logging in first time
    final defaultUser = UserModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fullName: 'Farmer User',
      email: identifier.contains('@') ? identifier : 'farmer@farmsense.ai',
      phone: identifier.contains('@') ? '+91 9876543210' : identifier,
      farmLocation: 'Punjab, India',
      createdAt: DateTime.now(),
    );

    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyCurrentUser, jsonEncode(defaultUser.toJson()));
    return defaultUser;
  }

  /// Registers a new user (signup).
  Future<UserModel> signup({
    required String fullName,
    required String email,
    required String phone,
    required String farmLocation,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final newUser = UserModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fullName: fullName,
      email: email,
      phone: phone,
      farmLocation: farmLocation,
      createdAt: DateTime.now(),
    );

    final registeredStr = prefs.getStringList(_keyRegisteredUsers) ?? [];
    registeredStr.add(jsonEncode(newUser.toJson()));
    await prefs.setStringList(_keyRegisteredUsers, registeredStr);

    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyCurrentUser, jsonEncode(newUser.toJson()));

    return newUser;
  }

  /// Logs out current user session.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, false);
    await prefs.remove(_keyCurrentUser);
  }
}
