@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"

echo ==============================
echo  BUILD WEB PRODUCCION - LUVEGI
echo ==============================
echo.

echo [1/4] Verificando codigo (flutter analyze)...
rem Solo los ERRORES bloquean el build. Los avisos e infos no.
rem Asi el build nunca sube codigo roto a produccion.
call flutter analyze --no-fatal-infos --no-fatal-warnings
if errorlevel 1 (
    echo.
    echo [ERROR] Hay errores de analisis. No se compila ni se sube nada.
    echo         Revisa los archivos marcados en rojo en el IDE.
    pause
    exit /b 1
)

echo [2/4] Renovando version ?v= del bootstrap (cache-busting)...
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "Get-Date -Format 'yyyyMMddHHmmss'"`) do set "VER=%%i"
if "%VER%"=="" set "VER=1"
powershell -NoProfile -Command "$f='web\index.html'; (Get-Content $f -Raw) -replace '\?v=\d+', ('?v=%VER%') | Set-Content $f -NoNewline"
echo       version nueva: %VER%

echo [3/4] Compilando Flutter Web (release)...
rem --no-tree-shake-icons incluye TODOS los iconos en la fuente MaterialIcons.
rem Evita que iconos nuevos aparezcan en blanco en produccion.
call flutter build web --release --no-tree-shake-icons
if errorlevel 1 (
    echo.
    echo [ERROR] El build de Flutter fallo. No se sube nada.
    pause
    exit /b 1
)

echo [4/4] Comprimiendo main.dart.js.gzip...
if not exist build\web\main.dart.js (
    echo [ERROR] No existe build\web\main.dart.js
    pause
    exit /b 1
)

set "GZIP_EXE=%ProgramFiles%\Git\usr\bin\gzip.exe"
if not exist "%GZIP_EXE%" (
    set "GZIP_EXE_WOW6432=%ProgramFiles(x86)%\Git\usr\bin\gzip.exe"
    if exist "%GZIP_EXE_WOW6432%" set "GZIP_EXE=%GZIP_EXE_WOW6432%"
)
if not exist "%GZIP_EXE%" (
    set "GZIP_EXE=%~dp0..\usr\bin\gzip.exe"
)
if not exist "%GZIP_EXE%" (
    where gzip >nul 2>&1 && set "GZIP_EXE=gzip"
)
if not exist "%GZIP_EXE%" (
    echo.
    echo [ERROR] No se encontro gzip.exe. Instala Git para Windows o
    echo         indica la ruta en la variable GZIP_EXE de este script.
    pause
    exit /b 1
)

"%GZIP_EXE%" -k -f build\web\main.dart.js
if errorlevel 1 (
    echo.
    echo [ERROR] gzip fallo al comprimir.
    pause
    exit /b 1
)

echo.
echo ==============================
echo  BUILD TERMINADO CON EXITO
echo ==============================
echo.
echo Archivos a subir (build\web):
echo   - main.dart.js
echo   - main.dart.js.gz   (nuevo comprimido)
echo   - flutter_bootstrap.js
echo   - flutter_service_worker.js  (OBLIGATORIO: invalida cache)
echo   - index.html (con viewport)
echo   - version.json
echo   - .htaccess (copia sola desde web\)
echo   - assets\           (OBLIGATORIO: fuentes e iconos)
echo   - canvaskit\
echo.
echo Sube la carpeta build\web COMPLETA (sin assets.zip)
echo Tras subir, recarga con "Vaciar cache" para descartar el
echo service worker y la fuente de iconos anterior.
echo.
pause