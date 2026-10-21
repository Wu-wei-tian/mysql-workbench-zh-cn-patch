param([string]$ServerBin='C:\Program Files\MySQL\MySQL Server 8.4\bin')
$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$data=Join-Path (Get-Location) 'build\test-db'
if(Get-NetTCPConnection -LocalPort 13367 -State Listen -ErrorAction SilentlyContinue){throw 'Port 13367 is already in use; never reuse an unknown server'}
if(-not(Test-Path (Join-Path $data 'auto.cnf'))){
 New-Item -ItemType Directory -Force $data | Out-Null
 & (Join-Path $ServerBin 'mysqld.exe') --no-defaults --initialize-insecure "--datadir=$data" --console *> logs\mysql-test-init.log
 if($LASTEXITCODE){throw 'Test database initialization failed'}
}
$p=Start-Process (Join-Path $ServerBin 'mysqld.exe') -ArgumentList @('--no-defaults',('--datadir="'+$data+'"'),'--port=13367','--bind-address=127.0.0.1','--mysqlx=OFF','--skip-log-bin','--console') -WindowStyle Hidden -RedirectStandardError logs\mysql-test-server.log -RedirectStandardOutput logs\mysql-test-stdout.log -PassThru
$p.Id | Set-Content build\test-db.pid
Write-Output 'Disposable local test server started on 127.0.0.1:13367. Never expose it to the network.'
