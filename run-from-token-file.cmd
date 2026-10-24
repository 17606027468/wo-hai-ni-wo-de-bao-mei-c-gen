@echo off
chcp 65001 >nul
cd /d "%~dp0"
if not exist "token.txt" (
  echo [X] 找不到 token.txt
  echo     请把 GitHub Token 保存到本文件夹的 token.txt 里再运行。
  echo     路径：%~dp0token.txt
  echo.
  pause
  exit /b 1
)
set /p GITHUB_TOKEN=< "token.txt"
if "%GITHUB_TOKEN%"=="" (
  echo [X] token.txt 是空的，请把 Token 粘贴进去保存。
  echo.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy-to-github.ps1" -NoPause %*
set GITHUB_TOKEN=
echo.
pause
