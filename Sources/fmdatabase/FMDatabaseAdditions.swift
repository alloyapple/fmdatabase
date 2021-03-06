import CSqlite3
import Foundation

extension FMDatabase {

}

public protocol SqliteValue {
    func bind(idx: Int32, pStmt: OpaquePointer)
}

extension Data {
    var bytes: [UInt8] {
        return [UInt8](self)
    }
}

extension Date: SqliteValue {
    public func bind(idx: Int32, pStmt: OpaquePointer) {
        sqlite3_bind_double(pStmt, idx, self.timeIntervalSince1970)
    }
}

extension Data: SqliteValue {
    public func bind(idx: Int32, pStmt: OpaquePointer) {
        let bytes = self.bytes
        sqlite3_bind_blob(pStmt, idx, bytes, Int32(bytes.count), SQLITE_STATIC)
    }
}

extension String: SqliteValue {
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

extension FMDatabase {

    func tableExists(tableName: String) -> Bool {
        let _tableName = tableName.lowercased()
        guard
            let rs = self.executeQuery(
                "select [sql] from sqlite_master where [type] = 'table' and lower(name) = ?",
                _tableName
            )
        else {
            return false
        }
        return rs.next
    }

    var schema: FMResultSet? {
         //result colums: type[STRING], name[STRING],tbl_name[STRING],rootpage[INTEGER],sql[STRING]
        return self.executeQuery(
            sql:
                "SELECT type, name, tbl_name, rootpage, sql FROM (SELECT * FROM sqlite_master UNION ALL SELECT * FROM sqlite_temp_master) WHERE type != 'meta' AND name NOT LIKE 'sqlite_%' ORDER BY tbl_name, type DESC, name"
        )
    }

    func  tableSchema(tableName: String) -> FMResultSet? {
        return self.executeQuery(
            sql:
                "PRAGMA table_info('\(tableName)')")
    }

}
