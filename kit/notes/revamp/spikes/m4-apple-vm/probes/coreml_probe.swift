// Which compute devices does Core ML see here, where would it run each op, and how fast is each unit?
import CoreML
import Foundation

let url = URL(fileURLWithPath: CommandLine.arguments[1]) // a compiled .mlmodelc

for dev in MLModel.availableComputeDevices {
    switch dev {
    case .cpu: print("COREML: device cpu")
    case .gpu(let g): print("COREML: device gpu \(g.metalDevice.name)")
    case .neuralEngine(let n): print("COREML: device neuralEngine cores=\(n.totalCoreCount)")
    @unknown default: print("COREML: device unknown")
    }
}

let cfg = MLModelConfiguration()
cfg.computeUnits = .all
let plan = try await MLComputePlan.load(contentsOf: url, configuration: cfg)
if case .program(let program) = plan.modelStructure, let main = program.functions["main"] {
    var preferred: [String: Int] = [:]
    for op in main.block.operations {
        guard let usage = plan.deviceUsage(for: op) else { continue }
        let p: String
        switch usage.preferred {
        case .cpu: p = "cpu"
        case .gpu: p = "gpu"
        case .neuralEngine: p = "neuralEngine"
        @unknown default: p = "unknown"
        }
        preferred["\(op.operatorName)@\(p)", default: 0] += 1
    }
    print("COREML: plan with .all (op@preferredDevice: count) \(preferred.sorted { $0.key < $1.key })")
}

let input = try MLMultiArray(shape: [1, 512], dataType: .float32)
for i in 0..<512 { input[i] = NSNumber(value: Float(i % 7) * 0.1) }
let units: [(String, MLComputeUnits)] = [("cpuOnly", .cpuOnly), ("cpuAndGPU", .cpuAndGPU),
                                         ("cpuAndNeuralEngine", .cpuAndNeuralEngine), ("all", .all)]
for (name, u) in units {
    let c = MLModelConfiguration()
    c.computeUnits = u
    do {
        let model = try MLModel(contentsOf: url, configuration: c)
        let inputName = model.modelDescription.inputDescriptionsByName.keys.first!
        let provider = try MLDictionaryFeatureProvider(dictionary: [inputName: input])
        _ = try model.prediction(from: provider)
        let t0 = Date()
        for _ in 0..<500 { _ = try model.prediction(from: provider) }
        print(String(format: "COREML: %@ 500 predictions %.1f ms", name, Date().timeIntervalSince(t0) * 1000))
    } catch {
        print("COREML: \(name) error \(error)")
    }
}
