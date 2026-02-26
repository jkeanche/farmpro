@echo off
echo Cleaning Flutter build cache...

:: Stop any running Flutter processes
taskkill /f /im dart.exe 2>nul
taskkill /f /im flutter.exe 2>nul
taskkill /f /im java.exe 2>nul

:: Clean Flutter cache
flutter clean

:: Delete specific cache folders
echo Cleaning Gradle cache...
rmdir /s /q "%USERPROFILE%\.gradle\caches\modules-2\files-2.1\io.flutter" 2>nul
rmdir /s /q "%USERPROFILE%\.gradle\caches\modules-2\metadata-2.97\descriptors\io.flutter" 2>nul
rmdir /s /q "%USERPROFILE%\.gradle\daemon" 2>nul

:: Clear pub cache for Flutter packages
echo Cleaning Pub cache...
flutter pub cache clean
flutter pub get

echo Done! Build system optimized. 