@echo off 

mode 200,1000

call build_all %1

setlocal

set FMUSDK_HOME=.

rem enhance path to include open modelica dlls. THis is needed due to a bug in loading the dlls
set PREV_PATH=%PATH%
rem set PATH=%PATH%;C:\OpenModelica1.12.0-dev-32bit\bin

echo Running Scenario

bin\fmu20sim_cs.exe

rem restore path
set PATH=%PREV_PATH%

endlocal

if "%1"=="nopause" goto skip
	pause
:skip