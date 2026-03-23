import Foundation
import SQLiteVecKit
import CSQLiteVecKit

struct VectorSearchResult: Sendable, Equatable {
    let rowid: Int64
    let distance: Float
}

protocol VectorSearchProtocol: Sendable {
    func createTable() throws
    func insert(rowid: Int64, embedding: [Float]) throws
    func query(embedding: [Float], limit: Int) throws -> [VectorSearchResult]
    func count() throws -> Int
    func deleteAll() throws
    func delete(rowid: Int64) throws
}

// @unchecked Sendable: thread-safe via NSLock protecting all db access
final class VectorSearch: VectorSearchProtocol, @unchecked Sendable {
    private let db: OpaquePointer?
    private let lock = NSLock()

    init(path: String) throws {
        SQLiteVecKit.initialize()
        var db: OpaquePointer?
        let rc = csvk_open(path, &db)
        guard rc == CSVK_OK else {
            let message = db.flatMap { String(cString: csvk_errmsg($0)) } ?? "Unknown error"
            csvk_close(db)
            throw VectorSearchError.openFailed(message)
        }
        self.db = db
    }

    deinit {
        csvk_close(db)
    }

    func createTable() throws {
        try execute("CREATE VIRTUAL TABLE IF NOT EXISTS vec_items USING vec0(embedding float[384])")
    }

    func insert(rowid: Int64, embedding: [Float]) throws {
        guard embedding.count == 384 else {
            throw VectorSearchError.invalidDimension(expected: 384, got: embedding.count)
        }
        let sql = "INSERT INTO vec_items(rowid, embedding) VALUES (?, ?)"
        try lock.withLock {
            var stmt: OpaquePointer?
            defer { csvk_finalize(stmt) }
            guard csvk_prepare(db, sql, &stmt) == CSVK_OK else {
                throw VectorSearchError.queryFailed(errorMessage())
            }
            csvk_bind_int64(stmt, 1, rowid)
            embedding.withUnsafeBufferPointer { buffer in
                csvk_bind_blob(stmt, 2, buffer.baseAddress, Int32(buffer.count * MemoryLayout<Float>.size))
            }
            guard csvk_step(stmt) == CSVK_DONE else {
                throw VectorSearchError.queryFailed(errorMessage())
            }
        }
    }

    func query(embedding: [Float], limit: Int) throws -> [VectorSearchResult] {
        guard embedding.count == 384 else {
            throw VectorSearchError.invalidDimension(expected: 384, got: embedding.count)
        }
        let sql = "SELECT rowid, distance FROM vec_items WHERE embedding MATCH ? ORDER BY distance LIMIT ?"
        return try lock.withLock {
            var stmt: OpaquePointer?
            defer { csvk_finalize(stmt) }
            guard csvk_prepare(db, sql, &stmt) == CSVK_OK else {
                throw VectorSearchError.queryFailed(errorMessage())
            }
            embedding.withUnsafeBufferPointer { buffer in
                csvk_bind_blob(stmt, 1, buffer.baseAddress, Int32(buffer.count * MemoryLayout<Float>.size))
            }
            csvk_bind_int(stmt, 2, Int32(limit))

            var results: [VectorSearchResult] = []
            while csvk_step(stmt) == CSVK_ROW {
                let rowid = csvk_column_int64(stmt, 0)
                let distance = Float(csvk_column_double(stmt, 1))
                results.append(VectorSearchResult(rowid: rowid, distance: distance))
            }
            return results
        }
    }

    func count() throws -> Int {
        let sql = "SELECT count(*) FROM vec_items"
        return try lock.withLock {
            var stmt: OpaquePointer?
            defer { csvk_finalize(stmt) }
            guard csvk_prepare(db, sql, &stmt) == CSVK_OK else {
                throw VectorSearchError.queryFailed(errorMessage())
            }
            guard csvk_step(stmt) == CSVK_ROW else {
                throw VectorSearchError.queryFailed(errorMessage())
            }
            return Int(csvk_column_int64(stmt, 0))
        }
    }

    func delete(rowid: Int64) throws {
        let sql = "DELETE FROM vec_items WHERE rowid = ?"
        try lock.withLock {
            var stmt: OpaquePointer?
            defer { csvk_finalize(stmt) }
            guard csvk_prepare(db, sql, &stmt) == CSVK_OK else {
                throw VectorSearchError.queryFailed(errorMessage())
            }
            csvk_bind_int64(stmt, 1, rowid)
            guard csvk_step(stmt) == CSVK_DONE else {
                throw VectorSearchError.queryFailed(errorMessage())
            }
        }
    }

    func deleteAll() throws {
        try execute("DELETE FROM vec_items")
    }

    private func execute(_ sql: String) throws {
        try lock.withLock {
            let rc = csvk_exec(db, sql)
            if rc != CSVK_OK {
                throw VectorSearchError.queryFailed(errorMessage())
            }
        }
    }

    private func errorMessage() -> String {
        db.flatMap { String(cString: csvk_errmsg($0)) } ?? "Unknown error"
    }
}

enum VectorSearchError: Error, LocalizedError {
    case openFailed(String)
    case queryFailed(String)
    case invalidDimension(expected: Int, got: Int)

    var errorDescription: String? {
        switch self {
        case .openFailed(let msg): "Failed to open database: \(msg)"
        case .queryFailed(let msg): "Query failed: \(msg)"
        case .invalidDimension(let expected, let got): "Invalid embedding dimension: expected \(expected), got \(got)"
        }
    }
}
