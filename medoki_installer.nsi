; NSIS Installer Script for Medoki Flutter App (Windows)
; Requires: Build the app first with `flutter build windows`
; Output: Installer EXE that copies the built app to Program Files and creates shortcuts

!define APPNAME "Medoki"
!define COMPANY "Medoki"
!define DESCRIPTION "Medoki Medical Records App"
!define VERSION "1.0.0"
!define EXE_NAME "medoki.exe"
!define INSTALL_DIR "$PROGRAMFILES\${APPNAME}"

; Icon for installer and shortcuts
!define ICON_FILE "windows\runner\resources\app_icon.ico"

; Installer output
OutFile "${APPNAME}_Setup.exe"
InstallDir "${INSTALL_DIR}"
RequestExecutionLevel admin

; Use modern UI
!include "MUI2.nsh"

;--------------------------------
; Installer pages
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

;--------------------------------
; Languages
!insertmacro MUI_LANGUAGE "English"

;--------------------------------
Section "Install"
  SetOutPath "$INSTDIR"
  ; Copy all files from build output
  File /r "build\windows\runner\Release\*.*"

  ; Create Start Menu shortcut
  CreateDirectory "$SMPROGRAMS\${APPNAME}"
  CreateShortCut "$SMPROGRAMS\${APPNAME}\${APPNAME}.lnk" "$INSTDIR\${EXE_NAME}" "" "$INSTDIR\${ICON_FILE}"

  ; Create Desktop shortcut
  CreateShortCut "$DESKTOP\${APPNAME}.lnk" "$INSTDIR\${EXE_NAME}" "" "$INSTDIR\${ICON_FILE}"

  ; Write uninstall information
  WriteUninstaller "$INSTDIR\Uninstall.exe"
SectionEnd

;--------------------------------
Section "Uninstall"
  ; Remove installed files
  Delete "$INSTDIR\${EXE_NAME}"
  Delete "$INSTDIR\Uninstall.exe"
  ; Remove all other files
  RMDir /r "$INSTDIR\data"
  RMDir /r "$INSTDIR\*"

  ; Remove shortcuts
  Delete "$SMPROGRAMS\${APPNAME}\${APPNAME}.lnk"
  RMDir  "$SMPROGRAMS\${APPNAME}"
  Delete "$DESKTOP\${APPNAME}.lnk"

  ; Remove install directory
  RMDir "$INSTDIR"
SectionEnd

;--------------------------------
; Uninstaller entry in Windows Apps & Features
Function un.onInit
  MessageBox MB_ICONQUESTION|MB_YESNO "Are you sure you want to uninstall ${APPNAME}?" IDYES +2
  Abort
FunctionEnd

;--------------------------------
; Installer Icon
Icon "${ICON_FILE}"
UninstallIcon "${ICON_FILE}"