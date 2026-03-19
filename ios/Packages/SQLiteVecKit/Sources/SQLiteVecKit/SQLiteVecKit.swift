import CSQLiteVecKit

public enum SQLiteVecKit {
    public static func initialize() {
        csvk_initialize()
    }
}

// Re-export C types for use in Swift
public typealias SQLiteVecDB = OpaquePointer
public typealias SQLiteVecStmt = OpaquePointer
