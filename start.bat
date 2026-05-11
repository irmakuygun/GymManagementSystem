@echo off
REM Gym Management System - Windows kurulum + baslatma scripti
REM Kullanim: Klasore git, terminalde:  .\start.bat   (veya:  .\start)

setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "APP_DIR=%SCRIPT_DIR%app"
set "DB_DIR=%SCRIPT_DIR%database"

REM --- Python bul ---
where py >nul 2>&1 && (set "PYTHON=py -3") || (
    where python >nul 2>&1 || goto :no_python
    set "PYTHON=python"
)

REM --- MySQL bul: once PATH, sonra C:\Program Files\MySQL\... ---
set "MYSQL_EXE=mysql"
where mysql >nul 2>&1
if !errorlevel! neq 0 (
    set "MYSQL_EXE="
    for /f "delims=" %%i in ('dir /b /ad "C:\Program Files\MySQL" 2^>nul ^| findstr /b "MySQL Server"') do (
        if exist "C:\Program Files\MySQL\%%i\bin\mysql.exe" set "MYSQL_EXE=C:\Program Files\MySQL\%%i\bin\mysql.exe"
    )
    if "!MYSQL_EXE!"=="" (
        for /f "delims=" %%i in ('dir /b /ad "C:\Program Files (x86)\MySQL" 2^>nul ^| findstr /b "MySQL Server"') do (
            if exist "C:\Program Files (x86)\MySQL\%%i\bin\mysql.exe" set "MYSQL_EXE=C:\Program Files (x86)\MySQL\%%i\bin\mysql.exe"
        )
    )
    if "!MYSQL_EXE!"=="" goto :no_mysql
)

cd /d "%APP_DIR%" 2>nul || goto :no_app

REM --- venv yoksa veya bozuksa olustur ---
if not exist ".venv\Scripts\python.exe" (
    echo ==^> Python sanal ortami olusturuluyor...
    if exist ".venv" rmdir /s /q .venv
    %PYTHON% -m venv .venv
    if !errorlevel! neq 0 (echo HATA: .venv olusturulamadi & pause & exit /b 1)
)
call ".venv\Scripts\activate.bat"

echo ==^> Bagimliliklar kuruluyor...
python -m pip install -q --upgrade pip 2>nul
pip install -q -r requirements.txt

:setup_env
if exist ".env" goto :load_env

echo.
set /p "DB_PW=MySQL root sifresini gir: "
for /f "delims=" %%i in ('python -c "import secrets; print(secrets.token_hex(32))"') do set "FLASK_SECRET=%%i"
(
    echo DB_HOST=127.0.0.1
    echo DB_PORT=3306
    echo DB_USER=root
    echo DB_PASSWORD=!DB_PW!
    echo DB_NAME=gym_management
    echo FLASK_SECRET=!FLASK_SECRET!
) > .env
set "DB_HOST=127.0.0.1"
set "DB_PORT=3306"
set "DB_USER=root"
set "DB_PASSWORD=!DB_PW!"
set "DB_NAME=gym_management"
goto :test_mysql

:load_env
for /f "usebackq tokens=1,* delims==" %%a in (".env") do (
    if not "%%a"=="" set "%%a=%%b"
)

:test_mysql
set "MYSQL_PWD=!DB_PASSWORD!"
"!MYSQL_EXE!" -h!DB_HOST! -P!DB_PORT! -u!DB_USER! -e "SELECT 1" 2>"%TEMP%\gym_mysql_err.txt" >nul
if !errorlevel! neq 0 (
    findstr /c:"Access denied" "%TEMP%\gym_mysql_err.txt" >nul 2>&1
    if !errorlevel! equ 0 (
        echo.
        echo MySQL sifresi yanlis. Lutfen dogru MySQL root sifrenizi girin.
        del /q "%TEMP%\gym_mysql_err.txt" 2>nul
        set /p "DB_PW=MySQL root sifresi: "
        set "DB_PASSWORD=!DB_PW!"
        REM .env'i yeniden yaz - sadece sifre degisiyor, diger ayarlar korunuyor
        (
            echo DB_HOST=!DB_HOST!
            echo DB_PORT=!DB_PORT!
            echo DB_USER=!DB_USER!
            echo DB_PASSWORD=!DB_PW!
            echo DB_NAME=!DB_NAME!
            echo FLASK_SECRET=!FLASK_SECRET!
        ) > .env
        goto :test_mysql
    )
    echo.
    echo HATA: MySQL servisine baglanilamadi.
    echo   Windows arama -^> "Services" ac -^> "MySQL80" ^(veya "MySQL84"^) -^> sag tik -^> Start
    type "%TEMP%\gym_mysql_err.txt"
    del /q "%TEMP%\gym_mysql_err.txt" 2>nul
    pause & exit /b 1
)
del /q "%TEMP%\gym_mysql_err.txt" 2>nul

REM --- Veritabani yoksa kur ---
"!MYSQL_EXE!" -h!DB_HOST! -P!DB_PORT! -u!DB_USER! -e "USE !DB_NAME!" 2>nul >nul
if !errorlevel! neq 0 (
    echo ==^> '!DB_NAME!' veritabani yok - schema + functions + triggers + views + data yukleniyor...
    pushd "%DB_DIR%"
    for %%f in (01_schema.sql 03_functions.sql 04_triggers.sql 05_views.sql 02_data.sql) do (
        "!MYSQL_EXE!" -h!DB_HOST! -P!DB_PORT! -u!DB_USER! < %%f
        if !errorlevel! neq 0 (popd & echo HATA: %%f yuklenemedi & pause & exit /b 1)
    )
    popd
    echo ==^> Veritabani kuruldu.
)
set "MYSQL_PWD="

echo.
echo ==^> Flask baslatiliyor: http://127.0.0.1:5050
echo ==^> Tarayicida bu adresi ac. Kapatmak icin Ctrl+C bas.
echo.
python app.py
exit /b 0

:no_python
echo HATA: Python bulunamadi.
echo python.org adresinden Python 3.10+ indir. Kurarken "Add Python to PATH" kutusunu IsaretLE.
pause & exit /b 1

:no_mysql
echo HATA: MySQL bulunamadi.
echo MySQL Server 8.x kurulu degil. Indir:  https://dev.mysql.com/downloads/installer/
echo Kurulum sirasinda bir root sifresi belirleyin, hatirlayin.
pause & exit /b 1

:no_app
echo HATA: app klasoru bulunamadi: %APP_DIR%
echo Bu scripti GymManagementSystem klasorunden calistirin.
pause & exit /b 1
