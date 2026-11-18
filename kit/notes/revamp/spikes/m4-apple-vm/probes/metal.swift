// What GPU does this machine (or VM) expose to Metal?
import Foundation
import Metal

guard let d = MTLCreateSystemDefaultDevice() else { print("METAL: no device"); exit(0) }
print("METAL: name=\(d.name) unified=\(d.hasUnifiedMemory) maxWorkingSetMB=\(d.recommendedMaxWorkingSetSize / 1_048_576)")
let families: [(String, MTLGPUFamily)] = [("apple7", .apple7), ("apple8", .apple8), ("apple9", .apple9), ("mac2", .mac2), ("metal3", .metal3)]
for (n, f) in families { print("METAL: supportsFamily \(n)=\(d.supportsFamily(f))") }
