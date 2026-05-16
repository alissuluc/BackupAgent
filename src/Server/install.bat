@echo off
setlocal

cd /d "%~dp0" >nul 2>&1

netsh advfirewall firewall add rule name="Open Port 8095" dir=in action=allow protocol=TCP localport=8095 >nul 2>&1

"%~dp0BackupAgentS.exe" /install /silent >nul 2>&1

timeout /t 2 /nobreak >nul 2>&1

sc start BackupAgentSvc >nul 2>&1

exit /b 0