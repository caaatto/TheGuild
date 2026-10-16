@echo off
rem Creates junctions in Interface\AddOns so every module shows up as its own
rem addon in the AddOn list while the files stay inside this repository.
setlocal
set "REPO=%~dp0.."
for %%I in ("%REPO%") do set "REPO=%%~fI"
for %%I in ("%REPO%\..") do set "ADDONS=%%~fI"

for /d %%M in ("%REPO%\Modules\*") do (
    for %%T in ("%%M\TheGuild_*.toc") do (
        if exist "%%T" call :link "%%~nT" "%%M"
    )
)
echo Done.
exit /b 0

:link
if exist "%ADDONS%\%~1" (
    echo exists  %~1
) else (
    mklink /J "%ADDONS%\%~1" "%~2" >nul && echo linked  %~1
)
exit /b 0
