import Foundation
import NitroModules

@objc(NitroAudioRecorderPlayerOnLoad)
public class NitroAudioRecorderPlayerOnLoad: NSObject {
    @objc
    public static func load() {
        NitroModules.register(HybridAudioRecorderPlayer.self)
    }
}