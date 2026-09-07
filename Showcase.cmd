@echo off
setlocal
cd /d "%~dp0"
set "APPDATA=%~dp0.runtime"
"D:\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe" --path "%~dp0." --fixed-fps 30 -- --enemy-showcase
