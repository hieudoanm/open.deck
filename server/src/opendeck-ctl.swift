// open-deck-ctl — macOS host-control helper invoked by open-deck-server.
// Subcommands: bt-get|bt-set <0|1>, kbd-list, kbd-next,
//              bri-get, bri-set <0-100>
import Foundation
import CoreGraphics
import Carbon

// ---------- Bluetooth (IOBluetooth private prefs API) ----------

typealias BtGetFn = @convention(c) () -> Int32
typealias BtSetFn = @convention(c) (Int32) -> Int32

func btFuncs() -> (BtGetFn, BtSetFn)? {
    guard let h = dlopen(
        "/System/Library/Frameworks/IOBluetooth.framework/IOBluetooth",
        RTLD_NOW
    ) else { return nil }
    guard let gs = dlsym(h, "IOBluetoothPreferenceGetControllerPowerState"),
          let ss = dlsym(h, "IOBluetoothPreferenceSetControllerPowerState")
    else { return nil }
    return (
        unsafeBitCast(gs, to: BtGetFn.self),
        unsafeBitCast(ss, to: BtSetFn.self)
    )
}

func cmdBt(_ args: [String]) -> Int32 {
    guard let (get, set) = btFuncs() else { print("unsupported"); return 3 }
    if args.count > 2 && args[2] == "set" {
        let v = args.count > 3 ? (Int32(args[3]) ?? -1) : -1
        guard v == 0 || v == 1 else { print("usage: bt-set <0|1>"); return 2 }
        let rc = set(v)
        print(rc == 0 ? "ok" : "err:\(rc)")
        return rc == 0 ? 0 : 1
    }
    print(get() == 1 ? "on" : "off")
    return 0
}

// ---------- Keyboard input sources (Carbon HIToolbox TIS) ----------

func tisPropStr(_ src: TISInputSource, _ key: CFString) -> String? {
    guard let p = TISGetInputSourceProperty(src, key) else { return nil }
    return Unmanaged<CFTypeRef>.fromOpaque(p).takeUnretainedValue() as? String
}

func tisPropBool(_ src: TISInputSource, _ key: CFString) -> Bool {
    guard let p = TISGetInputSourceProperty(src, key) else { return false }
    return Unmanaged<CFBoolean>.fromOpaque(p).takeUnretainedValue() == kCFBooleanTrue
}

func keyboardSources() -> [TISInputSource] {
    let props: [String: Any] = [
        kTISPropertyInputSourceCategory as String:
            kTISCategoryKeyboardInputSource as String,
    ]
    guard let all = TISCreateInputSourceList(props as CFDictionary, false)?
        .takeRetainedValue() as? [TISInputSource]
    else { return [] }
    return all.filter { src in
        tisPropBool(src, kTISPropertyInputSourceIsSelectCapable)
            && tisPropStr(src, kTISPropertyInputSourceType)
                != "KeyboardInputMethodMode"
    }
}

func cmdKbd(_ args: [String]) -> Int32 {
    let sources = keyboardSources()
    if args.count > 2 && args[2] == "next" {
        guard let cur = TISCopyCurrentKeyboardInputSource()?
            .takeRetainedValue(),
            let curId = tisPropStr(cur, kTISPropertyInputSourceID),
            let idx = sources.firstIndex(where: {
                tisPropStr($0, kTISPropertyInputSourceID) == curId
            })
        else { print("[]"); return 1 }
        let next = sources[(idx + 1) % sources.count]
        let st = TISSelectInputSource(next)
        print(st == noErr ? "ok" : "err:\(st)")
        return st == noErr ? 0 : 1
    }
    // JSON array: [{"name","id","current"}]
    var curId: String? = nil
    if let cur = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() {
        curId = tisPropStr(cur, kTISPropertyInputSourceID)
    }
    var rows: [[String: Any]] = []
    for src in sources {
        rows.append([
            "name": tisPropStr(src, kTISPropertyLocalizedName) ?? "?",
            "id": tisPropStr(src, kTISPropertyInputSourceID) ?? "?",
            "current": tisPropStr(src, kTISPropertyInputSourceID) == curId,
        ])
    }
    if let data = try? JSONSerialization.data(withJSONObject: rows),
       let s = String(data: data, encoding: .utf8) {
        print(s)
    } else {
        print("[]")
    }
    return 0
}

// ---------- Display brightness (private DisplayServices framework) ----------

typealias BriGetFn = @convention(c) (
    CGDirectDisplayID, UnsafeMutablePointer<Float>
) -> Int32
typealias BriSetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32

func briFuncs() -> (BriGetFn, BriSetFn, [CGDirectDisplayID])? {
    guard let h = dlopen(
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
        RTLD_NOW
    ), let gs = dlsym(h, "DisplayServicesGetBrightness"),
        let ss = dlsym(h, "DisplayServicesSetBrightness")
    else { return nil }
    var count: UInt32 = 0
    CGGetActiveDisplayList(0, nil, &count)
    var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
    CGGetActiveDisplayList(count, &ids, nil)
    return (
        unsafeBitCast(gs, to: BriGetFn.self),
        unsafeBitCast(ss, to: BriSetFn.self),
        ids
    )
}

func cmdBri(_ args: [String]) -> Int32 {
    guard let (get, set, ids) = briFuncs() else {
        print("unsupported"); return 3
    }
    if args.count > 2 && args[2] == "set" {
        guard let pct = Int(args.count > 3 ? args[3] : ""),
              (0...100).contains(pct)
        else { print("usage: bri-set <0-100>"); return 2 }
        let v = Float(pct) / 100.0
        var ok = false
        for id in ids {
            var b: Float = 0
            if get(id, &b) == 0 && set(id, v) == 0 { ok = true }
        }
        print(ok ? "ok" : "err")
        return ok ? 0 : 1
    }
    // Report the brightest active display's level as a percent.
    var best = -1
    for id in ids {
        var b: Float = 0
        if get(id, &b) == 0 {
            best = max(best, Int((b * 100).rounded()))
        }
    }
    print(best >= 0 ? "\(best)" : "unsupported")
    return best >= 0 ? 0 : 3
}

// ---------- dispatch ----------

let a = CommandLine.arguments
guard a.count > 1 else { exit(2) }
let code: Int32
switch a[1] {
case "bt": code = cmdBt(a)
case "kbd": code = cmdKbd(a)
case "bri": code = cmdBri(a)
default: code = 2
}
exit(code)
