// Arcade Stick Mode: menu bar toggle for an 8BitDo Arcade Controller connected
// over Bluetooth in Switch mode.
//
// macOS puts Switch-Pro-type controllers into a Nintendo-only report (0x30).
// Steam and native Mac games expect that. Fightcade's bundled Wine cannot read
// it and needs the controller's plain HID gamepad report (0x3F) instead.
//
//   Automatic      plain HID while Fightcade is open, Switch mode otherwise
//   Fightcade mode always plain HID
//   Switch mode    always the macOS default
//
// Quitting the app puts the controller back in Switch mode.
import AppKit
import IOKit.hid

let fightcadeBundleID = "com.fightcade2"
let hidMode: UInt8 = 0x3F      // plain HID gamepad reports (Wine / Fightcade)
let switchMode: UInt8 = 0x30   // Nintendo full reports (macOS, Steam)

enum Setting: String { case auto, fightcade, switchMode = "switch" }

final class Controller {
    let device: IOHIDDevice
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 512)
    var mode: UInt8?            // last report type seen from the stick
    var lastSent = Date.distantPast
    var packet: UInt8 = 0
    init(_ d: IOHIDDevice) { device = d }
    deinit { buffer.deallocate() }

    func send(_ target: UInt8, force: Bool = false) {
        guard force || Date().timeIntervalSince(lastSent) > 1 else { return }
        lastSent = Date()
        packet = (packet + 1) & 0x0F
        var out = [UInt8](repeating: 0, count: 49)
        out[0] = 0x01; out[1] = packet
        out[2...9] = [0x00, 0x01, 0x40, 0x40, 0x00, 0x01, 0x40, 0x40]   // neutral rumble
        out[10] = 0x03; out[11] = target                               // set input report mode
        IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, 0x01, out, out.count)
    }
}

final class App: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    var controllers: [IOHIDDevice: Controller] = [:]
    let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    var items: [Setting: NSMenuItem] = [:]

    var setting: Setting {
        get { Setting(rawValue: UserDefaults.standard.string(forKey: "mode") ?? "") ?? .auto }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "mode"); apply() }
    }
    var fightcadeRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == fightcadeBundleID }
    }
    var target: UInt8 {
        switch setting {
        case .fightcade: return hidMode
        case .switchMode: return switchMode
        case .auto: return fightcadeRunning ? hidMode : switchMode
        }
    }

    func applicationDidFinishLaunching(_ note: Notification) {
        let menu = NSMenu()
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())
        for (s, title) in [(Setting.auto, "Automatic (Fightcade mode while Fightcade is open)"),
                           (.fightcade, "Fightcade mode"),
                           (.switchMode, "Switch mode (Steam and other games)")] {
            let item = NSMenuItem(title: title, action: #selector(pick(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = s.rawValue
            items[s] = item; menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit (returns stick to Switch mode)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        // Only the Bluetooth connection: over USB the command format differs.
        IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: 0x057E, kIOHIDProductIDKey: 0x2009,
                                                kIOHIDTransportKey: "Bluetooth"] as CFDictionary)
        let me = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { ctx, _, _, d in
            Unmanaged<App>.fromOpaque(ctx!).takeUnretainedValue().attached(d)
        }, me)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { ctx, _, _, d in
            let app = Unmanaged<App>.fromOpaque(ctx!).takeUnretainedValue()
            app.controllers[d] = nil; app.refresh()
        }, me)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))

        let nc = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] n in
                let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                if app?.bundleIdentifier == fightcadeBundleID { self?.apply() }
            }
        }
        refresh()
    }

    func attached(_ d: IOHIDDevice) {
        let c = Controller(d)
        controllers[d] = c
        IOHIDDeviceRegisterInputReportCallback(d, c.buffer, 512, { ctx, _, sender, _, id, _, _ in
            guard id == UInt32(hidMode) || id == UInt32(switchMode), let sender = sender else { return }
            let app = Unmanaged<App>.fromOpaque(ctx!).takeUnretainedValue()
            let dev = Unmanaged<IOHIDDevice>.fromOpaque(sender).takeUnretainedValue()
            guard let c = app.controllers[dev] else { return }
            if c.mode != UInt8(id) { c.mode = UInt8(id); app.refresh() }
            if UInt8(id) != app.target { c.send(app.target) }     // macOS or a reconnect changed it back
        }, Unmanaged.passUnretained(self).toOpaque())
        c.send(target, force: true)
        refresh()
    }

    @objc func pick(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let s = Setting(rawValue: raw) { setting = s }
    }

    func apply() {
        for c in controllers.values { c.send(target, force: true) }
        refresh()
    }

    func refresh() {
        for (s, item) in items { item.state = s == setting ? .on : .off }
        let live = controllers.values.compactMap { $0.mode }
        let inHID = live.contains(hidMode)
        if controllers.isEmpty { statusLine.title = "Stick not connected" }
        else if live.isEmpty { statusLine.title = "Stick connected" }
        else { statusLine.title = inHID ? "Stick is in Fightcade mode" : "Stick is in Switch mode" }
        let symbol = inHID ? "gamecontroller.fill" : "gamecontroller"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Arcade Stick Mode")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = statusLine.title
    }

    func applicationWillTerminate(_ note: Notification) {
        for c in controllers.values { c.send(switchMode, force: true) }
        CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0.3, false)   // let the command go out
    }
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
