import Foundation
import CSqlite3

public class FMResultSet {
    let parentDB: FMDatabase
    let statement: FMStatement
    public var query: String = ""
    let columnNamesSetup: Bool = false
    var columnCount: Int32 {
        get {
            return sqlite3_column_count(self.statement.statement)
        }
    }

    var resultDict: [String: SqliteValue] {
        var result = [String: SqliteValue]()
        
        for (k, v) in self.columnNames {
            result[k] = self.valueForColumnIndex(v)
        }
        return result
    }

    lazy var columnNames: [String: Int32] = self.getColumnNames()

    func getColumnNames() -> [String: Int32] {
        var result = [String: Int32]()
        let columnCount = sqlite3_column_count(statement.statement)

        for i in 0..<columnCount {
            let key = String(cString: sqlite3_column_name(statement.statement, i))
            result[key.lowercased()] = i
        }

        return result
    }

    public  init(db: FMDatabase, statement: FMStatement) {
        self.parentDB = db
        self.statement = statement
    }

    public func valueForColumnIndex(_ columnIdx: Int32) -> SqliteValue? {
        let columnType = sqlite3_column_type(statement.statement, columnIdx)
        if (columnType == SQLITE_INTEGER) {
            return sqlite3_column_int64(statement.statement, columnIdx);
        } else if (columnType == SQLITE_FLOAT) {
            return sqlite3_column_double(statement.statement, columnIdx);
        } else if (columnType == SQLITE_BLOB) {
            return dataForColumnIndex(columnIdx)
        } else  {
            return nil
        }
        
    }

    public func dataForColumnIndex(_ columnIdx: Int32) -> Data? {
        if (sqlite3_column_type(statement.statement, columnIdx) == SQLITE_NULL || (columnIdx < 0)) {
            return nil
        }

        let dataSize = sqlite3_column_bytes(statement.statement, columnIdx)
        let data = Data(capacity: Int(dataSize))
        data.copyBytes(to: unsafeBitCast(sqlite3_column_blob(statement.statement, columnIdx), to: UnsafeMutableRawBufferPointer.self), count: Int(dataSize))
        return data
    }

    deinit {
        statement.reset()

    }

    public static func resultSetWith(statement: FMStatement, aDB: FMDatabase) -> FMResultSet {
        return FMResultSet(db: aDB, statement: statement)
    }
}