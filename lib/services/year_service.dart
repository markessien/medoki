import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/year.dart';

class YearService {
  static const String _storageKey = 'years';
  final SharedPreferences _prefs;

  YearService(this._prefs);

  static Future<YearService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return YearService(prefs);
  }

  List<Year> getYears() {
    final String? yearsJson = _prefs.getString(_storageKey);
    if (yearsJson == null) {
      // Initialize with default years if none exist
      final defaultYears = [
        Year(id: '2023', name: '2023', createdAt: DateTime.now()),
        Year(id: '2024', name: '2024', createdAt: DateTime.now()),
        Year(id: '2025', name: '2025', createdAt: DateTime.now()),
      ];
      saveYears(defaultYears);
      return defaultYears;
    }

    final List<dynamic> yearsList = json.decode(yearsJson);
    // return yearsList.map((json) => Year.fromJson(json)).toList();
    final years = yearsList.map((json) => Year.fromJson(json)).toList();
    years.sort((a, b) => int.parse(b.name).compareTo(int.parse(a.name)));

    return years;
  }

  Future<void> saveYears(List<Year> years) async {
    final String yearsJson = json.encode(
      years.map((year) => year.toJson()).toList(),
    );
    await _prefs.setString(_storageKey, yearsJson);
  }

  Future<void> addYear(Year year) async {
    final years = getYears();
    years.add(year);
    await saveYears(years);
  }

  Future<void> removeYear(String id) async {
    final years = getYears();
    years.removeWhere((year) => year.id == id);
    await saveYears(years);
  }
}
