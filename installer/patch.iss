; SPDX-License-Identifier: GPL-2.0-only
#define AppVersion "26.7.0.1"
[Setup]
AppId={{3956B919-00E0-474C-B03A-B05F49B8BC04}
AppName=MySQL Workbench 26.7.0 Simplified Chinese Patch
AppVersion={#AppVersion}
AppVerName=MySQL Workbench 26.7.0 简体中文补丁 (Preview 1)
AppPublisher=Independent Community Localization (not Oracle)
VersionInfoVersion={#AppVersion}
VersionInfoDescription=MySQL Workbench Simplified Chinese Offline Patch
DefaultDirName={autopf64}\MySQL\MySQL Workbench
DisableDirPage=no
DisableProgramGroupPage=yes
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=commandline
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
WizardStyle=modern
Compression=lzma2
SolidCompression=yes
OutputDir=..\dist
OutputBaseFilename=MySQL-Workbench-26.7.0-zh-CN-Patch
UninstallDisplayName=MySQL Workbench 26.7.0 简体中文补丁 (恢复英文 / Restore English)
UninstallFilesDir={app}\localization\uninstaller
UninstallDisplayIcon={app}\MySQL Workbench.exe
CloseApplications=yes
RestartApplications=no
SetupLogging=yes
LicenseFile=..\upstream\LICENSE-workbench.txt
InfoBeforeFile=PATCH-NOTICE.txt

[Languages]
Name: "chinesesimp"; MessagesFile: "ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"
#include "chinese-overrides.iss"

[Files]
#include "patch-payload-msi.iss"
#include "patch-payload-zip.iss"
Source: "..\build\patch-manifest.json"; DestDir: "{app}\localization"; Flags: ignoreversion; Check: IsMsiRuntime
Source: "..\build\standalone-manifest.json"; DestDir: "{app}\localization"; DestName: "patch-manifest.json"; Flags: ignoreversion; Check: IsZipRuntime
Source: "..\dist\README.txt"; DestDir: "{app}\localization"; Flags: ignoreversion
Source: "..\dist\SOURCE-LICENSE-NOTICE.txt"; DestDir: "{app}\localization"; Flags: ignoreversion
Source: "..\upstream\mysql-workbench-26.7.0-src.zip"; DestDir: "{app}\localization\source"; Flags: ignoreversion
Source: "..\dist\localization-source.zip"; DestDir: "{app}\localization\source"; Flags: ignoreversion

[Code]
var CheckError: String; IsRestoring: Boolean;

function IsZipRuntime: Boolean;
begin
  Result := FileExists(ExpandConstant('{app}\resources\app\frontend\build\assets\ApplicationHost-DxSYK8q-.js'));
end;

function IsMsiRuntime: Boolean;
begin
  Result := not IsZipRuntime;
end;

procedure CheckResource(RelativePath, OriginalHash, PatchedHash: String);
var Target, Backup, Actual: String;
begin
  if CheckError <> '' then exit;
  Target := ExpandConstant('{app}\') + RelativePath;
  Backup := ExpandConstant('{app}\localization\original\') + RelativePath;
  if not FileExists(Target) then begin CheckError := 'Missing resource: '+RelativePath; exit; end;
  Actual := GetSHA256OfFile(Target);
  if (CompareText(Actual,OriginalHash) <> 0) and (CompareText(Actual,PatchedHash) <> 0) then begin
    CheckError := 'Incompatible or modified resource: '+RelativePath+'. No files will be patched.'; exit;
  end;
  if FileExists(Backup) then begin
    if CompareText(GetSHA256OfFile(Backup),OriginalHash) <> 0 then CheckError := 'Backup hash mismatch: '+RelativePath;
  end else begin
    if IsRestoring or (CompareText(Actual,OriginalHash) <> 0) then CheckError := 'Missing verified original backup: '+RelativePath;
  end;
end;

procedure BackupResource(RelativePath, OriginalHash, PatchedHash: String);
var Source, Dest: String;
begin
  Source := ExpandConstant('{app}\') + RelativePath;
  Dest := ExpandConstant('{app}\localization\original\') + RelativePath;
  if not FileExists(Dest) then begin
    if not ForceDirectories(ExtractFileDir(Dest)) then RaiseException('Cannot create backup directory');
    if not FileCopy(Source,Dest,True) then RaiseException('Cannot backup '+RelativePath);
    if CompareText(GetSHA256OfFile(Dest),OriginalHash) <> 0 then RaiseException('Backup verification failed: '+RelativePath);
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  CheckError := ''; IsRestoring := False;
  if FileExists(ExpandConstant('{app}\resources\app\standalone-profile.marker')) then begin
    Result := 'This is the standalone localization edition. Use its own installer instead.'; exit;
  end;
  if not FileExists(ExpandConstant('{app}\MySQL Workbench.exe')) then begin
    Result := 'MySQL Workbench was not found. Select the installation directory for version 26.7.0.'; exit;
  end;
  if not FileExists(ExpandConstant('{app}\localization\patch-manifest.json')) then begin
    if FileExists(ExpandConstant('{app}\resources\app\src\l10n.cjs')) or
       FileExists(ExpandConstant('{app}\resources\app\src\zh-CN.json')) or
       FileExists(ExpandConstant('{app}\resources\app\frontend\build\localization.js')) then begin
      Result := 'Existing localization helper files are not owned by this patch. Installation stopped.'; exit;
    end;
  end;
  if IsZipRuntime then begin
#include "resource-checks-zip.iss"
  end else begin
#include "resource-checks-msi.iss"
  end;
  Result := CheckError;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssInstall then begin
    if IsZipRuntime then begin
#include "resource-backups-zip.iss"
    end else begin
#include "resource-backups-msi.iss"
    end;
  end;
end;

function InitializeUninstall: Boolean;
begin
  CheckError := ''; IsRestoring := True;
  if IsZipRuntime then begin
#include "resource-checks-zip.iss"
  end else begin
#include "resource-checks-msi.iss"
  end;
  Result := CheckError = '';
  if not Result then SuppressibleMsgBox('Restoration stopped to protect updated files: '+CheckError,mbError,MB_OK,IDOK);
end;

procedure RestoreResource(RelativePath, OriginalHash: String);
var Source, Dest: String;
begin
  Source := ExpandConstant('{app}\localization\original\') + RelativePath;
  Dest := ExpandConstant('{app}\') + RelativePath;
  if not FileCopy(Source,Dest,False) then RaiseException('Cannot restore '+RelativePath);
  if CompareText(GetSHA256OfFile(Dest),OriginalHash) <> 0 then RaiseException('Restoration verification failed: '+RelativePath);
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep=usUninstall then begin
    if IsZipRuntime then begin
#include "resource-restore-zip.iss"
    end else begin
#include "resource-restore-msi.iss"
    end;
  end;
end;
