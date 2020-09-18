import CSqlite3
import Foundation

extension FMDatabase {

    
}

extension Data {
    var bytes : [UInt8]{
        return [UInt8](self)
    }
}

extension Data: SqliteValue {
    public func bind(idx: Int32, pStmt: OpaquePointer) {
        let bytes = self.bytes
        sqlite3_bind_blob(pStmt, idx, bytes, Int32(bytes.count), SQLITE_STATIC)
    }
}

extension String : SqliteValue {
    public func bind(idx: Int32, pStmt: OpaquePointer) {
        sqlite3_bind_text(pStmt, idx, self, -1, SQLITE_STATIC)
    }
}

extension Int32: SqliteValue {
    public func bind(idx: Int32, pStmt: OpaquePointer) {
        sqlite3_bind_int(pStmt, idx, self)
    }
}

extension Int64: SqliteValue {
    public func bind(idx: Int32, pStmt: OpaquePointer) {
        sqlite3_bind_int64(pStmt, idx, self)
    }
}

extension UInt32: SqliteValue {
    public func bind(idx: Int32, pStmt: OpaquePointer) {
        sqlite3_bind_int64(pStmt, idx, sqlite3_int64(self))
    }
}

extension UInt64: SqliteValue {
    public func bind(idx: Int32, pStmt: OpaquePointer) {
        sqlite3_bind_int64(pStmt, idx, sqlite3_int64(self))
    }
}

extension Float: SqliteValue {
    public func bind(idx: Int32, pStmt: OpaquePointer) {
        sqlite3_bind_double(pStmt, idx, Double(self))
    }
}

extension Double: SqliteValue {
    public func bind(idx: Int32, pStmt: OpaquePointer) {
        sqlite3_bind_double(pStmt, idx, Double(self))
    }
}