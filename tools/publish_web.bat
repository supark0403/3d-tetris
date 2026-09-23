@echo off
REM 3D Tetris 웹 배포: 로컬 export -> orphan gh-pages 브랜치로 푸시
setlocal
set PROJ=E:\Godot\hrj-godot
set OUT=%PROJ%\build\web
if not exist "%OUT%" mkdir "%OUT%"
echo [1/3] Godot web export...
"E:\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path "%PROJ%" --export-release Web "%OUT%\index.html"
if errorlevel 1 exit /b 1
set CLONE=%TEMP%\tetris-pages
echo [2/3] gh-pages 브랜치 구성...
if exist "%CLONE%" rmdir /s /q "%CLONE%"
git clone -q "%PROJ%" "%CLONE%"
if errorlevel 1 exit /b 1
cd /d "%CLONE%"
git config user.name "supark0403"
git config user.email "supark0403@users.noreply.github.com"
git checkout -q --orphan gh-pages
git rm -rf -q . >nul
xcopy "%OUT%" . /E /Y /Q >nul
git add -A
git commit -q -m "web build"
echo [3/3] push...
git push -f -q origin gh-pages
if errorlevel 1 exit /b 1
echo DONE: https://supark0403.github.io/3d-tetris/
