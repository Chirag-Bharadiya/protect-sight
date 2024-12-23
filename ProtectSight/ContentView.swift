import SwiftUI
import AppKit

@main
struct EyeProtectionApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView() // No visible app window
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popupTimer: Timer?
    var popupWindow: CustomWindow?
    var isTimerRunning: Bool = false // Track timer state
    @State private var selectedTime: Int? // To hold selected time in minutes
    @State private var isTimeSelectionVisible: Bool = false // Flag for showing time options

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
    }

    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Eye Protection")
        }

        let menu = NSMenu()
        let toggleTimerMenuItem = NSMenuItem(title: "Start Timer", action: #selector(toggleTimer), keyEquivalent: "t")
        toggleTimerMenuItem.tag = 1 // Tag to identify the menu item
        menu.addItem(toggleTimerMenuItem)

        // Time selection options (hidden by default)
        let timeSelectionMenuItem = NSMenuItem(title: "Select Time", action: nil, keyEquivalent: "")
        timeSelectionMenuItem.isEnabled = false // Disable it initially
        let timeSelectionSubMenu = NSMenu()
        timeSelectionSubMenu.addItem(NSMenuItem(title: "10 Min", action: #selector(selectTime(_:)), keyEquivalent: ""))
        timeSelectionSubMenu.addItem(NSMenuItem(title: "20 Min", action: #selector(selectTime(_:)), keyEquivalent: ""))
        timeSelectionSubMenu.addItem(NSMenuItem(title: "30 Min", action: #selector(selectTime(_:)), keyEquivalent: ""))
        timeSelectionSubMenu.addItem(NSMenuItem(title: "40 Min", action: #selector(selectTime(_:)), keyEquivalent: ""))
        timeSelectionSubMenu.addItem(NSMenuItem(title: "60 Min", action: #selector(selectTime(_:)), keyEquivalent: ""))
//        timeSelectionSubMenu.addItem(NSMenuItem(title: "Custom Time", action: #selector(selectTime(_:)), keyEquivalent: ""))
        timeSelectionMenuItem.submenu = timeSelectionSubMenu
        menu.addItem(timeSelectionMenuItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc func toggleTimer() {
        if isTimerRunning {
            stopPopupTimer()
        } else {
            showTimeSelection() // Show time selection options before starting the timer
        }
    }

    func showTimeSelection() {
        // Enable the time selection menu options after clicking "Start Timer"
        if let menu = statusItem.menu {
            if let timeSelectionMenuItem = menu.items.first(where: { $0.title == "Select Time" }) {
                timeSelectionMenuItem.isEnabled = true // Enable the time options
            }
        }
    }

    @objc func selectTime(_ sender: NSMenuItem) {
        // Parse the selected time from the menu item title
        var time: Int = 0
        switch sender.title {
        case "10 Min":
            time = 10
        case "20 Min":
            time = 20
        case "30 Min":
            time = 30
        case "40 Min":
            time = 40
        case "60 Min":
            time = 60
        default:
            break
        }
        
        if time > 0 {
            startPopupTimer(withTime: time)
        }
    }

    func startPopupTimer(withTime minutes: Int) {
        stopPopupTimer() // Prevent duplicate timers
        isTimerRunning = true
        updateTimerMenuItemTitle(to: "Stop Timer")
        popupTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes * 60), repeats: true) { [weak self] _ in
            self?.showPopup()
        }
        showPopup() // Show immediately
    }

    func stopPopupTimer() {
        isTimerRunning = false
        popupTimer?.invalidate()
        popupTimer = nil
        updateTimerMenuItemTitle(to: "Start Timer")
    }

    func updateTimerMenuItemTitle(to newTitle: String) {
        if let menu = statusItem.menu, let toggleMenuItem = menu.item(withTag: 1) {
            toggleMenuItem.title = newTitle
        }
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func showPopup() {
        DispatchQueue.main.async {
            // Prevent duplicate popups
            guard self.popupWindow == nil else { return }

            // Create a fullscreen window
            let screenFrame = NSScreen.main?.frame ?? .zero
            self.popupWindow = CustomWindow(
                contentRect: screenFrame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )

            // Configure window properties
            self.popupWindow?.level = .screenSaver // Ensure it appears above other windows
            self.popupWindow?.isOpaque = false
            self.popupWindow?.backgroundColor = NSColor.black.withAlphaComponent(0.8)
            self.popupWindow?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            // Add SwiftUI content
            let contentView = NSHostingView(rootView: PopupView { [weak self] in
                self?.dismissPopup()
            })
            self.popupWindow?.contentView = contentView

            // Display the window
            self.popupWindow?.makeKeyAndOrderFront(nil)
        }
    }

    func dismissPopup() {
        DispatchQueue.main.async {
            guard let window = self.popupWindow else { return }
            window.orderOut(nil) // Remove the window from the screen
            self.popupWindow = nil // Release the reference
        }
    }
}

class CustomWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }
}

struct PopupView: View {
    var onDismiss: () -> Void
    @State private var countdown: Int = 10 // 20-second timer
    @State private var progress: Double = 0.0 // Progress for the circular progress bar

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)

            VStack(spacing: 20) {
                Text("Please look somewhere else!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Take a 20-second break to protect your eyes.")
                    .foregroundColor(.white)

                // Circular progress timer
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 8)
                        .frame(width: 120, height: 120)

                    Circle()
                        .trim(from: 0.0, to: CGFloat(progress))
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 120, height: 120)
                        .animation(.linear(duration: 10), value: progress)

                    Text("\(countdown)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }

                Button(action: {
                    onDismiss()
                }) {
                    Text("Skip")
                        .font(.headline)
                        .foregroundColor(.black)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            startCountdown()
        }
    }

    // Countdown timer logic
    private func startCountdown() {
        progress = 1.0 // Start the animation to full circle
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if countdown > 0 {
                countdown -= 1
            } else {
                timer.invalidate()
                onDismiss() // Automatically dismiss after countdown ends
            }
        }
    }
}
