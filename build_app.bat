@echo off
echo =======================================
echo        Building WASLA App
echo =======================================

:: Change directory to the Flutter mobile app folder
cd /d "%~dp0\frontend\mobile\wasla"

echo.
echo [1/2] Getting dependencies...
call flutter pub get

echo.
echo [2/2] Building APK...
call flutter build apk

echo.
echo =======================================
echo        Build Complete!
echo =======================================
echo The APK can be found in: frontend\mobile\wasla\build\app\outputs\flutter-apk\
pause
