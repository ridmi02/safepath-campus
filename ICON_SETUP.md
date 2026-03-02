# SafePath Campus - App Icon Setup Guide

## Current Status
✅ Home page redesigned with custom UI  
✅ Material3 theme with 7-color palette implemented  
✅ Splash screen with shield + location pin logo created  
✅ Auto-navigation (7 seconds) working  
✅ All tests passing  

## App Icon Configuration

The `flutter_launcher_icons` package has been configured in `pubspec.yaml` to automatically generate platform-specific app icons for:
- Android (multiple sizes for different densities)
- iOS (multiple sizes for different devices)
- Web (manifest icons)

### Steps to Apply Custom App Icon

**Step 1:** Create your custom icon as a **512×512 PNG image**

Your icon should match the splash screen logo:
- Shield icon (blue #3A86FF)
- Green location pin overlay (green #2ECC71)
- White background

You can create this using:
- [Canva](https://www.canva.com/) - Design tool (export as PNG)
- [Figma](https://www.figma.com/) - Professional design tool
- [GIMP](https://www.gimp.org/) - Free open-source editor
- [Photoshop](https://www.adobe.com/products/photoshop.html)

Or generate programmatically using your preferred image library.

**Step 2:** Place the PNG file at:
```
assets/icon/icon.png
```

The dimensions should be exactly **512×512 pixels** in PNG format.

**Step 3:** Run the icon generator:
```bash
flutter pub get
dart run flutter_launcher_icons
```

This will automatically generate:
- Android icons in `android/app/src/main/res/mipmap-*/`
- iOS icons in `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- Web icons in `web/icons/`

**Step 4:** Rebuild the app:
```bash
flutter clean
flutter run
```

## Color Reference

For creating your custom icon, use these brand colors:
- **Primary Blue**: #3A86FF (RGB: 58, 134, 255)
- **Safe Green**: #2ECC71 (RGB: 46, 204, 113)
- **Background**: #0D1B2A (RGB: 13, 27, 42)
- **White**: #FFFFFF

## Icon Generator Tool

A Dart script has been created at `tools/generate_icon.dart` that can be extended to programmatically generate your custom icon if needed. Currently, it requires proper PNG image processing libraries.

## Quick Reference

- **Splash Logo Location**: [lib/main.dart](lib/main.dart#L80-L90)
- **Flutter Launcher Icons Config**: [pubspec.yaml](pubspec.yaml) - `flutter_launcher_icons` section
- **Android Icons**: `android/app/src/main/res/mipmap-*/ic_launcher.png`
- **iOS Icons**: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- **Web Icons**: `web/icons/Icon-*.png`

## Testing

After applying the custom icon, test on all platforms:
```bash
flutter run     # Android/iOS
flutter run -d chrome  # Web
```

The app badge should now display your custom SafePath shield + location pin logo instead of the default Flutter logo.
