import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 專門負責「把資料存進手機」和「從手機讀回資料」的工具類別。
///
/// UI 畫面不需要知道資料如何存檔，只要呼叫這裡提供的方法即可。
class SharedPreferencesHelper {
  SharedPreferencesHelper._();

  /// 整個 APP 共用同一個 helper 物件（單例模式）。
  static final SharedPreferencesHelper instance =
      SharedPreferencesHelper._();

  static const String _recordsKey = 'bookkeeping_records';
  static const String _userNameKey = 'bookkeeping_user_name';
  static const String _monthlyBudgetKey = 'bookkeeping_monthly_budget';

  /// 讀取所有收支紀錄。
  ///
  /// 第一次開啟 APP 時，回傳 null；這樣畫面就知道要建立測試資料。
  /// 如果使用者曾經刪光所有紀錄，會回傳空 List，而不是 null。
  Future<List<Map<String, dynamic>>?> readRecords() async {
    final preferences = await SharedPreferences.getInstance();
    final savedText = preferences.getString(_recordsKey);

    if (savedText == null) {
      return null;
    }

    final decodedData = jsonDecode(savedText);
    if (decodedData is! List) {
      return <Map<String, dynamic>>[];
    }

    return decodedData
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  /// 將所有收支紀錄轉成 JSON 文字後存起來。
  Future<void> saveRecords(List<Map<String, dynamic>> records) async {
    final preferences = await SharedPreferences.getInstance();
    final recordsText = jsonEncode(records);
    await preferences.setString(_recordsKey, recordsText);
  }

  /// 讀取使用者名稱；第一次使用時會回傳 null。
  Future<String?> readUserName() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_userNameKey);
  }

  /// 儲存使用者名稱。
  Future<void> saveUserName(String userName) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_userNameKey, userName);
  }

  /// 讀取每月預算；第一次使用時會回傳 null。
  Future<int?> readMonthlyBudget() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getInt(_monthlyBudgetKey);
  }

  /// 儲存每月預算。
  Future<void> saveMonthlyBudget(int amount) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_monthlyBudgetKey, amount);
  }
}
