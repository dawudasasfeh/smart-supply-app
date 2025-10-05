# Language System Setup Instructions

## ✅ What's Ready:
- Language localization files (English & Arabic)
- Language provider for state management  
- Language selector widgets
- Settings page integration

## 🔧 To Enable Language Switching:

### 1. Update `main.dart` - Add Import:
```dart
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/language_provider.dart';
import 'l10n/app_localizations.dart';
```

### 2. Wrap Your App with LanguageProvider:

Find your `MaterialApp` widget and wrap it like this:

```dart
void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()), // Your existing provider
        ChangeNotifierProvider(create: (_) => LanguageProvider()), // Add this
        // ... other providers
      ],
      child: const MyApp(),
    ),
  );
}
```

### 3. Update MaterialApp in `main.dart`:

```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return MaterialApp(
          title: 'Smart Supply',
          
          // Add these localization settings:
          locale: languageProvider.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', ''), // English
            Locale('ar', ''), // Arabic
          ],
          
          // Your existing theme settings:
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: context.watch<ThemeProvider>().themeMode,
          
          // Rest of your app...
        );
      },
    );
  }
}
```

### 4. Add flutter_localizations dependency:

In `pubspec.yaml`, ensure you have:
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
```

Then run: `flutter pub get`

## 🎉 After Setup:

The language selector in Settings will work! Users can switch between:
- 🇬🇧 English (Left-to-Right)
- 🇸🇦 Arabic (Right-to-Left with full RTL support)

The selection will persist across app restarts!
