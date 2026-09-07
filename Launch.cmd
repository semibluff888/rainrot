@echo off
setlocal
cd /d "%~dp0"
set "RAINROT_GODOT=D:\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe"
if not exist "%RAINROT_GODOT%" (
  echo Godot was not found at the configured path.
  echo Edit RAINROT_GODOT in Launch.cmd or import project.godot in Godot 4.7.1.
  pause
  exit /b 1
)
if not exist ".godot\global_script_class_cache.cfg" (
  echo Preparing RAINROT assets. First launch can take a minute.
  "%RAINROT_GODOT%" --headless --editor --import --path "%~dp0."
)
start "RAINROT" "%RAINROT_GODOT%" --path "%~dp0."
exit /b 0
