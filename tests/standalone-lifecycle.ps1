param(
 [string]$RunId='release',
 [Parameter(Mandatory=$true)][string]$RuntimeZip
)
$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$root=(Get-Location).Path
$fixture=Join-Path $root "build\setup-fixture-$RunId"
$target=Join-Path $root "build\setup-install-$RunId"
if((Test-Path $fixture) -or (Test-Path $target)){throw 'Use a new RunId for disposable lifecycle fixtures'}
if((Get-FileHash $RuntimeZip).Hash -ne 'A2ABE0925D0CC0D31D9818E60342902D699CD965BA2B55515607BCCB67787684'){throw 'Unexpected runtime input'}
New-Item -ItemType Directory $fixture,$target | Out-Null
$exe=Join-Path $fixture 'MySQL-Workbench-26.7.0-zh-CN-Setup.exe'
$archive=Join-Path $fixture 'mysql-workbench-26.7.0-winx64.zip'
Copy-Item dist\MySQL-Workbench-26.7.0-zh-CN-Setup.exe $exe
Copy-Item $RuntimeZip $archive
$manifest=Get-Content build\standalone-manifest.json -Raw | ConvertFrom-Json
$results=[System.Collections.Generic.List[object]]::new()
function RunSetup([string]$Program,[string]$Directory,[string]$Phase){
 $args=@('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/CURRENTUSER','/LANG=chinesesimp',('/LOG="'+(Join-Path $root "logs\standalone-$Phase.log")+'"'))
 if($Directory){$args+=('/DIR="'+$Directory+'"')}
 $p=Start-Process $Program -ArgumentList $args -WindowStyle Hidden -PassThru -Wait
 return $p.ExitCode
}
function CheckPayload {
 foreach($r in $manifest.patches){if((Get-FileHash (Join-Path $target $r.file)).Hash -ne $r.patchedSha256){throw "Resource mismatch: $($r.file)"}}
 $originalExe=Join-Path $root 'build\official-zip\MySQL Workbench.exe'
 if((Get-FileHash (Join-Path $target 'MySQL Workbench.exe')).Hash -ne (Get-FileHash $originalExe).Hash){throw 'Original EXE bytes changed'}
}
foreach($phase in @('install-empty-directory','repeat')){
 $code=RunSetup $exe $target $phase
 if($code){throw "Standalone $phase failed: $code"}
 CheckPayload
 $results.Add(@{test="standalone-$phase";status='PASS'})
}
'USER SCRIPT SENTINEL' | Set-Content (Join-Path $target 'personal-script.sql')
$profile=Join-Path $fixture 'profile'
New-Item -ItemType Directory $profile | Out-Null
'PROFILE SENTINEL' | Set-Content (Join-Path $profile 'personal-settings.txt')
$code=RunSetup (Join-Path $target 'unins000.exe') '' 'uninstall'
if($code){throw "Uninstall failed: $code"}
if(Test-Path (Join-Path $target 'MySQL Workbench.exe')){throw 'Runtime executable was not removed'}
if(-not(Test-Path (Join-Path $target 'personal-script.sql'))){throw 'User script was removed'}
if(-not(Test-Path (Join-Path $profile 'personal-settings.txt'))){throw 'External profile was removed'}
$results.Add(@{test='standalone-uninstall-preserves-untracked-files';status='PASS'})
$code=RunSetup $exe $target 'reinstall'
if($code){throw "Reinstall with preserved files failed: $code"}
CheckPayload
if((Get-Content (Join-Path $target 'personal-script.sql')) -ne 'USER SCRIPT SENTINEL'){throw 'User script changed'}
$results.Add(@{test='standalone-reinstall-preserves-untracked-files';status='PASS'})
$foreign=Join-Path $fixture 'foreign-install'
New-Item -ItemType Directory $foreign | Out-Null
'UNKNOWN INSTALLATION' | Set-Content (Join-Path $foreign 'MySQL Workbench.exe')
$code=RunSetup $exe $foreign 'reject-foreign'
if($code -eq 0){throw 'Unknown installation was accepted'}
if((Get-Content (Join-Path $foreign 'MySQL Workbench.exe')) -ne 'UNKNOWN INSTALLATION'){throw 'Unknown installation changed'}
$results.Add(@{test='standalone-reject-foreign-install';status='PASS';exitCode=$code})
# Replace only the disposable archive copy, never the original download.
[IO.File]::WriteAllText($archive,'CORRUPT ARCHIVE FIXTURE')
$badTarget=Join-Path $fixture 'reject-bad-archive'
$code=RunSetup $exe $badTarget 'reject-archive'
if($code -eq 0){throw 'Corrupt archive was accepted'}
if(Test-Path $badTarget){throw 'Rejected archive created an installation'}
$results.Add(@{test='standalone-reject-archive-sha256';status='PASS';exitCode=$code})
$results | ConvertTo-Json -Depth 4 | Set-Content logs\standalone-lifecycle.json -Encoding utf8
