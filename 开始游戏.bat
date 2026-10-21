@echo off
cd /d "%~dp0"
title Kailuo Night-Weaving - local server
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0serve.ps1"
pause
