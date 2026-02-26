@echo off
setlocal enabledelayedexpansion

echo Farm Fresh Development Runner
echo ============================
echo.

:: Check if this is a cold start or incremental build
if "%1"=="cold" (
  echo Running COLD build (full rebuild)...
  
  :: Clean Flutter build cache for cold start
  flutter clean
  
  :: Get dependencies
  echo Getting dependencies...
  flutter pub get
  
  :: Start the app with performance flags
  echo Starting app with cold build...
  flutter run --enable-impeller --use-application-binary
) else (
  :: Run incremental build
  echo Running INCREMENTAL build...
  
  :: Skip analysis in dev mode
  set FLUTTER_ARGS=--enable-impeller --no-sound-null-safety --fast-start --dart-define=Dart.vm.product=false
  
  :: If performance flag is set, add additional performance optimization flags
  if "%1"=="perf" (
    echo [Performance mode enabled]
    set FLUTTER_ARGS=!FLUTTER_ARGS! --enable-software-rendering --profile --release --no-tree-shake-icons
  )
  
  :: Start with cached Hot Reload session if possible
  flutter run !FLUTTER_ARGS!
)

echo.
echo Build completed.
endlocal 