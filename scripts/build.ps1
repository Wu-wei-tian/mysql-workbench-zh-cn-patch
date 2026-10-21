param(
 [string]$OriginalDir = 'C:\Program Files\MySQL\MySQL Workbench',
 [Parameter(Mandatory=$true)][string]$RuntimeZip,
 [Parameter(Mandatory=$true)][string]$InnoCompiler
)
$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
foreach($dir in @('build','logs','dist','upstream','backup')) { New-Item -ItemType Directory -Force $dir | Out-Null }
foreach($doc in Get-ChildItem docs -Filter '*.txt' -ErrorAction SilentlyContinue) { Copy-Item $doc.FullName dist }
if ((Get-Content (Join-Path $OriginalDir 'resources\app\package.json') -Raw | ConvertFrom-Json).version -ne '26.7.0') { throw 'Only Workbench 26.7.0 is supported' }
$InputDir=$OriginalDir
$installedManifest=Join-Path $OriginalDir 'localization\patch-manifest.json'
if(Test-Path $installedManifest){
 # Reconstruct a pristine build input from verified backups without changing the installation.
 $InputDir=Join-Path (Get-Location) ('build\input-msi-'+[guid]::NewGuid().ToString('N'))
 & robocopy $OriginalDir $InputDir /E /XD localization /XF l10n.cjs zh-CN.json localization.js standalone-profile.marker /COPY:DAT /R:1 /W:1 /NFL /NDL /NP /LOG:logs\reconstruct-input.log | Out-Null
 if($LASTEXITCODE -ge 8){throw 'Input staging failed'}
 $manifest=Get-Content $installedManifest -Raw | ConvertFrom-Json
 if($manifest.version -ne '26.7.0'){throw 'Unsupported installed patch manifest'}
 foreach($r in $manifest.patches){
  $destination=[IO.Path]::GetFullPath((Join-Path $InputDir $r.file))
  if(-not $destination.StartsWith($InputDir+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe manifest path'}
  $backup=Join-Path $OriginalDir ('localization\original\'+$r.file)
  if((Get-FileHash $backup).Hash -ne $r.originalSha256){throw 'Original backup hash mismatch'}
  Copy-Item $backup $destination -Force
 }
 Write-Output 'Reconstructed pristine build input from verified original backups.'
}
if ((Get-FileHash $RuntimeZip -Algorithm SHA256).Hash -ne 'A2ABE0925D0CC0D31D9818E60342902D699CD965BA2B55515607BCCB67787684') { throw 'Unexpected official runtime SHA-256' }
$sourceZip='upstream\mysql-workbench-26.7.0-src.zip'
if (-not (Test-Path $sourceZip)) { Invoke-WebRequest 'https://cdn.mysql.com/Downloads/MySQLGUITools/mysql-workbench-26.7.0-src.zip' -OutFile $sourceZip }
if ((Get-FileHash $sourceZip -Algorithm MD5).Hash -ne '0E0D076BF03A80B7CDFB9EA716BF08B2') { throw 'Unexpected source archive checksum' }
Copy-Item (Join-Path $OriginalDir 'LICENSE.txt') 'upstream\LICENSE-workbench.txt' -Force
Copy-Item $sourceZip dist
& robocopy $InputDir build\app /E /COPY:DAT /R:1 /W:1 /NFL /NDL /NP /LOG:logs\copy-original.log | Out-Null
if($LASTEXITCODE -ge 8){throw 'Staging original failed'}
Expand-Archive $RuntimeZip build\official-zip -Force
& robocopy build\official-zip build\app-standalone /E /COPY:DAT /R:1 /W:1 /NFL /NDL /NP /LOG:logs\copy-zip.log | Out-Null
if($LASTEXITCODE -ge 8){throw 'Staging ZIP failed'}
Get-ChildItem build\app,build\app-standalone -Recurse -File | Where-Object IsReadOnly | ForEach-Object {$_.IsReadOnly=$false}
node scripts\import-translations.cjs
if($LASTEXITCODE){throw 'Dictionary build failed'}
try {
 $env:WB_ORIGINAL=(Resolve-Path $InputDir).Path
 $env:WB_OUTPUT=(Resolve-Path build\app).Path
 $env:WB_MANIFEST=Join-Path (Get-Location) 'build\patch-manifest.json'
 node scripts\localize.cjs
 if($LASTEXITCODE){throw 'MSI localization failed'}
 node scripts\package.cjs
 if($LASTEXITCODE){throw 'MSI packaging failed'}
 $env:WB_ORIGINAL=(Resolve-Path build\official-zip).Path
 $env:WB_OUTPUT=(Resolve-Path build\app-standalone).Path
 $env:WB_MANIFEST=Join-Path (Get-Location) 'build\standalone-manifest.json'
 node scripts\localize.cjs
 if($LASTEXITCODE){throw 'ZIP localization failed'}
 node scripts\package.cjs --standalone
 if($LASTEXITCODE){throw 'ZIP packaging failed'}
} finally { Remove-Item Env:\WB_ORIGINAL,Env:\WB_OUTPUT,Env:\WB_MANIFEST -ErrorAction SilentlyContinue }
node scripts\audit-untranslated.cjs
if($LASTEXITCODE){throw 'Untranslated audit failed'}
$env:WB_ORIGINAL=$InputDir
try { npm.cmd test *> logs\unit-tests.log; if($LASTEXITCODE){throw 'Tests failed; see logs/unit-tests.log'} }
finally { Remove-Item Env:\WB_ORIGINAL -ErrorAction SilentlyContinue }
node scripts\archive-source.cjs
if($LASTEXITCODE){throw 'Source staging failed'}
Compress-Archive build\source-package\* dist\localization-source.zip -Force
foreach($kind in @('patch','setup')) {
 & $InnoCompiler "installer\$kind.iss" *> "logs\build-$kind.log"
 if($LASTEXITCODE){throw "Installer compilation failed: $kind"}
}
$hashLines=Get-ChildItem dist -File | Where-Object Extension -in '.exe','.zip' | Sort-Object Name | ForEach-Object { ((Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant())+'  '+$_.Name }
$hashLines | Set-Content dist\SHA256SUMS.txt -Encoding utf8
Write-Output 'Both installers built. Review dist/TEST_REPORT.txt before distribution.'
