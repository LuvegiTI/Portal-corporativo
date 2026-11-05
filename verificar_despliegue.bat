@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul
cd /d "%~dp0"

echo ==============================================================
echo  VERIFICACION DE DESPLIEGUE - PORTAL LUVEGI
echo ==============================================================
echo.

set "BASE=https://portal.luvegi.com/api_luvegi"
set "CURL=curl -s -D - -o NUL -m 30"

rem Cada linea: archivo | version esperada
set "CHECKS[1]=admin_encuestas.php|admin_encuestas.php?action=usuarios|X-Admin-Encuestas-Version: 2026-11-04-V2-ODOO-FOTOS"
set "CHECKS[2]=admin_usuarios.php|admin_usuarios.php?action=listar|X-Admin-Usuarios-Version: 2026-11-04-V2-ODOO-FOTOS"
set "CHECKS[3]=foto_empleado.php|foto_empleado.php?usuario_id=1|X-Foto-Empleado-Version: 2026-11-04-V2"
set "CHECKS[4]=comunicados.php|comunicados.php?action=listar|X-Comunicados-Version: 2026-11-04-V2-REACCIONES"
set "CHECKS[5]=comunicados_common.php|comunicados_common.php|X-Comunicados-Common-Version: 2026-11-04-V2-REACCIONES"
set "CHECKS[6]=odoo_empleados.php|odoo_empleados.php|X-Odoo-Empleados-Version: 2026-11-04-V2-DNI"

set "OK=0"
set "FALTA=0"

for /l %%i in (1,1,6) do (
  set "linea=!CHECKS[%%i]!"
  for /f "tokens=1-3 delims=|" %%a in ("!linea!") do (
    set "archivo=%%a"
    set "ruta=%%b"
    set "esperado=%%c"
  )
  set "cabeceras="
  for /f "tokens=*" %%h in ('!CURL! "!BASE!/!ruta!" 2^>nul ^| findstr /r /c:"^X-"') do (
    set "cabeceras=!cabeceras! %%h"
  )
  echo [!archivo!]
  if "!cabeceras!"=="" (
    echo    SIN CABECERA DE VERSION - el archivo no existe o es de otra version
    set /a FALTA+=1
  ) else (
    echo !cabeceras! | findstr /c:"!esperado!" >nul
    if errorlevel 1 (
      echo    DESACTUALIZADO - se espera: !esperado!
      set /a FALTA+=1
    ) else (
      echo    OK
      set /a OK+=1
    )
  )
  echo.
)

echo ==============================================================
echo  Resultado: !OK! actualizados, !FALTA! por revisar
echo ==============================================================
echo.
echo  Recuerda: ademas de los archivos, hay que EJECUTAR en la base
echo  de datos los scripts .sql de la carpeta php\ (son idempotentes):
echo    - comunicados_schema.sql   (tabla de reacciones)
echo    - encuestas_schema.sql     (modulo de encuestas)
echo    - usuarios_dni.sql         (columna dni en usuarios_app)
echo.
pause
