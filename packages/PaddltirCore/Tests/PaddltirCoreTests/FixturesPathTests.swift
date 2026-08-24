import Foundation
import Testing
@testable import PaddltirCore

@Suite struct FixturesPathTests {
    @Test func fixturesDirectoryResolves() {
        #expect(FileManager.default.fileExists(atPath: fixturesURL().appendingPathComponent("README.md").path))
    }
}
