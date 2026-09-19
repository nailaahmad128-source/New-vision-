@echo off
setlocal
cd /d "%~dp0"

set "FLUTTER=C:\src\flutter\bin\flutter.bat"
if not exist "%FLUTTER%" set "FLUTTER=flutter"

where %FLUTTER% >nul 2>nul
if errorlevel 1 (
  echo.
  echo Flutter SDK was not found.
  echo Install Flutter in C:\src\flutter or add Flutter to PATH.
  pause
  exit /b 1
)

echo ==========================================
echo PDF Master Tools - Windows Release Build
echo ==========================================
echo.

echo [1/2] Getting packages...
call "%FLUTTER%" pub get
if errorlevel 1 goto :error

echo.
echo [2/2] Building Windows EXE...
call "%FLUTTER%" build windows --release
if errorlevel 1 goto :error

echo.
echo ==========================================
echo BUILD SUCCESSFUL
echo ==========================================
echo.
echo Release folder:
echo %CD%\build\windows\x64\runner\Release
echo.
start "" explorer "%CD%\build\windows\x64\runner\Release"
pause
exit /b 0

:error
echo.
echo ==========================================
echo BUILD FAILED
echo ==========================================
echo.
echo Send me the error shown above.
pause
exit /b 1
