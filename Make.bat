@ECHO off
@SET LIT_VERSION=1.2.5

IF NOT "x%1" == "x" GOTO :%1

:lit
ECHO "Building lit"
@powershell -NoProfile -ExecutionPolicy unrestricted -Command "iex ((new-object net.webclient).DownloadString('https://raw.githubusercontent.com/luvit/lit/%LIT_VERSION%/get-lit.ps1'))"
GOTO :end

:test
IF NOT EXIST lit.exe CALL Make.bat lit
CALL lit.exe install
CALL luvi.exe . -m tests\run.lua
GOTO :end

:clean
IF EXIST lit.exe DEL /F /Q lit.exe
IF EXIST luvi.exe DEL /F /Q luvi.exe

:end
