@echo off
::taskkill /f /t /im node.exe
set mode=/K
start cmd %mode% run-relay.bat
timeout /t 1
start cmd %mode% run-host.bat
start cmd %mode% run-guest.bat
::pause