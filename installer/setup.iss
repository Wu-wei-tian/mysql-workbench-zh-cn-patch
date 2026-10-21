; SPDX-License-Identifier: GPL-2.0-only
; Independent localization installer; downloads the original from Oracle.
#define AppVersion "26.7.0.1"
#define ArchiveName "mysql-workbench-26.7.0-winx64.zip"
#define ArchiveHash "a2abe0925d0cc0d31d9818e60342902d699cd965ba2b55515607bccb67787684"
[Setup]
AppId={{D6175CF9-5398-4F15-AE66-EA468045F39D}
AppName=MySQL Workbench 26.7.0 - Simplified Chinese Community Localization
AppVersion={#AppVersion}
AppVerName=MySQL Workbench 26.7.0 简体中文社区汉化版 (Preview 1)
AppPublisher=Independent Community Localization (not Oracle)
VersionInfoDescription=MySQL Workbench Simplified Chinese Localization Installer
VersionInfoVersion={#AppVersion}
DefaultDirName={localappdata}\Programs\MySQL Workbench zh-CN
DefaultGroupName=MySQL Workbench 简体中文
DisableProgramGroupPage=yes
DisableDirPage=no
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog commandline
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
WizardStyle=modern
Compression=lzma2
SolidCompression=yes
ArchiveExtraction=full
OutputDir=..\dist
OutputBaseFilename=MySQL-Workbench-26.7.0-zh-CN-Setup
UninstallDisplayIcon={app}\MySQL Workbench.exe
CloseApplications=yes
RestartApplications=no
SetupLogging=yes
LicenseFile=..\upstream\LICENSE-workbench.txt
InfoBeforeFile=..\installer\NOTICE.txt
ExtraDiskSpaceRequired=1200000000

[Languages]
Name: "chinesesimp"; MessagesFile: "ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"
#include "chinese-overrides.iss"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式 / Create a desktop shortcut"; Flags: checkedonce

[Files]
Source: "{tmp}\{#ArchiveName}"; DestDir: "{app}"; Flags: external extractarchive recursesubdirs ignoreversion
#include "payload.iss"
Source: "standalone-profile.marker"; DestDir: "{app}\resources\app"; Flags: ignoreversion
Source: "..\build\standalone-manifest.json"; DestDir: "{app}\localization"; Flags: ignoreversion
Source: "..\dist\README.txt"; DestDir: "{app}\localization"; Flags: ignoreversion
Source: "..\dist\CHANGELOG.txt"; DestDir: "{app}\localization"; Flags: ignoreversion
Source: "..\dist\SOURCE-LICENSE-NOTICE.txt"; DestDir: "{app}\localization"; Flags: ignoreversion
Source: "..\upstream\mysql-workbench-26.7.0-src.zip"; DestDir: "{app}\localization\source"; Flags: ignoreversion
Source: "..\dist\localization-source.zip"; DestDir: "{app}\localization\source"; Flags: ignoreversion

[INI]
; Keep this small ownership marker after uninstall so reinstall can preserve unknown user files.
Filename: "{app}\zh-cn-install.ini"; Section: "Localization"; Key: "Version"; String: "{#AppVersion}"
Filename: "{app}\zh-cn-install.ini"; Section: "Localization"; Key: "Product"; String: "Workbench-26.7.0-zh-CN"

[Icons]
Name: "{group}\MySQL Workbench 简体中文"; Filename: "{app}\MySQL Workbench.exe"; WorkingDir: "{app}"
Name: "{group}\MySQL Workbench English"; Filename: "{app}\MySQL Workbench.exe"; Parameters: "--ui-language=en"; WorkingDir: "{app}"
Name: "{group}\Uninstall"; Filename: "{uninstallexe}"
Name: "{autodesktop}\MySQL Workbench 简体中文"; Filename: "{app}\MySQL Workbench.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\MySQL Workbench.exe"; Description: "启动 MySQL Workbench 简体中文 / Launch"; Flags: nowait postinstall skipifsilent

[Code]
var DownloadPage: TDownloadWizardPage;

procedure InitializeWizard;
begin
  DownloadPage := CreateDownloadPage('下载官方程序 / Download official runtime', 'MySQL Workbench 26.7.0 x64 (318 MiB)', nil);
end;

function ContainsFiles(Directory: String): Boolean;
var FindRec: TFindRec;
begin
  Result := False;
  if FindFirst(AddBackslash(Directory)+'*',FindRec) then begin
    try
      repeat
        if (FindRec.Name<>'.') and (FindRec.Name<>'..') then begin Result:=True; break; end;
      until not FindNext(FindRec);
    finally FindClose(FindRec); end;
  end;
end;

function ValidateTarget: String;
var Target, InstalledVersion: String;
begin
  Result := '';
  Target := ExpandConstant('{app}');
  if FileExists(Target + '\MySQL Workbench.exe') then begin
    if GetIniString('Localization', 'Product', '', Target+'\zh-cn-install.ini') <> 'Workbench-26.7.0-zh-CN' then begin
      Result := '此目录已有其他安装。请选择新的空目录；安装程序不会覆盖原版或未知版本。' + #13#10 + 'Choose a separate directory. Original or unknown installations cannot be overwritten.';
      exit;
    end;
    InstalledVersion := GetIniString('Localization', 'Version', '', Target+'\zh-cn-install.ini');
    if InstalledVersion <> '{#AppVersion}' then
      Result := 'Unsupported localization version. Choose a new directory instead of downgrading or overwriting it.';
  end else if DirExists(Target) and ContainsFiles(Target) then begin
    if GetIniString('Localization', 'Product', '', Target+'\zh-cn-install.ini') <> 'Workbench-26.7.0-zh-CN' then
      Result := 'For a fresh install, choose an empty directory. Existing data is never adopted.';
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var LocalArchive: String;
begin
  Result := ValidateTarget;
  if Result <> '' then exit;
  if FileExists(ExpandConstant('{tmp}\{#ArchiveName}')) then exit;
  LocalArchive := ExpandConstant('{src}\{#ArchiveName}');
  if FileExists(LocalArchive) then begin
    if CompareText(GetSHA256OfFile(LocalArchive), '{#ArchiveHash}') <> 0 then begin
      Result := 'The companion archive has an unexpected SHA-256. Installation was stopped.';
      exit;
    end;
    if not FileCopy(LocalArchive, ExpandConstant('{tmp}\{#ArchiveName}'), False) then
      Result := 'Could not stage the verified companion archive.';
    exit;
  end;
  DownloadPage.Clear;
  DownloadPage.Add('https://cdn.mysql.com/Downloads/MySQLGUITools/{#ArchiveName}', '{#ArchiveName}', '{#ArchiveHash}');
  DownloadPage.Show;
  try
    try
      DownloadPage.Download;
    except
      Result := 'Official download or SHA-256 verification failed: ' + GetExceptionMessage;
    end;
  finally
    DownloadPage.Hide;
  end;
end;

procedure VerifyOriginal(RelativePath, ExpectedHash: String);
var Target: String;
begin
  Target := ExpandConstant('{app}\') + RelativePath;
  if not FileExists(Target) then RaiseException('Missing original resource: ' + RelativePath);
  if CompareText(GetSHA256OfFile(Target), ExpectedHash) <> 0 then
    RaiseException('Incompatible original resource: ' + RelativePath);
end;
