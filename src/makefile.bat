@echo off
title Build R2CompMod project

::==================================================::
::             CONFIGURATION SETTINGS               ::
::            Your folder replace after =           ::
::==================================================::
:: Note: For compiling you'll need include files.
:: More information here https://bitbucket.org/disawar1/l4d-competitive-plugins

:: Patch to the SourceMod scripting folder
set compiler=E:\srcds\Pawn\scripting fresh
::==================================================::

set error=folder does not exist! please edit this file and specify the correct path.

echo ##############################################################
echo #                  R2CompMod Compiler Helper                 #
echo #                          * * *                             #
echo # Script has been started and make your life easier!         #
echo # It take some time...                                       #
echo #                             Written by raziEiL [disawar1]  #
echo ##############################################################

if exist "%compiler%" (goto COMPILER) else goto ERROR

:COMPILER
set sourcecode=%~dp0
echo Source code folder: "%sourcecode%"
echo SM compiler folder: "%compiler%"
"%compiler%\spcomp.exe" -D "%sourcecode%\r2compmod.sp"
pause
exit

:ERROR
echo ERROR: compiler %error%
pause
exit