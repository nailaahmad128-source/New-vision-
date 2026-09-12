@echo off
setlocal
cd /d "%~dp0"
set "EXE=%CD%\build\windows\x64\runner\Release\pdf_master_tools.exe"
if not exist "%EXE%" (
  echo Windows release build not found. Building it now...
  call "%CD%\BUILD_WINDOWS.bat"
)
if exist "%EXE%" start "" "%EXE%"
