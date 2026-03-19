import Foundation
import Testing
@testable import sprinty

@Suite("VectorSearch Tests")
struct VectorSearchTests {
    private func createTempDatabasePath() -> String {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("test_vec_\(UUID().uuidString).sqlite").path
    }

    private func makeEmbedding(seed: Float = 1.0) -> [Float] {
        (0..<384).map { Float($0) * seed * 0.001 }
    }

    @Test("Create vec0 virtual table succeeds")
    func createTable() throws {
        let path = createTempDatabasePath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let vectorSearch = try VectorSearch(path: path)
        try vectorSearch.createTable()
        let count = try vectorSearch.count()
        #expect(count == 0)
    }

    @Test("Insert and query vectors returns correct results")
    func insertAndQuery() throws {
        let path = createTempDatabasePath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let vectorSearch = try VectorSearch(path: path)
        try vectorSearch.createTable()

        let embedding1 = makeEmbedding(seed: 1.0)
        let embedding2 = makeEmbedding(seed: 2.0)
        let embedding3 = makeEmbedding(seed: 3.0)

        try vectorSearch.insert(rowid: 1, embedding: embedding1)
        try vectorSearch.insert(rowid: 2, embedding: embedding2)
        try vectorSearch.insert(rowid: 3, embedding: embedding3)

        #expect(try vectorSearch.count() == 3)

        // Query with embedding close to embedding1
        let queryVec = makeEmbedding(seed: 1.01)
        let results = try vectorSearch.query(embedding: queryVec, limit: 5)

        #expect(!results.isEmpty)
        // Closest match should be rowid 1 (seed 1.0 is closest to 1.01)
        #expect(results.first?.rowid == 1)
    }

    @Test("Query returns results ordered by distance")
    func queryOrderedByDistance() throws {
        let path = createTempDatabasePath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let vectorSearch = try VectorSearch(path: path)
        try vectorSearch.createTable()

        try vectorSearch.insert(rowid: 1, embedding: makeEmbedding(seed: 1.0))
        try vectorSearch.insert(rowid: 2, embedding: makeEmbedding(seed: 5.0))
        try vectorSearch.insert(rowid: 3, embedding: makeEmbedding(seed: 10.0))

        let queryVec = makeEmbedding(seed: 4.5)
        let results = try vectorSearch.query(embedding: queryVec, limit: 3)

        #expect(results.count == 3)
        // Distances should be ascending
        for i in 0..<(results.count - 1) {
            #expect(results[i].distance <= results[i + 1].distance)
        }
    }

    @Test("Query limit is respected")
    func queryLimit() throws {
        let path = createTempDatabasePath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let vectorSearch = try VectorSearch(path: path)
        try vectorSearch.createTable()

        for i in 1...10 {
            try vectorSearch.insert(rowid: Int64(i), embedding: makeEmbedding(seed: Float(i)))
        }

        let results = try vectorSearch.query(embedding: makeEmbedding(seed: 5.0), limit: 3)
        #expect(results.count == 3)
    }

    @Test("Invalid dimension embedding throws error")
    func invalidDimension() throws {
        let path = createTempDatabasePath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let vectorSearch = try VectorSearch(path: path)
        try vectorSearch.createTable()

        let shortEmbedding = [Float](repeating: 0.0, count: 128)
        #expect(throws: VectorSearchError.self) {
            try vectorSearch.insert(rowid: 1, embedding: shortEmbedding)
        }
    }

    @Test("Delete all removes all vectors")
    func deleteAll() throws {
        let path = createTempDatabasePath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let vectorSearch = try VectorSearch(path: path)
        try vectorSearch.createTable()

        try vectorSearch.insert(rowid: 1, embedding: makeEmbedding(seed: 1.0))
        try vectorSearch.insert(rowid: 2, embedding: makeEmbedding(seed: 2.0))
        #expect(try vectorSearch.count() == 2)

        try vectorSearch.deleteAll()
        #expect(try vectorSearch.count() == 0)
    }

    @Test("Query on empty table returns empty results")
    func queryEmptyTable() throws {
        let path = createTempDatabasePath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let vectorSearch = try VectorSearch(path: path)
        try vectorSearch.createTable()

        let results = try vectorSearch.query(embedding: makeEmbedding(seed: 1.0), limit: 5)
        #expect(results.isEmpty)
    }
}
