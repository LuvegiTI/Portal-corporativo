@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul
cd /d "%~dp0"

echo ==============================================================
echo  SINCRONIZAR DNI DE USUARIOS CON ODOO (hr.employee)
echo ==============================================================
echo.
echo  Rellena usuarios_app.dni con el identification_id de Odoo.
echo  Con el DNI, el emparejamiento con las fotos del personal y con
echo  los cesados es exacto.
echo.
echo  Es una tarea de mantenimiento: se corre una vez (o cuando se
echo  agreguen empleados nuevos a Odoo).
echo.

set "BASE=https://portal.luvegi.com/api_luvegi"
set "TOKEN="
set /p "TOKEN=Pega aqui tu token de GitHub/portal (Bearer): "

if "%TOKEN%"=="" (
    echo.
    echo [ERROR] No se ingreso token.
    pause
    exit /b 1
)

echo.
echo Sincronizando...
echo.

curl -s -H "Authorization: Bearer %TOKEN%" -H "Accept: application/json" ^
     "%BASE%/admin_usuarios.php?action=sincronizar_dni"

echo.
echo.
echo Si la respuesta dice "ok": true, ya quedo sincronizado.
echo Si dice "FALTA_COLUMNA_DNI", falta ejecutar usuarios_dni.sql en la base.
echo.
pause
