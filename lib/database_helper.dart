import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseHelper {
  static Future<void> saveUserData(String name, String email, String password, String avatar) async {
    final prefs = await SharedPreferences.getInstance();

    List<Map<String, dynamic>> userList = [];
    String? existingUsersRaw = prefs.getString('all_registered_users');

    if (existingUsersRaw != null) {
      List<dynamic> decodedList = jsonDecode(existingUsersRaw);
      userList = decodedList.map((item) => Map<String, dynamic>.from(item)).toList();
    }

    Map<String, dynamic> newUser = {
      'name': name,
      'email': email,
      'password': password,
      'avatar': avatar
    };

    int existingIndex = userList.indexWhere((user) => user['email'] == email);
    if (existingIndex != -1) {
      userList[existingIndex] = newUser;
    } else {
      userList.add(newUser);
    }

    await prefs.setString('all_registered_users', jsonEncode(userList));
  }

  static Future<Map<String, String>?> findUser(String email) async {
    final prefs = await SharedPreferences.getInstance();
    String? existingUsersRaw = prefs.getString('all_registered_users');

    if (existingUsersRaw == null) return null;

    List<dynamic> decodedList = jsonDecode(existingUsersRaw);
    for (var item in decodedList) {
      if (item['email'] == email) {
        return {
          'name': item['name'] ?? 'User',
          'email': item['email'] ?? '',
          'password': item['password'] ?? '',
          'avatar': item['avatar'] ?? '',
        };
      }
    }
    return null;
  }
}