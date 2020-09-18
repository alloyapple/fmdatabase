import CSqlite3

public protocol SqliteValue {
    func bind()
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

    public func bindObject(obj: SqliteValue?, idx: Int, pStmt: UnsafePointer<sqlite3_stmt>) {
        guard let obj = obj else {
            sqlite3_bind_null(pStmt, idx);
            return 
        }

        obj.bind()

    }
}


public class FMStatement{

}

