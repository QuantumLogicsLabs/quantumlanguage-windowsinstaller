; ============================================================================
;  Quantum Programming Language - Windows Installer (Inno Setup script)
;  Produces: installer\Output\QuantumSetup.exe
;
;  Wizard flow:
;    Welcome  ->  Terms & Conditions (accept)  ->  Choose install folder
;             ->  Additional tasks (Add to PATH, pre-checked)
;             ->  Ready to install  ->  Installing  ->  Finish
;
;  Build:  "%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe" installer\Quantum.iss
; ============================================================================

#define MyAppName       "Quantum Programming Language"
#define MyAppShortName  "Quantum"
#define MyAppVersion    "2.0.4"
#define MyAppPublisher  "Muhammad Saad Amin (@SENODROOM)"
#define MyAppURL        "https://github.com/SENODROOM/Quantum-Language"
#define MyAppExeName    "quantum.exe"

[Setup]
; A unique AppId for this product (do not reuse for other apps).
AppId={{8F3A2C1E-7B4D-49A6-9C0F-2A6B4D9C0F1E}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppShortName}
DefaultGroupName={#MyAppShortName}
DisableProgramGroupPage=yes
; Per-user install => no UAC elevation prompt, PATH changes apply cleanly.
PrivilegesRequired=lowest
; Terms & Conditions page (must be accepted to continue).
LicenseFile=TermsAndConditions.txt
; Branding / icon.
SetupIconFile=assets\quantum.ico
; We change the PATH environment variable, so broadcast the change.
ChangesEnvironment=yes
WizardStyle=modern
Compression=lzma2/max
SolidCompression=yes
OutputDir=Output
OutputBaseFilename=QuantumSetup
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
; Pre-checked checkbox to add Quantum to the user's PATH.
Name: "addtopath"; Description: "Add Quantum to my PATH environment variable (recommended)"; GroupDescription: "Environment:"
; Optional desktop shortcut to the install folder (unchecked by default).
Name: "desktopicon"; Description: "Create a desktop shortcut to the Quantum folder"; GroupDescription: "Shortcuts:"; Flags: unchecked

[Files]
; --- Core binaries (must live in the same folder) ---
Source: "..\quantum.exe";       DestDir: "{app}"; Flags: ignoreversion
Source: "..\qrun.exe";          DestDir: "{app}"; Flags: ignoreversion
Source: "..\quantum_stub.exe";  DestDir: "{app}"; Flags: ignoreversion
; --- Documentation ---
Source: "..\README.md";         DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE";           DestDir: "{app}"; DestName: "LICENSE.txt"; Flags: ignoreversion
Source: "TermsAndConditions.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
; Start-menu entries.
Name: "{group}\Quantum README";          Filename: "{app}\README.md"
Name: "{group}\Uninstall Quantum";       Filename: "{uninstallexe}"
; Optional desktop shortcut (folder).
Name: "{autodesktop}\Quantum";           Filename: "{app}"; Tasks: desktopicon

[Registry]
; Append the install folder to the per-user PATH (HKCU\Environment) only when
; the "addtopath" task is selected AND it is not already present.
Root: HKCU; Subkey: "Environment"; ValueType: expandsz; ValueName: "Path"; \
    ValueData: "{olddata};{app}"; \
    Tasks: addtopath; Check: NeedsAddPath(ExpandConstant('{app}'))

[Run]
; Offer to open the examples folder when finished.
Filename: "{app}"; Description: "Open the Quantum folder"; Flags: postinstall shellexec skipifsilent unchecked

[Code]
{ Returns True if Param is NOT already on the user's PATH (so we should add it). }
function NeedsAddPath(Param: string): Boolean;
var
  OrigPath: string;
begin
  if not RegQueryStringValue(HKEY_CURRENT_USER, 'Environment', 'Path', OrigPath) then
  begin
    Result := True;  { No PATH yet -> definitely add. }
    exit;
  end;
  { Wrap in semicolons for a whole-token, case-insensitive comparison. }
  Result := Pos(';' + Lowercase(Param) + ';', ';' + Lowercase(OrigPath) + ';') = 0;
end;

{ On uninstall, strip the install folder back out of the user's PATH. }
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  OrigPath, AppDir, NewPath: string;
  P: Integer;
begin
  if CurUninstallStep <> usUninstall then
    exit;
  if not RegQueryStringValue(HKEY_CURRENT_USER, 'Environment', 'Path', OrigPath) then
    exit;

  AppDir := ExpandConstant('{app}');

  { Try the ';dir' form first, then 'dir;', then a lone 'dir'. }
  NewPath := OrigPath;
  P := Pos(Lowercase(';' + AppDir), Lowercase(NewPath));
  if P > 0 then
    Delete(NewPath, P, Length(';' + AppDir))
  else
  begin
    P := Pos(Lowercase(AppDir + ';'), Lowercase(NewPath));
    if P > 0 then
      Delete(NewPath, P, Length(AppDir + ';'))
    else
    begin
      P := Pos(Lowercase(AppDir), Lowercase(NewPath));
      if P > 0 then
        Delete(NewPath, P, Length(AppDir));
    end;
  end;

  if NewPath <> OrigPath then
    RegWriteExpandStringValue(HKEY_CURRENT_USER, 'Environment', 'Path', NewPath);
end;
