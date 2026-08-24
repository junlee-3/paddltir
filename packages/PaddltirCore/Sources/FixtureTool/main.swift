import Foundation
import PaddltirCore

/// Usage:
///   swift run FixtureTool update-greedy fixtures/placement   # rewrite expected.greedy for every fixture
///   swift run FixtureTool check fixtures/placement           # exit 1 if any expected.greedy differs
///   swift run -c release FixtureTool bench fixtures/placement/std-mixed-22.json   # time autoFill
let args = CommandLine.arguments.dropFirst()
guard let command = args.first, let pathArg = args.dropFirst().first else {
    FileHandle.standardError.write(Data("usage: FixtureTool <update-greedy|check|bench> <path>\n".utf8)); exit(2)
}
let url = URL(fileURLWithPath: pathArg)
var isDir: ObjCBool = false
FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
let files: [URL] = isDir.boolValue
    ? (try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)).filter { $0.pathExtension == "json" }.sorted { $0.path < $1.path }
    : [url]

var failures = 0
for file in files {
    var fx = try Fixture.load(from: file)
    let result = Greedy.autoFill(fx.placementRequest)
    let outcome = Fixture.outcome(from: result)
    switch command {
    case "update-greedy":
        var expected = fx.expected ?? Fixture.Expected()
        expected.greedy = outcome
        fx.expected = expected
        try fx.write(to: file)
        print("\(fx.name): seated \(outcome.metrics.seated)  Δw \(outcome.metrics.weightDelta)  side \(outcome.metrics.sideMismatches)  seat \(outcome.metrics.seatMismatches)  Δp \(outcome.metrics.powerDelta)  trim \(outcome.metrics.trimMoment)  rule \(outcome.ruleSatisfied)")
    case "check":
        if fx.expected?.greedy?.seats != outcome.seats { print("MISMATCH \(fx.name)"); failures += 1 } else { print("ok \(fx.name)") }
    case "bench":
        let clock = ContinuousClock()
        var best = Duration.seconds(1)
        for _ in 0..<20 { let d = clock.measure { _ = Greedy.autoFill(fx.placementRequest) }; if d < best { best = d } }
        print("\(fx.name): best of 20 = \(best)")
    default:
        FileHandle.standardError.write(Data("unknown command \(command)\n".utf8)); exit(2)
    }
}
exit(failures == 0 ? 0 : 1)
