import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var dropPanel: DonutDropPanel?
    private var dragInterceptor: DragInterceptor?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // 1. Initialize the Donut Drop Panel
        let panel = DonutDropPanel()
        self.dropPanel = panel

        // 2. Initialize the Global Option+Drag Interceptor
        let interceptor = DragInterceptor()
        interceptor.panel = panel
        interceptor.start()
        self.dragInterceptor = interceptor

        // 3. Setup Status Bar Menu
        setupStatusBar()

        print("[FileWheel] Ready! Drag any file in Finder while holding Option.")
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            if let customURL = Bundle.main.url(forResource: "MenuBarTemplate", withExtension: "png"),
               let customImg = NSImage(contentsOf: customURL) {
                customImg.size = NSSize(width: 18, height: 18)
                customImg.isTemplate = true
                button.image = customImg
            } else {
                button.image = NSImage(
                    systemSymbolName: "arrow.triangle.2.circlepath.circle",
                    accessibilityDescription: "FileWheel"
                )
            }
        }

        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "FileWheel (⌥ Drag to Convert)", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(
            title: "Test Donut at Cursor",
            action: #selector(testDonutAtCursor),
            keyEquivalent: "t"
        ))

        menu.addItem(NSMenuItem(
            title: "How to Use FileWheel",
            action: #selector(showHowToUse),
            keyEquivalent: ""
        ))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(
            title: "Quit FileWheel",
            action: #selector(quitApp),
            keyEquivalent: "q"
        ))

        statusItem?.menu = menu
    }

    @objc private func testDonutAtCursor() {
        let cursor = NSEvent.mouseLocation
        dropPanel?.present(at: cursor)
    }

    @objc private func showHowToUse() {
        let alert = NSAlert()
        alert.messageText = "How to Use FileWheel"
        alert.informativeText = """
        1. Select any file in Finder, on your Desktop, or in your browser (e.g., photo.heic, image.png, video.mp4).
        2. Hold the Option (⌥) key on your keyboard.
        3. Start dragging the file — the Donut Menu will pop up around your cursor!
        4. Hover over any target format (WebP, PNG, JPG, or AI Background Cutout) and drop!
        
        The converted file is instantly created right next to your original file.
        """
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
