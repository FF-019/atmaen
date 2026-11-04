# Atma'en mobile (Flutter)

Arabic, right-to-left app for parents and medical volunteers.

## Run

The `android/` and `ios/` folders aren't committed (they're generated). First time only:

```bash
cd mobile
flutter create . --platforms=android,ios --org sa.atmaen --project-name atmaen
flutter pub get
```

Then add the permissions below and run against your local API:

```bash
# android emulator -> host machine
flutter run --dart-define=API_URL=http://10.0.2.2:8000
# real phone on the same wifi
flutter run --dart-define=API_URL=http://192.168.1.20:8000
```

Demo accounts (after `python -m scripts.seed --demo` on the backend):

| role      | email             | password  |
|-----------|-------------------|-----------|
| parent    | parent@demo.sa    | Demo@1234 |
| volunteer | volunteer@demo.sa | Demo@1234 |

## Permissions

`android/app/src/main/AndroidManifest.xml`, inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<queries>
  <intent><action android:name="android.intent.action.DIAL"/><data android:scheme="tel"/></intent>
  <intent><action android:name="android.intent.action.SENDTO"/><data android:scheme="sms"/></intent>
  <intent><action android:name="android.intent.action.TTS_SERVICE"/></intent>
</queries>
```

For local http during development add `android:usesCleartextTraffic="true"` on `<application>`.

`ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>لمسح باركود العبوة أو تصويرها</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>لإرسال موقعك للإسعاف وإظهار أقرب مستشفى</string>
<key>LSApplicationQueriesSchemes</key>
<array><string>tel</string><string>sms</string></array>
```

## Structure

```
lib/
  core/        api client, app state, offline store (sqflite), theme
  models/      plain data classes
  features/
    auth/        welcome, login, register (parent / volunteer)
    emergency/   identify (text, barcode, photo), guidance + text-to-speech, nearest hospital
    consult/     live chat with the volunteer (websocket + polling fallback)
    children/    child profiles
    library/     offline first aid library
    volunteer/   case queue, service hours
    profile/
```

## Offline

`assets/offline/bundle.json` ships inside the app, so the emergency steps and the library
work from the very first launch with no internet. The app refreshes it from
`/api/offline/bundle` when the version changes. Cases opened while offline are queued and
sent when the connection comes back.

Regenerate the bundled copy after editing protocols or chemicals:

```bash
cd backend && python -m scripts.export_offline_bundle ../mobile/assets/offline/bundle.json
```
