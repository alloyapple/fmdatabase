import XCTest

@testable import fmdatabase

final class fmdatabaseTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.

        let db = FMDatabase()
        XCTAssertTrue(db.open())
        let expected_sqls = [
            """
            CREATE TABLE t1(id integer primary key, s1 text, t1_i1 integer not null, i2 integer, unique (s1), constraint t1_idx1 unique (i2));
            """,
            "INSERT INTO \"t1\" VALUES(1,'foo',10,20);",
            "INSERT INTO \"t1\" VALUES(2,'foo2',30,30);",
            """
            CREATE TABLE t2(id integer, t2_i1 integer, 
            t2_i2 integer, primary key (id),
            foreign key(t2_i1) references t1(t1_i1));
            """,
            """
            CREATE TRIGGER trigger_1 update of t1_i1 on t1 
            begin 
            update t2 set t2_i1 = new.t1_i1 where t2_i1 = old.t1_i1;  
            end;
            """,
            """
            CREATE VIEW v1 as select * from t1 left join t2 
            using (id);
            """,
        ]

        for sql in expected_sqls {
            let test = db.executeUpdate(sql: sql)
            XCTAssertTrue(test)
        }
    }

    func testselect() {
        let db = FMDatabase()
        XCTAssertTrue(db.open())
        XCTAssertTrue(db.goodConnection)
        db.traceExecution = true
        if let r = db.executeQuery(sql: "select 4+5 as foo") {
            if r.next {
                let data = r.intForColumn("foo")
                XCTAssertEqual(data, 9)
            }

        } else {
            XCTAssertTrue(false)
        }

        XCTAssertFalse(db.tableExists(tableName: "Person"))
        XCTAssertTrue(db.executeUpdate(sql: "CREATE TABLE Person(id integer primary key)"))
        XCTAssertTrue(db.tableExists(tableName: "Person"))

    }

    func testPassword() {
        let db = FMDatabase(path: "Resource/_password.db")
        XCTAssertTrue(db.open())

        XCTAssertTrue(db.executeUpdate(sql: "delete from \"password\";"))
        for i in 1...1000 {
            XCTAssertTrue(db.executeUpdate(sql: "INSERT INTO \"password\" VALUES(\(i),'foo');"))
        }

    }

    func testPasswordCommit() {
        let db = FMDatabase(path: "Resource/_password.db")
        XCTAssertTrue(db.open())

        XCTAssertTrue(db.executeUpdate(sql: "delete from \"password\";"))
        XCTAssertTrue(db.beginTransaction())
        for i in 1...10000 {
            XCTAssertTrue(db.executeUpdate(sql: "INSERT INTO \"password\" VALUES(\(i),'foo');"))
        }

        XCTAssertTrue(db.commit())

    }

    static var allTests = [
        ("testExample", testExample),
        ("testPassword", testPassword),
        ("testPasswordCommit", testPasswordCommit),

        ("testselect", testselect),
    ]
}
