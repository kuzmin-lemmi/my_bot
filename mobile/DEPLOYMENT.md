# FocusDay Mobile - Руководство по деплою

## Требования
- Flutter SDK 3.0+
- Android Studio или VS Code с Flutter плагином
- Android SDK (API 21+)
- Физическое устройство или эмулятор Android

## Настройка проекта

### 1. Установка зависимостей
```bash
cd mobile
flutter pub get
```

### 2. Конфигурация Backend
Отредактируйте `lib/main.dart`:
```dart
const String baseUrl = 'http://YOUR_BACKEND_URL:8000';
const String token = 'YOUR_MVP_TOKEN';
```

**Примечания**:
- Для эмулятора Android используйте `http://10.0.2.2:8000` (localhost эмулятора)
- Для реального устройства используйте IP-адрес компьютера в локальной сети (например, `http://192.168.1.100:8000`)
- Убедитесь, что Backend запущен и доступен

### 3. Запуск в режиме разработки
```bash
flutter run
```

## Деплой релизной версии (APK)

### 1. Сборка релизного APK
```bash
flutter build apk --release
```

Готовый APK будет находиться в:
```
build/app/outputs/flutter-apk/app-release.apk
```

### 2. Установка на устройство
```bash
flutter install
```

Или вручную скопируйте APK на устройство и установите.

## Подписание APK (для Production)

### 1. Создайте keystore
```bash
keytool -genkey -v -keystore ~/key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias key
```

### 2. Создайте файл `android/key.properties`
```
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=key
storeFile=/path/to/key.jks
```

### 3. Обновите `android/app/build.gradle`
Добавьте перед блоком `android`:
```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    ...
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

### 4. Соберите подписанный APK
```bash
flutter build apk --release
```

## Проверка работы уведомлений

### 1. Проверьте разрешения
При первом запуске приложение запросит:
- Разрешение на отправку уведомлений
- Разрешение на точные будильники (Exact Alarms)

### 2. Тестирование
1. Создайте цель на сегодня
2. Убедитесь, что текущее время находится в active window (по умолчанию 09:00-21:00)
3. Уведомление должно прийти через interval_minutes (по умолчанию 30 минут)

### 3. Отладка уведомлений
- Проверьте настройки системы: Settings → Apps → FocusDay → Notifications
- Убедитесь, что уведомления не заблокированы Do Not Disturb режимом
- Проверьте логи: `flutter logs`

## Типичные проблемы

### Уведомления не приходят
- Проверьте, что разрешения предоставлены
- Убедитесь, что есть активные цели на сегодня
- Проверьте, что текущее время в active window
- Убедитесь, что нет global pause

### Backend недоступен
- Проверьте, что Backend запущен: `curl http://localhost:8000/health`
- Для эмулятора используйте `10.0.2.2` вместо `localhost`
- Для реального устройства проверьте, что устройство и компьютер в одной сети

### Ошибки сборки
- Выполните `flutter clean && flutter pub get`
- Проверьте версию Flutter: `flutter doctor`
- Убедитесь, что Android SDK установлен корректно

## Мониторинг в Production

### Логи
```bash
flutter logs
# или через adb
adb logcat | grep flutter
```

### Crash reports
Для production рекомендуется интегрировать:
- Firebase Crashlytics
- Sentry

## Обновление приложения

### 1. Увеличьте версию в pubspec.yaml
```yaml
version: 1.0.1+2  # format: major.minor.patch+buildNumber
```

### 2. Соберите новый APK
```bash
flutter build apk --release
```

### 3. Распространите обновление
- Вручную (копирование APK)
- Или через Google Play Store (требует регистрации разработчика)

## Рекомендации по Production

1. **Настройте правильный baseUrl** — не используйте localhost/10.0.2.2
2. **Используйте HTTPS** для Backend API
3. **Защитите MVP_TOKEN** — не храните в коде (используйте .env или секретные переменные)
4. **Настройте мониторинг** — логи, краши, аналитика
5. **Тестируйте на реальных устройствах** — разные версии Android ведут себя по-разному с фоновыми задачами
6. **Оптимизируйте батарею** — слишком частые уведомления могут привести к разряду батареи
