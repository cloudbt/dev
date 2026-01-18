# SAP Login Scripts

## F36_SAP_Login.bat

SAP自动登录批处理脚本，支持从CSV文件读取密码

```batch
@echo off
setlocal EnableDelayedExpansion

REM SAP Login Script for F36 System

set "SYSTEM=F36"

call :log "Script started for %SYSTEM%"

REM --- Locate sapshcut.exe ---
set "SAPSHCUT=%ProgramFiles(x86)%\SAP\FrontEnd\SAPgui\sapshcut.exe"
if not exist "%SAPSHCUT%" set "SAPSHCUT=%ProgramFiles%\SAP\FrontEnd\SAPgui\sapshcut.exe"

if not exist "%SAPSHCUT%" (
  call :log "ERROR: sapshcut.exe not found"
  pause
  exit /b 1
)

REM --- Get user input ---
set /p client=Enter client number (e.g. 100):
if "%client%"=="" (
  call :log "ERROR: Client number required"
  pause
  exit /b 1
)

set /p user=Enter username (default: 2EY165):
if "%user%"=="" set "user=2EY165"

set /p lang=Enter language (default EN):
if "%lang%"=="" set "lang=EN"

REM --- Check user's password file ---
set "CSV=%~dp0%user%.csv"
call :log "User: %user%, Client: %client%"
call :log "Password file: %CSV%"

if not exist "%CSV%" (
  call :log "ERROR: Password file %user%.csv not found"
  pause
  exit /b 1
)

set "pwd="
set "commonPwd="

REM --- Search for specific client password and common password ---
for /f "usebackq tokens=1-3 delims=, skip=1" %%A in ("%CSV%") do (
  set "csvSys=%%A"
  set "csvClient=%%B"
  set "csvPwd=%%C"

  REM Remove spaces
  set "csvSys=!csvSys: =!"
  set "csvClient=!csvClient: =!"

  if /I "!csvSys!"=="%SYSTEM%" (
    if /I "!csvClient!"=="%client%" (
      set "pwd=!csvPwd!"
      call :log "Found password for client %client%"
    )
    if /I "!csvClient!"=="common" (
      set "commonPwd=!csvPwd!"
      call :log "Found common password"
    )
  )
)

REM --- Use common password if specific client password not found ---
if not defined pwd (
  if defined commonPwd (
    set "pwd=!commonPwd!"
    call :log "Using common password for client %client%"
  ) else (
    call :log "ERROR: No password found for system=%SYSTEM%, client=%client%"
    pause
    exit /b 1
  )
)

REM --- Launch SAP GUI ---
call :log "Launching SAP GUI with system=%SYSTEM%, client=%client%, language=%lang%, password=%pwd%"
START "" "%SAPSHCUT%" -system=%SYSTEM% -sysname=%SYSTEM% -client=%client% -user=%user% -pw=%pwd% -language=%lang%

call :log "Script finished"
timeout /t 30 /nobreak >nul
exit /b 0

REM --- Log function ---
:log
echo [%date% %time%] %~1
goto :eof
```

## Password CSV Format (2EY165.csv)

```csv
system,client,password
F36,100,AAA
F36,200,BBB
F36,common,CCC
F46,100,CCC
F46,common,CCC
F56,500,DDD
F56,common,CCC
```

## Usage

1. 将脚本和CSV密码文件放在同一目录下
2. CSV文件名必须与用户名一致 (例如: 2EY165.csv)
3. 运行批处理脚本并按提示输入：
   - Client number (例如: 100)
   - Username (默认: 2EY165)
   - Language (默认: EN)
4. 脚本会自动查找对应的密码并登录SAP系统

## Features

- 支持从CSV文件读取密码
- 支持client专用密码和common通用密码
- 自动检测sapshcut.exe路径
- 完整的错误处理和日志记录
