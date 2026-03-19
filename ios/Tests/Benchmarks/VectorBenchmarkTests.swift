import XCTest
@testable import sprinty

/// Performance benchmark suite for sqlite-vec vector similarity search.
/// Measures insert and query latency at 1K, 5K, and 10K vector thresholds.
///
/// These tests are intentionally slow and should NOT run in CI.
/// Run manually on a physical device for representative numbers.
final class VectorBenchmarkTests: XCTestCase {
    private var vectorSearch: VectorSearch!
    private var tempDBPath: String!
    private let embeddingDim = 384

    override func setUp() {
        super.setUp()
        let tempDir = FileManager.default.temporaryDirectory
        tempDBPath = tempDir.appendingPathComponent("bench_\(UUID().uuidString).sqlite").path
        vectorSearch = try! VectorSearch(path: tempDBPath)
        try! vectorSearch.createTable()
    }

    override func tearDown() {
        vectorSearch = nil
        try? FileManager.default.removeItem(atPath: tempDBPath)
        super.tearDown()
    }

    // MARK: - Synthetic Embedding Generator

    /// Generate deterministic synthetic embeddings using a seeded random approach.
    /// Uses a simple linear congruential generator for reproducibility.
    private func generateEmbedding(seed: Int) -> [Float] {
        var state = UInt64(seed &+ 1) &* 6364136223846793005 &+ 1442695040888963407
        return (0..<embeddingDim).map { _ in
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Float(Int64(bitPattern: state >> 33)) / Float(Int32.max)
        }
    }

    // MARK: - Insert Benchmarks

    func testInsert1K() {
        measure {
            let db = try! VectorSearch(path: FileManager.default.temporaryDirectory
                .appendingPathComponent("insert1k_\(UUID().uuidString).sqlite").path)
            try! db.createTable()
            for i in 0..<1_000 {
                try! db.insert(rowid: Int64(i), embedding: generateEmbedding(seed: i))
            }
        }
    }

    func testInsert5K() {
        measure {
            let db = try! VectorSearch(path: FileManager.default.temporaryDirectory
                .appendingPathComponent("insert5k_\(UUID().uuidString).sqlite").path)
            try! db.createTable()
            for i in 0..<5_000 {
                try! db.insert(rowid: Int64(i), embedding: generateEmbedding(seed: i))
            }
        }
    }

    func testInsert10K() {
        measure {
            let db = try! VectorSearch(path: FileManager.default.temporaryDirectory
                .appendingPathComponent("insert10k_\(UUID().uuidString).sqlite").path)
            try! db.createTable()
            for i in 0..<10_000 {
                try! db.insert(rowid: Int64(i), embedding: generateEmbedding(seed: i))
            }
        }
    }

    // MARK: - Query Benchmarks

    private func prepopulateDatabase(count: Int) {
        for i in 0..<count {
            try! vectorSearch.insert(rowid: Int64(i), embedding: generateEmbedding(seed: i))
        }
    }

    func testQuery1K() {
        prepopulateDatabase(count: 1_000)
        let queryVec = generateEmbedding(seed: 999_999)
        measure {
            _ = try! vectorSearch.query(embedding: queryVec, limit: 5)
        }
    }

    func testQuery5K() {
        prepopulateDatabase(count: 5_000)
        let queryVec = generateEmbedding(seed: 999_999)
        measure {
            _ = try! vectorSearch.query(embedding: queryVec, limit: 5)
        }
    }

    func testQuery10K() {
        prepopulateDatabase(count: 10_000)
        let queryVec = generateEmbedding(seed: 999_999)
        measure {
            _ = try! vectorSearch.query(embedding: queryVec, limit: 5)
        }
    }

    // MARK: - Memory Usage

    func testMemoryUsageAtThresholds() {
        let thresholds = [1_000, 5_000, 10_000]
        var results: [(count: Int, memoryMB: Float)] = []

        for threshold in thresholds {
            let baseMemory = Self.availableMemoryMB()

            let db = try! VectorSearch(path: FileManager.default.temporaryDirectory
                .appendingPathComponent("mem_\(threshold)_\(UUID().uuidString).sqlite").path)
            try! db.createTable()

            for i in 0..<threshold {
                try! db.insert(rowid: Int64(i), embedding: generateEmbedding(seed: i))
            }

            let usedMemory = baseMemory - Self.availableMemoryMB()
            results.append((count: threshold, memoryMB: usedMemory))
            print("[\(threshold) vectors] Memory delta: \(String(format: "%.1f", usedMemory)) MB")
        }

        // Log results for documentation
        print("\n=== Memory Usage Results ===")
        for r in results {
            print("  \(r.count) vectors: ~\(String(format: "%.1f", r.memoryMB)) MB")
        }
    }

    // MARK: - Comprehensive Benchmark Report

    func testBenchmarkReport() {
        print("\n" + String(repeating: "=", count: 60))
        print("VECTOR BENCHMARK REPORT")
        print(String(repeating: "=", count: 60))

        let thresholds = [1_000, 5_000, 10_000]

        for threshold in thresholds {
            let db = try! VectorSearch(path: FileManager.default.temporaryDirectory
                .appendingPathComponent("report_\(threshold)_\(UUID().uuidString).sqlite").path)
            try! db.createTable()

            // Measure insert time
            let insertStart = CFAbsoluteTimeGetCurrent()
            for i in 0..<threshold {
                try! db.insert(rowid: Int64(i), embedding: generateEmbedding(seed: i))
            }
            let insertTime = CFAbsoluteTimeGetCurrent() - insertStart

            // Measure query time (average of 10 queries)
            let queryVec = generateEmbedding(seed: 999_999)
            let queryStart = CFAbsoluteTimeGetCurrent()
            let queryIterations = 10
            for _ in 0..<queryIterations {
                _ = try! db.query(embedding: queryVec, limit: 5)
            }
            let avgQueryTime = (CFAbsoluteTimeGetCurrent() - queryStart) / Double(queryIterations)

            let queryMs = avgQueryTime * 1000
            let passNFR5 = queryMs < 500

            print("\n--- \(threshold) vectors ---")
            print("  Insert:  \(String(format: "%.3f", insertTime))s total (\(String(format: "%.3f", insertTime / Double(threshold) * 1000))ms/vector)")
            print("  Query:   \(String(format: "%.1f", queryMs))ms avg (top-5 cosine similarity)")
            print("  NFR5:    \(passNFR5 ? "PASS" : "FAIL") (<500ms at 10K)")
        }

        print("\n" + String(repeating: "=", count: 60))
    }

    // MARK: - Helpers

    private static func availableMemoryMB() -> Float {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            return Float(info.resident_size) / (1024 * 1024)
        }
        return 0
    }
}
