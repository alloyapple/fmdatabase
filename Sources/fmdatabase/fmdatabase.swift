import CSqlite3

public protocol SqliteValue {
    func bind(idx: Int32, pStmt: OpaquePointer)
}

public class FMDatabase {

    let traceExecution: Bool = false
    let checkedOut: Bool = false
    let busyRetryTimeout: Int = 0
    let crashOnErrors: Bool = false
    let logsErrors: Bool = false
    let cachedStatements: [Int: Int] = [:]
    let path: String
    var _db: OpaquePointer? = nil

    public init(path: String = ":memory:") {
        self.path = path
    }

    public func open() -> Bool {
        let err = sqlite3_open(self.path, &_db)
        return err == SQLITE_OK
    }

    public func open(flags: Int32) -> Bool {
         let err = sqlite3_open_v2(self.path, &_db, flags, nil /* Name of VFS module to use */)
         return err == SQLITE_OK
    }

    public static func databaseWith(path: String) -> FMDatabase {
        return FMDatabase(path: path)
    }

    public static func sqliteLibVersion() -> String {
        return String(cString: sqlite3_libversion())
    }

    public static func isSQLiteThreadSafe() -> Bool {
        return sqlite3_threadsafe() != 0
    }

    public func bindObject(obj: SqliteValue?, idx: Int32, pStmt: OpaquePointer) {
        guard let obj = obj else {
            sqlite3_bind_null(pStmt, idx)
            return 
        }

        obj.bind(idx: idx, pStmt: pStmt)

    }
}


public class FMStatement{
    public var statement: OpaquePointer?
    public var query: String = ""
    public var useCount: Int32 = 0

}

