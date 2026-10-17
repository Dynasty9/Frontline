; The Windows installer, Frontline-windows-setup.exe: the usual setup wizard
; (welcome, licence, where to put it, a finish page that offers to start the
; game). The release workflow (.github/workflows/release.yml) builds it with
; NSIS from the Windows export, on Linux like the rest of the build:
;
;   makensis -NOCD -DVERSION=1.2.3 -DVERSION4=1.2.3.0 -DEXE=build/windows/Frontline.exe \
;     -DLICENSE=LICENSE.txt -DOUT=build/Frontline-windows-setup.exe installer/windows.nsi
;
; It installs for the player alone, under their own AppData (where Windows puts
; per-user programs, as VS Code and Discord do), so it needs no administrator
; rights, and so the game can still update itself: the updater
; (scripts/autoload/updater.gd) swaps the executable in place, which it can't
; do in Program Files. It adds Start menu and desktop shortcuts, the
; frontline:// links the website's Join buttons use (the game registers them
; too, the first time it runs: scripts/autoload/links.gd), and an entry in
; Settings > Apps that uninstalls it. Uninstalling leaves the player's settings
; and service record, as games usually do.

Unicode true
ManifestDPIAware true
SetCompressor /SOLID lzma

!include "MUI2.nsh"
!include "FileFunc.nsh"

!define GAME "Frontline.exe"
!define UNINSTALLER "Uninstall Frontline.exe"
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\Frontline"
!define LINKS_KEY "Software\Classes\frontline"
!define WEBSITE "https://web-production-5a4c1.up.railway.app"
!define ICON "${__FILEDIR__}/frontline.ico"

Name "Frontline"
OutFile "${OUT}"
RequestExecutionLevel user
InstallDir "$LOCALAPPDATA\Programs\Frontline"
InstallDirRegKey HKCU "Software\Frontline" "InstallDir"
BrandingText "Frontline ${VERSION}"

VIProductVersion "${VERSION4}"
VIAddVersionKey "ProductName" "Frontline"
VIAddVersionKey "ProductVersion" "${VERSION}"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "FileDescription" "Frontline Setup"
VIAddVersionKey "LegalCopyright" "Copyright (c) 2026 Alexander Dines"

!define MUI_ICON "${ICON}"
!define MUI_UNICON "${ICON}"
!define MUI_WELCOMEFINISHPAGE_BITMAP "${__FILEDIR__}/wizard.bmp"
!define MUI_ABORTWARNING

!define MUI_WELCOMEPAGE_TEXT "This puts Frontline on your computer, for you alone: it needs no administrator rights, and it keeps itself up to date.$\r$\n$\r$\nIf Frontline is running, close it before you go on.$\r$\n$\r$\nClick Next to continue."
!define MUI_FINISHPAGE_RUN "$INSTDIR\${GAME}"
!define MUI_FINISHPAGE_RUN_TEXT "Play Frontline now"
; the finish page's second tick box, which MUI calls Show Readme, offers the
; desktop shortcut
!define MUI_FINISHPAGE_SHOWREADME ""
!define MUI_FINISHPAGE_SHOWREADME_TEXT "Put a shortcut on the desktop"
!define MUI_FINISHPAGE_SHOWREADME_FUNCTION DesktopShortcut

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${LICENSE}"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"


Section "Frontline"
	SetShellVarContext current
	SetOutPath "$INSTDIR"
	File "/oname=${GAME}" "${EXE}"
	File "/oname=LICENSE.txt" "${LICENSE}"
	File "/oname=Frontline.ico" "${ICON}"
	; what an update leaves until the game next starts (updater.gd)
	Delete "$INSTDIR\${GAME}.old"
	WriteUninstaller "$INSTDIR\${UNINSTALLER}"

	CreateShortcut "$SMPROGRAMS\Frontline.lnk" "$INSTDIR\${GAME}" "" "$INSTDIR\Frontline.ico" 0

	; frontline:// links open this copy, exactly as the game registers them itself
	WriteRegStr HKCU "${LINKS_KEY}" "" "URL:Frontline"
	WriteRegStr HKCU "${LINKS_KEY}" "URL Protocol" ""
	WriteRegStr HKCU "${LINKS_KEY}\DefaultIcon" "" '"$INSTDIR\${GAME}",0'
	WriteRegStr HKCU "${LINKS_KEY}\shell\open\command" "" '"$INSTDIR\${GAME}" "%1"'

	; Settings > Apps. No DisplayVersion: the game updates itself, so the
	; version it was installed at would soon be out of date.
	WriteRegStr HKCU "Software\Frontline" "InstallDir" "$INSTDIR"
	WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayName" "Frontline"
	WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\Frontline.ico"
	WriteRegStr HKCU "${UNINSTALL_KEY}" "Publisher" "Alexander Dines"
	WriteRegStr HKCU "${UNINSTALL_KEY}" "URLInfoAbout" "${WEBSITE}"
	WriteRegStr HKCU "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
	WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" '"$INSTDIR\${UNINSTALLER}"'
	WriteRegStr HKCU "${UNINSTALL_KEY}" "QuietUninstallString" '"$INSTDIR\${UNINSTALLER}" /S'
	WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoModify" 1
	WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoRepair" 1
	${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
	WriteRegDWORD HKCU "${UNINSTALL_KEY}" "EstimatedSize" $0
SectionEnd

Function DesktopShortcut
	SetShellVarContext current
	CreateShortcut "$DESKTOP\Frontline.lnk" "$INSTDIR\${GAME}" "" "$INSTDIR\Frontline.ico" 0
FunctionEnd


Section "Uninstall"
	SetShellVarContext current
	Delete "$INSTDIR\${GAME}"
	; the updater's: the version before the last update, and one half-installed
	Delete "$INSTDIR\${GAME}.old"
	Delete "$INSTDIR\${GAME}.new"
	Delete "$INSTDIR\LICENSE.txt"
	Delete "$INSTDIR\Frontline.ico"
	Delete "$INSTDIR\${UNINSTALLER}"
	; only if it's empty now: never anything the player put there
	RMDir "$INSTDIR"

	Delete "$SMPROGRAMS\Frontline.lnk"
	Delete "$DESKTOP\Frontline.lnk"

	; the links, unless another copy of the game has claimed them since
	ReadRegStr $0 HKCU "${LINKS_KEY}\shell\open\command" ""
	StrCmp $0 '"$INSTDIR\${GAME}" "%1"' 0 +2
		DeleteRegKey HKCU "${LINKS_KEY}"

	DeleteRegKey HKCU "${UNINSTALL_KEY}"
	DeleteRegKey HKCU "Software\Frontline"
SectionEnd
