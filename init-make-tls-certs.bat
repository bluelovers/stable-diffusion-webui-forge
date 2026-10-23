@echo off
setlocal EnableExtensions

rem ---------------------------------------------------------------------------
rem make-tls-certs.bat - generate a self-signed TLS certificate / private key
rem
rem Files produced (consumed by Forge's TLS options):
rem   tls-cert.pem  -->  --tls-certfile
rem   tls-key.pem   -->  --tls-keyfile
rem
rem Usage:
rem   make-tls-certs.bat [output-directory]
rem     output-directory  optional, defaults to this script's own folder
rem
rem Notes:
rem   - needs openssl.exe (Git for Windows ships one)
rem   - the key is unencrypted on purpose: Forge cannot prompt for a passphrase
rem   - default validity is 365 days, change DAYS below to extend it
rem   - rerunning replaces the old pair after you confirm the overwrite
rem ---------------------------------------------------------------------------

set "DAYS=365"
set "CN=localhost"

set "OUTDIR=%~dp0"
if not "%~1"=="" set "OUTDIR=%~f1"
if "%OUTDIR:~-1%"=="\" set "OUTDIR=%OUTDIR:~0,-1%"

set "OUTCERT=%OUTDIR%\tls-cert.pem"
set "OUTKEY=%OUTDIR%\tls-key.pem"
set "CNF=%OUTDIR%\tls-gen.cnf"

if not exist "%OUTDIR%" (
    echo [ERROR] output directory does not exist: "%OUTDIR%"
    exit /b 1
)

rem --- locate openssl.exe -----------------------------------------------------
set "OPENSSL="
where /q openssl.exe
if not errorlevel 1 set "OPENSSL=openssl.exe"

if not defined OPENSSL (
    for %%P in (
        "%ProgramFiles%\Git\usr\bin\openssl.exe"
        "%ProgramFiles%\Git\mingw64\bin\openssl.exe"
        "%LocalAppData%\Programs\Git\usr\bin\openssl.exe"
        "D:\msys64\usr\bin\openssl.exe"
        "C:\msys64\usr\bin\openssl.exe"
        "%ProgramFiles%\OpenSSL\bin\openssl.exe"
    ) do (
        if not defined OPENSSL if exist "%%~P" set "OPENSSL=%%~P"
    )
)

if not defined OPENSSL (
    echo [ERROR] openssl.exe was not found.
    echo         Install Git for Windows, or put openssl.exe on PATH.
    exit /b 1
)

echo [INFO] using openssl: %OPENSSL%

rem --- do not overwrite an existing pair silently -----------------------------
if exist "%OUTCERT%" (
    echo tls-cert.pem already exists in %OUTDIR%
    choice /c YN /n /m "overwrite it? [Y/N] "
    if errorlevel 2 (
        echo cancelled - existing files kept
        exit /b 0
    )
)

rem --- openssl config: subject + SAN, keeps "-subj" out of the picture --------
(
    echo [req]
    echo prompt             = no
    echo default_bits       = 2048
    echo digest_alg         = sha256
    echo distinguished_name = dn
    echo x509_extensions    = ext
    echo.
    echo [dn]
    echo CN = %CN%
    echo.
    echo [ext]
    echo basicConstraints     = critical, CA:FALSE
    echo keyUsage             = critical, digitalSignature, keyEncipherment
    echo extendedKeyUsage     = serverAuth
    echo subjectKeyIdentifier = hash
    echo subjectAltName       = @san
    echo.
    echo [san]
    echo DNS.1 = localhost
    echo DNS.2 = %COMPUTERNAME%
    echo IP.1  = 127.0.0.1
    echo IP.2  = ::1
) > "%CNF%"

rem --- generate ---------------------------------------------------------------
"%OPENSSL%" req -x509 -newkey rsa:2048 -sha256 -days %DAYS% -nodes -keyout "%OUTKEY%" -out "%OUTCERT%" -config "%CNF%"
if errorlevel 1 (
    echo [ERROR] openssl failed while generating the certificate
    if exist "%CNF%" del /q "%CNF%"
    exit /b 1
)

if exist "%CNF%" del /q "%CNF%"

rem --- verify: both files exist and the pair matches --------------------------
if not exist "%OUTCERT%" (
    echo [ERROR] certificate file was not created: "%OUTCERT%"
    exit /b 1
)
if not exist "%OUTKEY%" (
    echo [ERROR] private key file was not created: "%OUTKEY%"
    exit /b 1
)

set "CERTMOD="
set "KEYMOD="
for /f "delims=" %%M in ('"%OPENSSL%" x509 -noout -modulus -in "%OUTCERT%" 2^>^&1') do set "CERTMOD=%%M"
for /f "delims=" %%M in ('"%OPENSSL%" rsa -noout -modulus -in "%OUTKEY%" 2^>^&1') do set "KEYMOD=%%M"

if /i not "%CERTMOD%"=="%KEYMOD%" (
    echo [ERROR] certificate and private key do not match
    exit /b 1
)

echo.
echo [OK] self-signed certificate created, valid %DAYS% days
echo      cert : "%OUTCERT%"
echo      key  : "%OUTKEY%"
echo      SAN  : localhost, %COMPUTERNAME%, 127.0.0.1, ::1
echo.
echo Forge launch options:
echo      set COMMANDLINE_ARGS=%%COMMANDLINE_ARGS%% --tls-certfile="%OUTCERT%" --tls-keyfile="%OUTKEY%"
exit /b 0
