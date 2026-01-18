@echo off
setlocal EnableDelayedExpansion

REM SAP Login Script for ER1 System

set "SYSTEM=ER1"
set "SYSTEMNAME=ER1"
call :log "Script started for %SYSTEM%"

REM --- Locate sapshcut.exe ---
set "SAPSHCUT=%ProgramFiles(x86)%\SAP\FrontEnd\SAPgui\sapshcut.exe"
if not exist "%SAPSHCUT%" set "SAPSHCUT=%ProgramFiles%\SAP\FrontEnd\SAPgui\sapshcut.exe"

if not exist "%SAPSHCUT%" (
  call :log "ERROR: sapshcut.exe not found"
  pause
  exit /b 1
)

REM client 000 001 800
set "client=800"

set /p user=Enter username (default: zddic): 
if "%user%"=="" set "user=zddic"

set "lang=EN"

set "pwd=c123456"
set "commonPwd="


REM --- Launch SAP GUI ---
call :log "Launching SAP GUI with system=%SYSTEM%, client=%client%, language=%lang%, password=%pwd%"
START "" "%SAPSHCUT%" -system=%SYSTEM% -sysname=%SYSTEMNAME% -client=%client% -user=%user% -pw=%pwd% -language=%lang%

call :log "Script finished"
timeout /t 5 /nobreak >nul
exit /b 0

REM --- Log function ---
:log
echo [%date% %time%] %~1
goto :eof