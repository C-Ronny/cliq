# Cliq





For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

app

presentation/navigation/routes.dart
- defined all routing systems


### Permissions for image library and camera usage

iOS 
// ios/Runner/Info.plist
<key>NSCameraUsageDescription</key>
<string>We need access to your camera to take profile pictures.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photo library to select profile pictures.</string>

Android
// android/app/src/main/AndroidManifest.xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>