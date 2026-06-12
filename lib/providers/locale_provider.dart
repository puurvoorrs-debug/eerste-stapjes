import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocaleProvider with ChangeNotifier {
  static const String _localePrefKey = 'selected_locale';

  Locale _locale = const Locale('nl');

  LocaleProvider() {
    _loadLocaleFromPrefs();
  }

  Locale get locale => _locale;

  bool get isDutch => _locale.languageCode == 'nl';

  Future<void> _loadLocaleFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final localeStr = prefs.getString(_localePrefKey);
    if (localeStr != null) {
      _locale = Locale(localeStr);
    } else {
      _locale = const Locale('nl');
    }
    notifyListeners();
  }

  Future<void> setLocale(Locale locale, {bool updateFirestore = true}) async {
    if (_locale.languageCode == locale.languageCode) return;
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localePrefKey, locale.languageCode);

    if (updateFirestore) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({'language': locale.languageCode}).catchError((e) =>
                debugPrint('Error updating user language in Firestore: $e'));
      }
    }
  }
}

extension LocalizationExtension on BuildContext {
  String tr(String nl, String en) {
    final localeProvider = Provider.of<LocaleProvider>(this);
    return localeProvider.locale.languageCode == 'en' ? en : nl;
  }
}
