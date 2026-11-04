import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var panel: PresenterPanel!
    private let model = PresenterModel()
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installMenu()

        let rootView = PresenterView(model: model)
        let hostingView = NSHostingView(rootView: rootView)

        panel = PresenterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 660),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Private Presenter"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.sharingType = .none
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.contentView = hostingView
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        model.attach(panel: panel)
        installStatusItem()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        model.saveAutosaveNow()
        sender.orderOut(nil)
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPresenter()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.saveAutosaveNow()
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let icon = NSImage(systemSymbolName: "doc.text", accessibilityDescription: "Private Presenter")
            icon?.isTemplate = true
            button.image = icon
            button.toolTip = "Private Presenter"
            button.setAccessibilityLabel("Private Presenter")
        }

        let menu = NSMenu(title: "Private Presenter")
        let actions: [(String, Selector)] = [
            ("Show Private Presenter", #selector(showPresenter)),
            ("Hide Window", #selector(hidePresenter)),
            ("", #selector(showPresenter)),
            ("Open Document…", #selector(openDocument)),
            ("Save", #selector(saveDocument)),
            ("", #selector(showPresenter)),
            ("Add Page", #selector(addPage)),
            ("Duplicate Current Page", #selector(duplicatePage)),
            ("Clear Current Page Text", #selector(clearPage)),
            ("Delete Current Page", #selector(deletePage)),
            ("", #selector(showPresenter)),
            ("Clean Formatting — All Pages", #selector(cleanFormatting)),
            ("Clear All…", #selector(clearAll)),
            ("", #selector(showPresenter))
        ]
        for (title, action) in actions {
            if title.isEmpty {
                menu.addItem(.separator())
            } else {
                let entry = menu.addItem(withTitle: title, action: action, keyEquivalent: "")
                entry.target = self
            }
        }
        let quit = menu.addItem(withTitle: "Quit Private Presenter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        quit.target = NSApp
        item.menu = menu
        statusItem = item
    }

    @objc private func showPresenter() {
        panel.deminiaturize(nil)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func hidePresenter() { panel.orderOut(nil) }
    @objc private func duplicatePage() { model.duplicatePage(at: model.currentPage) }
    @objc private func clearPage() { model.clearPage(at: model.currentPage) }
    @objc private func deletePage() { model.deleteCurrentPage() }
    @objc private func cleanFormatting() { model.cleanAllFormatting() }
    @objc private func clearAll() {
        showPresenter()
        model.confirmClearAll()
    }

    private func installMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "New Document", action: #selector(newDocument), keyEquivalent: "n")
        let addPageItem = appMenu.addItem(withTitle: "Add Page", action: #selector(addPage), keyEquivalent: "n")
        addPageItem.keyEquivalentModifierMask = [.command, .shift]
        appMenu.addItem(withTitle: "Open Document…", action: #selector(openDocument), keyEquivalent: "o")
        appMenu.addItem(withTitle: "Save", action: #selector(saveDocument), keyEquivalent: "s")
        let saveAsItem = appMenu.addItem(withTitle: "Save As…", action: #selector(saveDocumentAs), keyEquivalent: "s")
        saveAsItem.keyEquivalentModifierMask = [.command, .shift]
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Previous Page", action: #selector(previousPage), keyEquivalent: "[")
        appMenu.addItem(withTitle: "Next Page", action: #selector(nextPage), keyEquivalent: "]")
        for pageNumber in 1...9 {
            let item = appMenu.addItem(
                withTitle: "Go to Page \(pageNumber)",
                action: #selector(selectPage(_:)),
                keyEquivalent: "\(pageNumber)"
            )
            item.tag = pageNumber - 1
        }
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Private Presenter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu

        let formatItem = NSMenuItem()
        mainMenu.addItem(formatItem)
        let formatMenu = NSMenu(title: "Format")
        formatMenu.addItem(withTitle: "Bold", action: #selector(toggleBold), keyEquivalent: "b")
        formatMenu.addItem(withTitle: "Italic", action: #selector(toggleItalic), keyEquivalent: "i")
        formatMenu.addItem(withTitle: "Underline", action: #selector(toggleUnderline), keyEquivalent: "u")
        formatItem.submenu = formatMenu
        NSApp.mainMenu = mainMenu
    }

    @objc private func newDocument() { model.newDocument() }
    @objc private func addPage() { model.addPage() }
    @objc private func openDocument() {
        showPresenter()
        model.openDocument()
    }
    @objc private func saveDocument() {
        showPresenter()
        model.saveDocument()
    }
    @objc private func saveDocumentAs() { model.saveDocumentAs() }
    @objc private func toggleBold() { model.toggleBold() }
    @objc private func toggleItalic() { model.toggleItalic() }
    @objc private func toggleUnderline() { model.toggleUnderline() }
    @objc private func previousPage() { model.previousPage() }
    @objc private func nextPage() { model.nextPage() }
    @objc private func selectPage(_ sender: NSMenuItem) { model.jump(to: sender.tag) }
}

final class PresenterPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
