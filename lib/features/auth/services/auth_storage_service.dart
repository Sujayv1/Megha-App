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
      farmLocation: json['farmLocation']?.toString() ?? 'Main Farm',
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

  /// Performs user authentication (login) against locally registered users.
  Future<UserModel> login({
    required String identifier,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final registeredStr = prefs.getStringList(_keyRegisteredUsers) ?? [];
    final cleanId = identifier.trim().toLowerCase();
    final cleanPass = password.trim();

    for (final str in registeredStr) {
      try {
        final map = jsonDecode(str) as Map<String, dynamic>;
        final storedEmail = (map['email']?.toString() ?? '').trim().toLowerCase();
        final storedPass = (map['password']?.toString() ?? '').trim();

        if (storedEmail == cleanId) {
          if (storedPass.isNotEmpty && storedPass != cleanPass) {
            throw Exception('Incorrect password. Please try again.');
          }
          final user = UserModel.fromJson(map);
          await prefs.setBool(_keyIsLoggedIn, true);
          await prefs.setString(_keyCurrentUser, jsonEncode(user.toJson()));
          return user;
        }
      } catch (e) {
        if (e is Exception && e.toString().contains('Incorrect password')) {
          rethrow;
        }
      }
    }

    if (registeredStr.isEmpty) {
      // First-time fallback user if no registered accounts exist yet
      final defaultUser = UserModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fullName: 'Farmer User',
        email: cleanId.contains('@') ? cleanId : 'farmer@farmsense.ai',
        phone: '+91 9876543210',
        farmLocation: 'Main Farm',
        createdAt: DateTime.now(),
      );
      await prefs.setBool(_keyIsLoggedIn, true);
      await prefs.setString(_keyCurrentUser, jsonEncode(defaultUser.toJson()));
      return defaultUser;
    }

    throw Exception('No account found for $identifier. Please create an account.');
  }

  /// Registers a new user and persists in app storage.
  /// Does NOT automatically log in, so user is redirected to LoginScreen.
  Future<UserModel> signup({
    required String fullName,
    required String email,
    required String password,
    String phone = '',
    String farmLocation = 'Main Farm',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanEmail = email.trim().toLowerCase();
    final cleanPass = password.trim();

    final registeredStr = prefs.getStringList(_keyRegisteredUsers) ?? [];

    // Check if account already exists
    for (final str in registeredStr) {
      try {
        final map = jsonDecode(str) as Map<String, dynamic>;
        if ((map['email']?.toString() ?? '').trim().toLowerCase() == cleanEmail) {
          throw Exception('An account with $email already exists. Please sign in.');
        }
      } catch (e) {
        if (e is Exception && e.toString().contains('already exists')) {
          rethrow;
        }
      }
    }

    final newUser = UserModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fullName: fullName.trim(),
      email: cleanEmail,
      phone: phone.trim(),
      farmLocation: farmLocation.trim(),
      createdAt: DateTime.now(),
    );

    final userMap = newUser.toJson();
    userMap['password'] = cleanPass;

    registeredStr.add(jsonEncode(userMap));
    await prefs.setStringList(_keyRegisteredUsers, registeredStr);

    return newUser;
  }

  /// Logs out current user session.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, false);
    await prefs.remove(_keyCurrentUser);
  }
}
