@echo off
REM Build the Flutter Windows app, create NSIS installer, and move it to Releases/Windows

echo Building Flutter Windows app...
flutter build windows
IF %ERRORLEVEL% NEQ 0 (
    echo Flutter build failed!
    exit /b %ERRORLEVEL%
)

echo Creating NSIS installer...
makensis medoki_installer.nsi
IF %ERRORLEVEL% NEQ 0 (
    echo NSIS installer creation failed!
    exit /b %ERRORLEVEL%
)

REM Create Releases/Windows directory if it doesn't exist
if not exist "Releases\Windows" (
    mkdir "Releases\Windows"
)

REM Move the installer to Releases/Windows
move /Y "Medoki_Setup.exe" "Releases\Windows\Medoki_Setup.exe"

echo Installer has been created and moved to Releases\Windows\Medoki_Setup.exe