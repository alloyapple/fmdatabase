import CSqlite3
import Glibc


public class FMDatabase {

    var traceExecution: Bool = false
    var isExecutingStatement = false
    let checkedOut: Bool = false
    var busyRetryTimeout: Int = 0
    let crashOnErrors: Bool = false
    let logsErrors: Bool = false
    var cachedStatements: [String: FMStatement] = [:]
    let path: String
    var _db: OpaquePointer? = nil
    var openResultSets: [FMResultSet] = []
    var shouldCacheStatements: Bool = false

    var lastErrorCode: Int32 {
        get {
            return sqlite3_errcode(self._db)
        }
    }

    var lastErrorMessage: String {
        get {
            return String(cString: sqlite3_errmsg(self._db))
        }
    }

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

    public func setCachedStatement(statement: FMStatement, query: String) {
        statement.query = query
        self.cachedStatements[query] = statement
    }

    public func bindObject(obj: SqliteValue?, idx: Int32, pStmt: OpaquePointer) {
        guard let obj = obj else {
            sqlite3_bind_null(pStmt, idx)
            return 
        }

        obj.bind(idx: idx, pStmt: pStmt)

    }

    //- (FMResultSet *)executeQuery:(NSString *)sql withArgumentsInArray:(NSArray*)arrayArgs orDictionary:(NSDictionary *)dictionaryArgs orVAList:(va_list)args {

    public func executeQuery(sql: String, arrayArgs: [SqliteValue?] = [], dictionaryArgs: [String: SqliteValue?] = [:]) -> FMResultSet? {
        var pStmt: OpaquePointer? = nil
        var rc: Int32 = 0
        var retry = false
        var numberOfRetries = 0
        var statement :FMStatement? = nil

        if self.isExecutingStatement {
            return nil  
        }

        if self.traceExecution {
            print("executeQuery: \(sql)")
        }

        if self.shouldCacheStatements {
            statement = self.cachedStatements[sql]
            pStmt = statement?.statement
            statement?.reset()
        }

        if pStmt != nil {
            repeat {
                retry = false
                rc = sqlite3_prepare_v2(_db, sql, -1, &pStmt, nil)
                if (SQLITE_BUSY == rc || SQLITE_LOCKED == rc) {
                    retry = true
                    usleep(20)
                    numberOfRetries = numberOfRetries + 1
                    if self.busyRetryTimeout > 0 && numberOfRetries > self.busyRetryTimeout {
                        print("\(#function):\(#line) Database busy (\(self.path))")
                        sqlite3_finalize(pStmt)
                        self.isExecutingStatement = false
                        return nil
                    }
                } else if (SQLITE_OK != rc) {
                    if self.logsErrors {
                        print("DB Error: \(self.lastErrorCode) \(self.lastErrorMessage)")
                        print("DB Query: \(sql)")
                        print("DB Path: \(self.path)")
                    }
                    sqlite3_finalize(pStmt)
                    self.isExecutingStatement = false
                    return nil
                }
            } while retry;
        }

        let queryCount = sqlite3_bind_parameter_count(pStmt)
        var idx: Int32 = 0

        if dictionaryArgs.count > 0 {
            for (k, v) in dictionaryArgs {
                let namedIdx = sqlite3_bind_parameter_index(pStmt, k)
                if namedIdx > 0 {
                    bindObject(obj: v, idx: namedIdx, pStmt: pStmt!)
                    idx = idx + 1
                } else {
                    print("Could not find index for \(k)")
                }
            }
        } else {
            while idx < queryCount {
                let obj = arrayArgs[Int(idx)]
                idx = idx + 1
                bindObject(obj: obj, idx: idx, pStmt: pStmt!)
            }
        }

        if idx != queryCount {
            print("Error: the bind count is not correct for the # of variables (executeQuery)");
            sqlite3_finalize(pStmt)
            self.isExecutingStatement = false
            return nil
        }

        if statement == nil {
            statement = FMStatement()   
            statement?.statement = pStmt

            if self.shouldCacheStatements {
                self.setCachedStatement(statement: statement!, query: sql)
            }
        }

        let rs = FMResultSet.resultSetWith(statement: statement!, aDB: self)
        rs.query = sql
        self.openResultSets.append(rs)
        statement!.useCount = statement!.useCount + 1

        self.isExecutingStatement = false   

        return rs
    }
}


public class FMStatement{
    public var statement: OpaquePointer?
    public var query: String = ""
    public var useCount: Int32 = 0

    public func reset() {
        guard let statement = statement else {
            return
        }
        sqlite3_reset(statement)
    }

    deinit {
        guard let statement = statement else {
            return
        }
        sqlite3_finalize(statement)
    }

}

