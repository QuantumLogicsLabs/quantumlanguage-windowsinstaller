@echo off
rem Builds the Windows installer from the compiled programs in ..\build,
rem copies it into the website's downloads folder, and bumps the version.
rem
rem   build-installer.bat           next patch version (3.0.0 -> 3.0.1)
rem   build-installer.bat 3.1.0     that version instead
rem
rem version.txt holds the version of the last installer built (Quantum.iss
rem reads it too). It is rewritten only when the build and the copy succeed,
rem so a failed run doesn't use up a version number.
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

rem --- the programs the installer ships ---
for %%F in (quantum.exe qrun.exe quantum_stub.exe qpm.exe) do (
    if not exist "%BUILD%\%%F" (
        echo [error] %BUILD%\%%F is missing: run ..\build-quantum.bat first
        exit /b 1
    )
)
if not exist "%DOWNLOADS%\" (
    echo [error] downloads folder not found: %DOWNLOADS%
    exit /b 1
)

echo [1/3] building Output\QuantumSetup.exe %VERSION%
"%ISCC%" /Q /DMyAppVersion=%VERSION% Quantum.iss || goto :fail

echo [2/3] copying to %DOWNLOADS%
copy /y Output\QuantumSetup.exe "%DOWNLOADS%\QuantumSetup.exe" >nul || goto :fail
rem copy can fail silently when the target is locked: compare the bytes
fc /b Output\QuantumSetup.exe "%DOWNLOADS%\QuantumSetup.exe" >nul || (
    echo [error] %DOWNLOADS%\QuantumSetup.exe differs from Output\QuantumSetup.exe
    exit /b 1
)

echo [3/3] version.txt: %VERSION%
>version.txt echo %VERSION%

echo.
echo Done: Output\QuantumSetup.exe ^(version %VERSION%^)
echo       %DOWNLOADS%\QuantumSetup.exe
exit /b 0

:fail
echo [error] installer build failed
exit /b 1

rem --- succeeds when %1 looks like MAJOR.MINOR.PATCH ---
:isversion
echo %~1| findstr /r "^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$" >nul
exit /b
