@testable import sprinty
import Foundation

final class MockVectorSearch: VectorSearchProtocol, @unchecked Sendable {
    var createTableCallCount: Int = 0
    var insertedItems: [(rowid: Int64, embedding: [Float])] = []
    var stubbedQueryResults: [VectorSearchResult] = []
    var stubbedError: Error?
    var stubbedCount: Int = 0
    var deleteAllCallCount: Int = 0
    var deletedRowids: [Int64] = []
    var insertFailOnce: Bool = false

    func createTable() throws {
        createTableCallCount += 1
        if let error = stubbedError {
            throw error
        }
    }

    func insert(rowid: Int64, embedding: [Float]) throws {
        if let error = stubbedError {
            throw error
        }
        if insertFailOnce {
            insertFailOnce = false
            throw NSError(domain: "MockVectorSearch", code: 1, userInfo: [NSLocalizedDescriptionKey: "Simulated insert failure"])
        }
        insertedItems.append((rowid: rowid, embedding: embedding))
    }

    func query(embedding: [Float], limit: Int) throws -> [VectorSearchResult] {
        if let error = stubbedError {
            throw error
        }
        return Array(stubbedQueryResults.prefix(limit))
    }

    func count() throws -> Int {
        if let error = stubbedError {
            throw error
        }
        return stubbedCount
    }

    func delete(rowid: Int64) throws {
        if let error = stubbedError {
            throw error
        }
        deletedRowids.append(rowid)
        insertedItems.removeAll { $0.rowid == rowid }
    }

    func deleteAll() throws {
        deleteAllCallCount += 1
        if let error = stubbedError {
            throw error
        }
        insertedItems.removeAll()
    }
}
