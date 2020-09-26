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

    public  init(db: FMDatabase, statement: FMStatement) {
        self.parentDB = db
        self.statement = statement
    }

    public static func resultSetWith(statement: FMStatement, aDB: FMDatabase) -> FMResultSet {
        return FMResultSet(db: aDB, statement: statement)
    }
}