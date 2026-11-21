import AppKit

public final class DragInterceptor {
    private var dragMonitor: Any?
    private var flagsMonitor: Any?
    private var mouseUpMonitor: Any?
    private var isPanelShowing: Bool = false

    public weak var panel: DonutDropPanel?

    public init() {}

    deinit {
        stop()
    }

    public func start() {
        stop()

        // 1. Monitor global mouse drags (with Option modifier held down)
        dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] event in
            guard let self = self else { return }

            if event.modifierFlags.contains(.option) {
                if !self.isPanelShowing {
                    self.isPanelShowing = true
                    DispatchQueue.main.async {
                        self.panel?.present(at: NSEvent.mouseLocation)
                    }
                }
            }
        }

        // 2. Monitor modifier flag changes:
        //    - If Option is pressed while left mouse button is already dragging, summon the wheel immediately!
        //    - If Option is released while the wheel is open, dismiss!
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            guard let self = self else { return }
            let isOptionDown = event.modifierFlags.contains(.option)
            let isLeftMouseDown = (NSEvent.pressedMouseButtons & 1) != 0

            if isOptionDown && isLeftMouseDown && !self.isPanelShowing {
                self.isPanelShowing = true
                DispatchQueue.main.async {
                    self.panel?.present(at: NSEvent.mouseLocation)
                }
            } else if !isOptionDown && self.isPanelShowing {
                self.isPanelShowing = false
                DispatchQueue.main.async {
                    self.panel?.dismiss()
                }
            }
        }

        // 3. Monitor left mouse up (drag ended)
        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            guard let self = self, self.isPanelShowing else { return }
            self.isPanelShowing = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.panel?.dismiss()
            }
        }
    }

    public func stop() {
        if let m = dragMonitor { NSEvent.removeMonitor(m); dragMonitor = nil }
        if let m = flagsMonitor { NSEvent.removeMonitor(m); flagsMonitor = nil }
        if let m = mouseUpMonitor { NSEvent.removeMonitor(m); mouseUpMonitor = nil }
        isPanelShowing = false
    }
}
