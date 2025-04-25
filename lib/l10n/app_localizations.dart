import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const _localizedValues = <String, Map<String, String>>{
    'en': {
      'appTitle': 'Medoki',
      'slogan': 'Privately Analyse Your Medical Documents with AI',
      'settings': 'Settings',
      'storage': 'Storage',
      'account': 'Account',
      'email': 'Email',
      'password': 'Password',
      'login': 'Login',
      'createAccount': 'Create Account',
      'createAccountTitle': 'Create Account',
      'confirmPassword': 'Confirm Password',
      'cancel': 'Cancel',
      'create': 'Create',
      'chatAnalysisHint': 'chat about the analysis report',
      'chatDocumentHint': 'chat with your medical documents',
      'selectFileToChat': 'Select a file to chat',
      'medicalRecordsPath': 'Medical Records Path',
      'geminiApiKey': 'Gemini API Key',
      'openAiApiKey': 'OpenAI API Key',
      'save': 'Save',
      'directorySelectionCancelled': 'Directory selection cancelled.',
      'medicalRecordsPathSaved': 'Medical records path saved.',
      'geminiApiKeySaved': 'Gemini API Key saved.',
      'openAiApiKeySaved': 'OpenAI API Key saved.',
      'pleaseFillAllFields': 'Please fill in all fields.',
      'passwordsDoNotMatch': 'Passwords do not match.',
      'accountCreated': 'Account created for',
      'loginAttempted': 'Login attempted for',
    },
    'de': {
      'appTitle': 'Medoki',
      'slogan': 'Analysieren Sie Ihre medizinischen Dokumente privat mit KI',
      'settings': 'Einstellungen',
      'storage': 'Speicher',
      'account': 'Konto',
      'email': 'E-Mail',
      'password': 'Passwort',
      'login': 'Anmelden',
      'createAccount': 'Konto erstellen',
      'createAccountTitle': 'Konto erstellen',
      'confirmPassword': 'Passwort bestätigen',
      'cancel': 'Abbrechen',
      'create': 'Erstellen',
      'chatAnalysisHint': 'über den Analysebericht chatten',
      'chatDocumentHint': 'mit Ihren medizinischen Dokumenten chatten',
      'selectFileToChat': 'Datei zum Chatten auswählen',
      'medicalRecordsPath': 'Pfad zu medizinischen Unterlagen',
      'geminiApiKey': 'Gemini API-Schlüssel',
      'openAiApiKey': 'OpenAI API-Schlüssel',
      'save': 'Speichern',
      'directorySelectionCancelled': 'Verzeichnisauswahl abgebrochen.',
      'medicalRecordsPathSaved':
          'Pfad zu medizinischen Unterlagen gespeichert.',
      'geminiApiKeySaved': 'Gemini API-Schlüssel gespeichert.',
      'openAiApiKeySaved': 'OpenAI API-Schlüssel gespeichert.',
      'pleaseFillAllFields': 'Bitte alle Felder ausfüllen.',
      'passwordsDoNotMatch': 'Passwörter stimmen nicht überein.',
      'accountCreated': 'Konto erstellt für',
      'loginAttempted': 'Anmeldeversuch für',
    },
  };

  String get(String key) {
    return _localizedValues[locale.languageCode]?[key] ??
        _localizedValues['en']![key] ??
        key;
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'de'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}
