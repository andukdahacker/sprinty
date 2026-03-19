import Foundation

enum EmbeddingTestHelpers {
    static func vocabURL() throws -> URL {
        let bundle = appBundle()
        if let url = bundle.url(forResource: "vocab", withExtension: "txt") {
            return url
        }
        let sourcePath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("sprinty/Resources/vocab.txt")
        guard FileManager.default.fileExists(atPath: sourcePath.path) else {
            throw EmbeddingTestError.missingResource("vocab.txt")
        }
        return sourcePath
    }

    static func modelURL() throws -> URL {
        let bundle = appBundle()
        if let url = bundle.url(forResource: "MiniLM", withExtension: "mlmodelc") {
            return url
        }
        if let url = bundle.url(forResource: "MiniLM", withExtension: "mlpackage") {
            return url
        }
        let sourcePath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("sprinty/Resources/MiniLM.mlpackage")
        guard FileManager.default.fileExists(atPath: sourcePath.path) else {
            throw EmbeddingTestError.missingResource("MiniLM model — run scripts/convert_model.py first")
        }
        return sourcePath
    }

    static func appBundle() -> Bundle {
        let testBundle = Bundle(for: BundleMarker.self)
        let appBundleURL = testBundle.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return Bundle(url: appBundleURL) ?? testBundle
    }
}

enum EmbeddingTestError: Error {
    case missingResource(String)
}

private final class BundleMarker {}
