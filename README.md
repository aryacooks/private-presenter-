# Private Presenter

A floating, editable presenter-notes app for **Windows x64** and **macOS 13+**. Paste formatted notes, manage pages, and hide the window to the system tray or menu bar without quitting.

## Install on Windows

Open **PowerShell** and paste:

```powershell
irm https://raw.githubusercontent.com/aryacooks/private-presenter-/main/scripts/install-windows.ps1 | iex
```

Downloads the latest self-contained Windows x64 build, checks its SHA-256 checksum, installs it under `%LOCALAPPDATA%\Programs\Private Presenter`, adds a Start menu shortcut, and opens it. No administrator access, Git, or .NET installation is required. Requires 64-bit Windows 10 version 2004 or later, or Windows 11. On ARM Windows, the x64 build needs x64 emulation.

You can [read the installer](scripts/install-windows.ps1) before running it, or download and extract the Windows ZIP from [Releases](https://github.com/aryacooks/private-presenter-/releases/latest) and run `PrivatePresenter.exe` directly. Builds are not publisher-signed; Windows may display a reputation warning. Do not disable Windows security settings.

## Install on Mac

Open **Terminal** and paste:

```sh
curl -fsSL https://raw.githubusercontent.com/aryacooks/private-presenter-/main/scripts/install-macos.sh | bash
```

Downloads the latest universal build for Apple Silicon and Intel, checks its SHA-256 checksum and app signature, installs it in `~/Applications`, and opens it. No Xcode or Git is required. This installer does not change a copy already in `/Applications`.

You can [read the installer](scripts/install-macos.sh) first, or download and extract the Mac ZIP from [Releases](https://github.com/aryacooks/private-presenter-/releases/latest). The Mac app is ad-hoc signed, not Apple-notarized, so macOS may require you to approve the first launch using its normal **Privacy & Security → Open Anyway** flow. The installer does not remove quarantine or disable Gatekeeper.

For either platform, quit the app using its tray/menu-bar **Quit** command before running the installer again to update. Documents are stored separately from the installed app.

## Using the app

- **Paste:** Command-V on Mac or Ctrl-V on Windows inserts at the cursor. **Paste into Page** appends to the selected page. RTF preserves fonts, sizes, colours, and paragraph styles. Mac also accepts HTML formatting; Windows uses native rich-text paste and falls back to text when the source supplies no RTF.
- **Pages:** Add, duplicate, clear, or delete pages. Right-click a page for its actions. Deleting the last page leaves one blank page. Pages form one continuous scrollable document.
- **Clean All Formatting:** Keeps text and page divisions while applying regular 22-point text with consistent alignment. Mac uses white text on its dark editor; Windows uses black text on white.
- **Clear All:** Asks before replacing the document with one blank page. Save As first to keep a separate copy.
- **Formatting:** Bold, italic, underline, size, alignment, and a document zoom slider. Zoom does not change saved font sizes.
- **Close button:** Hides the window and saves an autosave. The app keeps running. Restore it through its menu-bar icon on Mac or by double-clicking its Windows tray icon. Right-click the Windows tray icon for its menu. Windows may place the icon in the tray overflow under the up arrow.
- **Quit:** Use the tray/menu-bar Quit command, Command-Q on Mac, or Ctrl-Q on Windows.
- **Window:** Always on top, with adjustable opacity. Windows also offers an always-on-top switch.

### File support

| | Mac | Windows |
|---|---|---|
| Open/save `.ppdoc` projects | Yes | Yes |
| Open `.rtf`, `.txt`, `.md` | Yes | Yes |
| Open `.docx`, `.pdf` | Yes | Export as RTF/text first |
| Formatted paste | RTF and HTML | Native RTF; text fallback |
| Window hide/restore | Menu bar | System tray |

`.ppdoc` uses the same version-1 JSON container with base64 RTF pages on both platforms. Fonts that are missing on the other platform are substituted. Rich-text rendering can differ between Apple and Windows editors. Windows imports each RTF/text file as one logical page; Mac repaginates document imports.

### Autosave locations

- Mac: `~/Library/Application Support/Private Presenter/Autosave.ppdoc`
- Windows: `%LOCALAPPDATA%\Private Presenter\Autosave.ppdoc`

Autosave restores on the next launch. Use Save or Save As for a named `.ppdoc` project. The Windows app allows one instance per user session; opening it again restores the existing window.

### Shortcuts

| Action | Mac | Windows |
|---|---|---|
| Open | Command-O | Ctrl-O |
| Save / Save As | Command-S / Command-Shift-S | Ctrl-S / Ctrl-Shift-S |
| Add page | Command-Shift-N | Ctrl-Shift-N |
| Bold / Italic / Underline | Command-B / I / U | Ctrl-B / I / U |
| Quit | Command-Q | Ctrl-Q |

Mac also supports Command-[ / ] for previous/next page and Command-1 through Command-9 for page jumps.

## Screen-capture limitations

This is not a guarantee of invisibility during screen sharing. Test your exact meeting app and sharing mode before relying on it.

Mac requests the legacy `NSWindow.sharingType.none` setting, which modern macOS capture paths may ignore. Its local capture preview cannot certify Zoom, Meet, or Teams behaviour. Sharing one application window or placing notes on a separate unshared display is the dependable arrangement.

Windows requests [`WDA_EXCLUDEFROMCAPTURE`](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setwindowdisplayaffinity) by default. Microsoft supports it from Windows 10 version 2004, but says display affinity is not a strict protection guarantee. The footer shows whether Windows accepted the request; the checkbox can turn it off. Successful acceptance does not certify every third-party recorder.

## Build from source

### Mac

Requires Xcode command-line tools and Swift 5.9 or later:

```sh
git clone https://github.com/aryacooks/private-presenter-.git
cd private-presenter-
./build_app.sh
open 'dist/Private Presenter.app'
```

For a universal build, run `PRIVATE_PRESENTER_UNIVERSAL=1 ./build_app.sh`. Builds write only to `.build` and `dist`; building does not install or modify an existing app. Run `swift test` for the Mac tests.

### Windows

Requires the [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0) and Git:

```powershell
git clone https://github.com/aryacooks/private-presenter-.git
cd private-presenter-
dotnet publish Windows/PrivatePresenter/PrivatePresenter.csproj -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o dist/windows
.\dist\windows\PrivatePresenter.exe
```

Run the executable with `--self-test` to check rich-text persistence, Unicode, page operations, autosave, and hide/restore lifecycle. GitHub Actions runs these on Windows and the Swift tests on macOS before publishing release ZIPs and checksums. Push a version tag such as `v1.1.0` to publish both builds; a workflow dispatch builds test artifacts without publishing.
