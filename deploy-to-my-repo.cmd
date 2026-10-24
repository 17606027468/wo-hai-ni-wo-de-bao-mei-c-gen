@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo ================================================
echo   Deploy "cost calculator" to:
echo   github.com/17606027468/wo-hai-ni-wo-de-bao-mei-c-gen
echo ================================================
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy-to-github.ps1" -RepoName "wo-hai-ni-wo-de-bao-mei-c-gen" -Username "17606027468" -NoPause %*
echo.
pause
