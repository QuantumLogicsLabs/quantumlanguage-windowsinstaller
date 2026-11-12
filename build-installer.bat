@echo off
rem Builds the Windows installer from the compiled programs in ..\build,
rem copies it into the website's downloads folder, and publishes ..\build to
rem npm, bumping both versions.
rem
rem   build-installer.bat           next patch versions: the installer
rem                                 (3.0.0 -> 3.0.1) and the npm package
rem                                 (1.0.3 -> 1.0.4)
rem   build-installer.bat 3.1.0     that installer version instead
rem
rem version.txt holds the version of the last installer built (Quantum.iss
rem reads it too). It is rewritten only when every step succeeds. The npm
rem version lives in ..\build\package.json; if publishing fails it is put
rem back. So a failed run uses up neither version number.
rem
rem Run ..\build-quantum.bat first: this only packages build\*.exe, it does
rem not compile them. All paths are relative to this folder (installer\).
setlocal
cd /d "%~dp0"

set BUILD=..\build
set DOWNLOADS=..\..\frontend\public\downloads

rem --- the version: the one given, or version.txt's with the patch bumped ---
set VERSION=%~1
if not "%VERSION%"=="" goto :checkversion
if not exist version.txt (
    echo [error] version.txt is missing: give the version, e.g. build-installer.bat 3.0.0
    exit /b 1
)
set LAST=
for /f "usebackq delims=" %%V in ("version.txt") do if not defined LAST set LAST=%%V
call :isversion "%LAST%" || (
    echo [error] version.txt holds "%LAST%", not a version like 3.0.0
    exit /b 1
)
for /f "tokens=1-3 delims=." %%a in ("%LAST%") do (
    set MAJOR=%%a
    set MINOR=%%b
    set /a PATCH=%%c+1
)
set VERSION=%MAJOR%.%MINOR%.%PATCH%

:checkversion
call :isversion "%VERSION%" || (
    echo [error] "%VERSION%" is not a version like 3.0.1
    exit /b 1
)

rem --- find Inno Setup's compiler ---
set ISCC=
if exist "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" set ISCC=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe
if "%ISCC%"=="" if exist "%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe" set ISCC=%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe
if "%ISCC%"=="" for %%I in (ISCC.exe) do set ISCC=%%~$PATH:I
if "%ISCC%"=="" (
    echo [error] Inno Setup 6 ^(ISCC.exe^) not found
    exit /b 1
)

rem --- the programs the installer and the npm package ship ---
for %%F in (quantum.exe qrun.exe quantum_stub.exe qpm.exe package.json) do (
    if not exist "%BUILD%\%%F" (
        echo [error] %BUILD%\%%F is missing: run ..\build-quantum.bat first
        exit /b 1
    )
)
if not exist "%DOWNLOADS%\" (
    echo [error] downloads folder not found: %DOWNLOADS%
    exit /b 1
)

rem --- npm: installed and logged in, checked before anything is built ---
call npm --version >nul 2>&1 || (
    echo [error] npm not found: install Node.js
    exit /b 1
)
call npm whoami >nul 2>&1 || (
    echo [error] not logged in to npm: run npm login
    exit /b 1
)

echo [1/4] building Output\QuantumSetup.exe %VERSION%
"%ISCC%" /Q /DMyAppVersion=%VERSION% Quantum.iss || goto :fail

echo [2/4] copying to %DOWNLOADS%
copy /y Output\QuantumSetup.exe "%DOWNLOADS%\QuantumSetup.exe" >nul || goto :fail
rem copy can fail silently when the target is locked: compare the bytes
fc /b Output\QuantumSetup.exe "%DOWNLOADS%\QuantumSetup.exe" >nul || (
    echo [error] %DOWNLOADS%\QuantumSetup.exe differs from Output\QuantumSetup.exe
    exit /b 1
)

rem --- npm: bump the patch version in package.json, publish; undo the bump if
rem publishing fails ---
pushd "%BUILD%"
set NPM_OLD=
for /f "delims=" %%V in ('npm pkg get version') do set NPM_OLD=%%~V
call :isversion "%NPM_OLD%" || (
    echo [error] %BUILD%\package.json has no version like 1.0.3
    popd
    exit /b 1
)
call npm version patch --no-git-tag-version >nul || (
    echo [error] npm version failed
    popd
    exit /b 1
)
set NPM_NEW=
for /f "delims=" %%V in ('npm pkg get version') do set NPM_NEW=%%~V
echo [3/4] publishing npm package %NPM_NEW% from %BUILD%
call npm publish || (
    echo [error] npm publish failed: %BUILD%\package.json is back at %NPM_OLD%
    call npm version %NPM_OLD% --no-git-tag-version --allow-same-version >nul
    popd
    exit /b 1
)
popd

echo [4/4] version.txt: %VERSION%
>version.txt echo %VERSION%

echo.
echo Done: Output\QuantumSetup.exe ^(version %VERSION%^)
echo       %DOWNLOADS%\QuantumSetup.exe
echo       npm package %NPM_NEW% ^(%BUILD%\package.json^)
exit /b 0

:fail
echo [error] installer build failed
exit /b 1

rem --- succeeds when %1 looks like MAJOR.MINOR.PATCH ---
:isversion
echo %~1| findstr /r "^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$" >nul
exit /b
