# Private Presenter for macOS

A native floating document overlay with best-effort compatibility for older macOS window-capture paths.

Requires macOS 13 or later. This version uses Apple's AppKit and SwiftUI frameworks and does not run on Windows. Windows support would require a separate implementation of the window, rich-text editor, and system-tray controls.

While running, Private Presenter appears as a document icon in the macOS menu bar. Click it to show or hide the window, open/save a document, manage pages, clean formatting, clear everything, or quit. Hiding the window keeps the menu-bar icon available so you can bring it back.

## Build and run

```sh
chmod +x build_app.sh
./build_app.sh
open "dist/Private Presenter.app"
```

Open a `.docx`, `.rtf`, `.txt`, `.md`, or `.pdf` file, then use the arrow controls to change pages. PDF gives the most predictable page boundaries; Word and text files are repaginated for the overlay.

The app opens as an editable untitled document. Type directly on a page, add pages from the sidebar, select any page to edit it, and paste with **Command-V**. **Paste into Page** appends the clipboard to the selected page. Both paste methods preserve fonts, sizes, colours, emphasis, and paragraph formatting supplied as RTF or HTML by the source app. Plain-text clipboards use the editor's text style. The size slider zooms the document without changing its saved font sizes.

The page navigator is on the right. Click-through behavior is intentionally disabled: ordinary left-clicks, right-clicks, and switching to another app do not hide the presenter. Close it only with the window's red close button or **Command-Q**.

Use **Page actions** below the page list to duplicate the selected page, clear its text, or delete it. Right-click any page in the list for the same actions on that page. Deleting the only remaining page leaves one blank page.

All logical pages render as one continuous, gapless document in the main editor. Scroll normally to move into the next page; there is no page transition or separate next-page action. The right sidebar follows the currently visible page and can still be used for direct jumps.

Fast page controls:

- **Command-Shift-N** adds a page.
- **Command-[** and **Command-]** move backward and forward.
- **Command-1** through **Command-9** jump directly to those pages.

Documents are automatically recovered from `~/Library/Application Support/Private Presenter/Autosave.ppdoc` when the app reopens. Use **Command-S** to save a reusable `.ppdoc` project and **Command-O** to reopen it later.

Select text and use the formatting toolbar for bold, italic, underline, font size, and left/center/right alignment. Standard **Command-B**, **Command-I**, and **Command-U** shortcuts are also available.

The **Document** menu in the bottom bar includes **Clean Formatting — All Pages**, which keeps the text and page divisions while applying regular 22-point system text in white, left alignment, and consistent spacing. It removes copied fonts, colours, highlights, and other styling. **Clear All…** asks for confirmation, then replaces all pages with one blank page. These changes autosave; use Save As first to keep a separate copy.

## Critical limitation

The app requests `NSWindow.SharingType.none` for compatibility with older capture paths. Apple now documents this as a legacy value that macOS no longer uses and explicitly says not to rely on it to hide or omit content from capture. Zoom, Google Meet, and Teams control their own ScreenCaptureKit streams; this app cannot force those streams to exclude its window when you share an entire display.

The built-in **Local Capture Test** is diagnostic only and cannot certify modern meeting-app behavior. Test a real private meeting recording with the exact app and sharing mode. The dependable arrangement is to put the presenter on a separate, unshared display (another monitor, Sidecar iPad, or another device) or share one application window instead of the whole display.
