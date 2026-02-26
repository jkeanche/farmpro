@echo off
echo Starting Farm Fresh in development mode...

:: Use special flags to speed up development builds
flutter run --enable-software-rendering --enable-impeller --no-sound-null-safety --fast-start --dart-define=Dart.vm.product=false 