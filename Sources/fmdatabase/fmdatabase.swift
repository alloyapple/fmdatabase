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

    public init(path: String) {

    }

    public static func databaseWith(path: String) -> FMDatabase {
        return FMDatabase(path: path)
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

}

