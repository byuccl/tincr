@echo off

set cmd=vivado -nojournal -nolog -mode batch

if not -%1-==--	(
	set cmd=%cmd% -source %1
	shift
)

if not -%1-==--	(
	set cmd=%cmd% -tclargs %1
	shift
)
 
:argactionstart
if -%1-==-- goto argactionend
set cmd=%cmd% %1
shift
goto argactionstart

:argactionend
%cmd%
exit /b