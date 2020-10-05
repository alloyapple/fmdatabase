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

    var shouldCacheStatements: Bool = false
    var inTransaction: Bool = false
    var databaseExists: Bool {
        if self._db == nil {
            print("The FMDatabase \(self.path) is not open.")
            return false
        }

        return true
    }

    var lastErrorCode: Int32 {
        return sqlite3_errcode(self._db)
    }

    var lastErrorMessage: String {
        return String(cString: sqlite3_errmsg(self._db))
    }

    var goodConnection: Bool {
        if _db == nil {
            return false
        }

        guard let _ = self.executeQuery(sql: "select name from sqlite_master where type='table'")
        else {
            return false
        }

        return true
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

    public func warnInUse() {
        print("The FMDatabase \(self.path) is currently in use.")
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

    public func executeQuery(
        sql: String,
        arrayArgs: [SqliteValue?] = [],
        dictionaryArgs: [String: SqliteValue?] = [:]
    ) -> FMResultSet? {
        var pStmt: OpaquePointer? = nil
        var rc: Int32 = 0
        var retry = false
        var numberOfRetries = 0
        var statement: FMStatement? = nil

        if self.databaseExists == false {
            return nil
        }

        if self.isExecutingStatement {
            self.warnInUse()
            return nil
        }

        self.isExecutingStatement = true

        if self.traceExecution {
            print("executeQuery: \(sql)")
        }

        if self.shouldCacheStatements {
            statement = self.cachedStatements[sql]
            pStmt = statement?.statement
            statement?.reset()
        }

        if pStmt == nil {
            repeat {
                retry = false
                rc = sqlite3_prepare_v2(_db, sql, -1, &pStmt, nil)
                if SQLITE_BUSY == rc || SQLITE_LOCKED == rc {
                    retry = true
                    usleep(20)
                    numberOfRetries = numberOfRetries + 1
                    if self.busyRetryTimeout > 0 && numberOfRetries > self.busyRetryTimeout {
                        print("\(#function):\(#line) Database busy (\(self.path))")
                        sqlite3_finalize(pStmt)
                        self.isExecutingStatement = false
                        return nil
                    }
                } else if SQLITE_OK != rc {
                    if self.logsErrors {
                        print("DB Error: \(self.lastErrorCode) \(self.lastErrorMessage)")
                        print("DB Query: \(sql)")
                        print("DB Path: \(self.path)")
                    }
                    sqlite3_finalize(pStmt)
                    self.isExecutingStatement = false
                    return nil
                }
            } while retry
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
            print("Error: the bind count is not correct for the # of variables (executeQuery)")
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
        statement!.useCount = statement!.useCount + 1

        self.isExecutingStatement = false

        return rs
    }

    public func executeUpdate(
        sql: String,
        arrayArgs: [SqliteValue?] = [],
        dictionaryArgs: [String: SqliteValue?] = [:]
    ) -> Bool {
        if self.databaseExists == false {
            return false
        }

        if self.isExecutingStatement {
            self.warnInUse()
            return false
        }

        self.isExecutingStatement = true

        if self.traceExecution {
            print("executeQuery: \(sql)")
        }

        var statement: FMStatement? = nil
        var pStmt: OpaquePointer? = nil
        var numberOfRetries = 0
        var retry = false
        var rc: Int32 = 0

        if self.shouldCacheStatements {
            statement = self.cachedStatements[sql]
            pStmt = statement?.statement
            statement?.reset()
        }

        if pStmt == nil {
            repeat {
                retry = false
                rc = sqlite3_prepare_v2(_db, sql, -1, &pStmt, nil)
                if SQLITE_BUSY == rc || SQLITE_LOCKED == rc {
                    retry = true
                    usleep(20)
                    numberOfRetries += 1
                    if self.busyRetryTimeout > 0 && numberOfRetries > self.busyRetryTimeout {
                        print("\(#function):\(#line) Database busy (\(self.path))")
                        print("Database busy")
                        sqlite3_finalize(pStmt)
                        self.isExecutingStatement = false
                        return false
                    }
                } else if SQLITE_OK != rc {

                    if self.logsErrors {
                        print("DB Error: \(self.lastErrorCode) \(self.lastErrorMessage)")
                        print("DB Query: \(sql)")
                        print("DB Path: \(self.path)")
                    }
                    sqlite3_finalize(pStmt)
                    self.isExecutingStatement = false
                    return false

                }
            } while retry
        }

        var idx: Int32 = 0
        let queryCount = sqlite3_bind_parameter_count(pStmt)

        if dictionaryArgs.count > 0 {

            for (k, v) in dictionaryArgs {
                let namedIdx = sqlite3_bind_parameter_index(pStmt, k)
                if namedIdx > 0 {
                    self.bindObject(obj: v, idx: namedIdx, pStmt: pStmt!)
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
            print("Error: the bind count is not correct for the # of variables (executeQuery)")
            sqlite3_finalize(pStmt)
            self.isExecutingStatement = false
            return false
        }

        numberOfRetries = 0

        repeat {
            rc = sqlite3_step(pStmt)
            retry = false
            if SQLITE_BUSY == rc || SQLITE_LOCKED == rc {
                retry = true
                if SQLITE_LOCKED == rc {
                    rc = sqlite3_reset(pStmt)
                    if rc != SQLITE_LOCKED {
                        print("Unexpected result from sqlite3_reset (\(rc)) eu")
                    }
                }

                usleep(20)
                numberOfRetries = numberOfRetries + 1
                if self.busyRetryTimeout > 0 && numberOfRetries > self.busyRetryTimeout {
                    print("\(#function):\(#line) Database busy (\(self.path ))")
                    print("Database busy")
                    retry = false
                }

            } else if SQLITE_DONE == rc {

            } else if SQLITE_ERROR == rc {
                print("Error calling sqlite3_step (\(rc): \(self.lastErrorMessage)) SQLITE_ERROR")
                print("DB Query: \(sql)")
            } else if SQLITE_MISUSE == rc {
                print("Error calling sqlite3_step (\(rc): \(self.lastErrorMessage)) SQLITE_MISUSE")
                print("DB Query: \(sql)")
            } else {
                print("Error calling sqlite3_step (\(rc): \(self.lastErrorMessage)) eu")
                print("DB Query: \(sql)")
            }
        } while retry

        var cachedStmt: FMStatement? = nil
        var closeErrorCode: Int32 = 0

        if self.shouldCacheStatements && cachedStmt == nil {
            cachedStmt = FMStatement()
            cachedStmt?.statement = pStmt
            self.setCachedStatement(statement: cachedStmt!, query: sql)
        }

        if cachedStmt == nil {
            closeErrorCode = sqlite3_finalize(pStmt)
        } else {
            cachedStmt!.useCount += cachedStmt!.useCount + 1
            closeErrorCode = sqlite3_reset(pStmt)
        }

        if closeErrorCode != SQLITE_OK {
            print(
                "Unknown error finalizing or resetting statement (\(closeErrorCode): \(self.lastErrorMessage))"
            )
            print("DB Query: \(sql)")
        }

        self.isExecutingStatement = false

        return (rc == SQLITE_DONE || rc == SQLITE_OK)
    }

    public func executeUpdate(_ sql: String, _ list: SqliteValue...) -> Bool {
        return self.executeUpdate(sql: sql, arrayArgs: list)
    }

    public func rollback() -> Bool {
        let b = self.executeUpdate(sql: "rollback transaction")

        if b {
            self.inTransaction = false
        }

        return b
    }

    public func commit() -> Bool {
        let b = self.executeUpdate(sql: "commit transaction")

        if b {
            self.inTransaction = false
        }

        return b
    }

    public func beginDeferredTransaction() -> Bool {
        let b = self.executeUpdate(sql: "begin deferred transaction")

        if b {
            self.inTransaction = true
        }

        return b
    }

    public func beginTransaction() -> Bool {
        let b = self.executeUpdate(sql: "begin exclusive transaction")

        if b {
            self.inTransaction = true
        }

        return b
    }
}

public class FMStatement {
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
