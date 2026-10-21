param([string]$RunId='final')
$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$root=(Get-Location).Path
$results=[System.Collections.Generic.List[object]]::new()
function RunInstaller([string]$Exe,[string[]]$Extra,[string]$LogName){
 $args=@('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/CURRENTUSER','/LANG=chinesesimp',('/LOG="'+(Join-Path $root "logs\$LogName.log")+'"'))+$Extra
 $p=Start-Process -FilePath $Exe -ArgumentList $args -WindowStyle Hidden -PassThru -Wait
 return $p.ExitCode
}
function AssertResources([string]$Dir,$Manifest,[bool]$Patched){
 foreach($r in $Manifest.patches){
  $expected=if($Patched){$r.patchedSha256}else{$r.originalSha256}
  if((Get-FileHash (Join-Path $Dir $r.file) -Algorithm SHA256).Hash -ne $expected){throw "Resource mismatch: $($r.file)"}
 }
}
foreach($variant in @('msi','zip')){
 $source=if($variant -eq 'msi'){'C:\Program Files\MySQL\MySQL Workbench'}else{Join-Path $root 'build\official-zip'}
 $target=Join-Path $root "build\patch-test-$variant-$RunId"
 if(Test-Path $target){throw "Disposable target already exists: $target. Use a fresh workspace for this test."}
 & robocopy $source $target /E /XD localization /XF l10n.cjs zh-CN.json localization.js standalone-profile.marker /COPY:DAT /R:1 /W:1 /NFL /NDL /NP "/LOG:logs\stage-patch-$variant.log" | Out-Null
 if($LASTEXITCODE -ge 8){throw 'Staging failed'}
 Get-ChildItem $target -Recurse -File | Where-Object IsReadOnly | ForEach-Object {$_.IsReadOnly=$false}
 'USER DATA SENTINEL' | Set-Content (Join-Path $target 'personal-script.sql')
 $manifestName=if($variant -eq 'msi'){'build\patch-manifest.json'}else{'build\standalone-manifest.json'}
 $m=Get-Content $manifestName -Raw | ConvertFrom-Json
 foreach($r in $m.patches){
  $copy=Join-Path $target $r.file
  if((Get-FileHash $copy).Hash -ne $r.originalSha256){
   $backup=Join-Path $source ('localization\original\'+$r.file)
   if((Get-FileHash $backup).Hash -ne $r.originalSha256){throw 'No verified original for lifecycle fixture'}
   Copy-Item $backup $copy -Force
  }
 }
 $exe=Join-Path $root 'dist\MySQL-Workbench-26.7.0-zh-CN-Patch.exe'
 foreach($phase in @('install','repeat')){
  $code=RunInstaller $exe @(('/DIR="'+$target+'"')) "patch-$variant-$phase"
  if($code -ne 0){throw "Patch $variant $phase failed: $code"}
  AssertResources $target $m $true
  $results.Add(@{test="patch-$variant-$phase";status='PASS'})
 }
 $uninstaller=Join-Path $target 'localization\uninstaller\unins000.exe'
 $changed=Join-Path $target $m.patches[0].file
 $savedBytes=[IO.File]::ReadAllBytes($changed)
 [IO.File]::AppendAllText($changed,"`n// future upstream change fixture")
 $changedHash=(Get-FileHash $changed).Hash
 $code=RunInstaller $uninstaller @() "patch-$variant-reject-restore"
 if($code -eq 0){throw 'Restoration accepted unknown updated resource'}
 if((Get-FileHash $changed).Hash -ne $changedHash){throw 'Restoration overwrote unknown updated resource'}
 [IO.File]::WriteAllBytes($changed,$savedBytes)
 $results.Add(@{test="patch-$variant-refuse-restore-over-updated-resource";status='PASS';exitCode=$code})
 $code=RunInstaller $uninstaller @() "patch-$variant-uninstall"
 if($code -ne 0){throw "Uninstall failed: $code"}
 AssertResources $target $m $false
 if(-not(Test-Path (Join-Path $target 'personal-script.sql'))){throw 'User sentinel removed'}
 $results.Add(@{test="patch-$variant-restore-preserve-user-file";status='PASS'})
 $code=RunInstaller $exe @(('/DIR="'+$target+'"')) "patch-$variant-reinstall"
 if($code -ne 0){throw 'Reinstall failed'}
 AssertResources $target $m $true
 $code=RunInstaller $uninstaller @() "patch-$variant-second-uninstall"
 if($code -ne 0){throw 'Second uninstall failed'}
 $results.Add(@{test="patch-$variant-reinstall";status='PASS'})
 $helper=Join-Path $target 'resources\app\src\l10n.cjs'
 [IO.File]::WriteAllText($helper,'// unrelated user helper')
 $code=RunInstaller $exe @(('/DIR="'+$target+'"')) "patch-$variant-reject-helper"
 if($code -eq 0){throw 'Unowned helper was overwritten'}
 if([IO.File]::ReadAllText($helper) -ne '// unrelated user helper'){throw 'Unowned helper changed'}
 Remove-Item -LiteralPath $helper
 $results.Add(@{test="patch-$variant-refuse-unowned-helper";status='PASS';exitCode=$code})
 # Corrupt one disposable resource, then ensure no other resource changes.
 $resource=Join-Path $target $m.patches[0].file
 [IO.File]::AppendAllText($resource,"`n// incompatible fixture")
 $before=(Get-FileHash $resource -Algorithm SHA256).Hash
 $code=RunInstaller $exe @(('/DIR="'+$target+'"')) "patch-$variant-reject"
 if($code -eq 0){throw 'Incompatible fixture was accepted'}
 if((Get-FileHash $resource -Algorithm SHA256).Hash -ne $before){throw 'Rejected fixture was modified'}
 foreach($r in $m.patches | Select-Object -Skip 1){if((Get-FileHash (Join-Path $target $r.file)).Hash -ne $r.originalSha256){throw 'Rejection modified another resource'}}
 $results.Add(@{test="patch-$variant-reject-incompatible-before-write";status='PASS';exitCode=$code})
}
$results | ConvertTo-Json -Depth 4 | Set-Content logs\installer-lifecycle.json -Encoding utf8
