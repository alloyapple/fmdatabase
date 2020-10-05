import CSqlite3
import Foundation

public class FMResultSet {
    weak var parentDB: FMDatabase?
    let statement: FMStatement
    public var query: String = ""
    let columnNamesSetup: Bool = false
    var columnCount: Int32 {
        return sqlite3_column_count(self.statement.statement)
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

    public init(db: FMDatabase, statement: FMStatement) {
        self.parentDB = db
        self.statement = statement
    }

    public func valueForColumnIndex(_ columnIdx: Int32) -> SqliteValue? {
        let columnType = sqlite3_column_type(statement.statement, columnIdx)
        if columnType == SQLITE_INTEGER {
            return sqlite3_column_int64(statement.statement, columnIdx)
        }
        else if columnType == SQLITE_FLOAT {
            return sqlite3_column_double(statement.statement, columnIdx)
        }
        else if columnType == SQLITE_BLOB {
            return dataForColumnIndex(columnIdx)
        }
        else {
            return nil
        }

    }

    public func dataForColumnIndex(_ columnIdx: Int32) -> Data? {
        if sqlite3_column_type(statement.statement, columnIdx) == SQLITE_NULL || (columnIdx < 0) {
            return nil
        }

        let dataSize = sqlite3_column_bytes(statement.statement, columnIdx)
        let data = Data(capacity: Int(dataSize))
        data.copyBytes(
            to: unsafeBitCast(
                sqlite3_column_blob(statement.statement, columnIdx),
                to: UnsafeMutableRawBufferPointer.self
            ),
            count: Int(dataSize)
        )
        return data
    }

    public var next: Bool {
        var retry = false
        var numberOfRetries = 0
        var rc = SQLITE_ROW
        repeat {
            retry = false
            rc = sqlite3_step(statement.statement)
            if rc == SQLITE_BUSY || rc == SQLITE_LOCKED {
                retry = true

                if rc == SQLITE_LOCKED {
                    rc = sqlite3_reset(statement.statement)
                    if rc != SQLITE_LOCKED {
                        print("Unexpected result from sqlite3_reset \(rc) rs")
                    }
                }

                usleep(20)
                numberOfRetries = numberOfRetries + 1

                if self.parentDB!.busyRetryTimeout > 0
                    && numberOfRetries > self.parentDB!.busyRetryTimeout
                {
                    print("\(#function):\(#line)Database busy \(parentDB?.path ?? "")")
                    print("Database busy")
                    break
                }

            }
            else if SQLITE_DONE == rc || SQLITE_ROW == rc {

            }
            else if SQLITE_ERROR == rc {
                print("Error calling sqlite3_step (\(rc): \(parentDB?.lastErrorMessage ?? "")) rs")
                break
            }
            else if SQLITE_MISUSE == rc {
                print("Error calling sqlite3_step (\(rc): \(parentDB?.lastErrorMessage ?? "")) rs")
            }
            else {
                print(
                    "Unknown Error calling sqlite3_step (\(rc): \(parentDB?.lastErrorMessage ?? "")) rs"
                )
            }
        } while retry

        return rc == SQLITE_ROW
    }

    func columnIndexForName(_ columnName: String) -> Int32 {

        let _columnName = columnName.lowercased()
        guard let n = self.columnNames[_columnName] else {
            return -1
        }
        return n

    }

    func intForColumn(_ columnName: String) -> Int32 {
        return self.intForColumnIndex(self.columnIndexForName(columnName))
    }

    func intForColumnIndex(_ columnIdx: Int32) -> Int32 {
        return sqlite3_column_int(statement.statement, columnIdx)
    }

    func int64ForColumn(_ columnName: String) -> Int64 {
        return self.int64ForColumnIndex(self.columnIndexForName(columnName))
    }

    func int64ForColumnIndex(_ columnIdx: Int32) -> Int64 {
        return sqlite3_column_int64(statement.statement, columnIdx)
    }

    func doubleForColumn(_ columnName: String) -> Double {
        return self.doubleForColumnIndex(self.columnIndexForName(columnName))
    }

    func doubleForColumnIndex(_ columnIdx: Int32) -> Double {
        return sqlite3_column_double(statement.statement, columnIdx)
    }

    deinit {
        statement.reset()
    
    }

    public static func resultSetWith(statement: FMStatement, aDB: FMDatabase) -> FMResultSet {
        return FMResultSet(db: aDB, statement: statement)
    }
}
