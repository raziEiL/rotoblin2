@echo off
title Build R2CompMod project

::==================================================::
::             CONFIGURATION SETTINGS               ::
::            Your folder replace after =           ::
::==================================================::
:: Note: For compiling you'll need include files. 
:: More information here https://bitbucket.org/disawar1/l4d-competitive-plugins

:: Patch to the SourceMod scripting folder
set compiler=E:\srcds\Pawn\scripting
:: Patch to the Rotoblin src folder
set sourcecode=E:\srcds\Pawn\repos\r2comp (google)\src
::==================================================::

set error=folder does not exist! please edit this file and specify the correct path.

if exist "%sourcecode%" (goto CHECKING) else goto ERROR

:CHECKING
if exist "%compiler%" (goto COMPILER) else goto ERROR2

:COMPILER
"%compiler%\spcomp.exe" -D "%sourcecode%\r2compmod.sp"
echo -----------------------------------------------------------
echo NOTE: Check your sourcecode folder for plugin
echo -----------------------------------------------------------
pause
exit

:ERROR
echo sourcecode %error%
pause
exit

:ERROR2
echo compiler %error%
pause
exit
