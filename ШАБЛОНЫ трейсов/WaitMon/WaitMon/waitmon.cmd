@echo off
set isqlpath=C:\Program Files\Microsoft SQL Server\80\Tools\Binn
set sybsrv=SERVERNAME
set syblogin=sa
echo MSSQL server alias: %sybsrv%
echo User: %syblogin%
set /p sybpasswd=Password: 

"%isqlpath%\osql.exe" -S%sybsrv% -U%syblogin% -P%sybpasswd% -w 4096 -i waitmon.sql -o waitmon.log -n
