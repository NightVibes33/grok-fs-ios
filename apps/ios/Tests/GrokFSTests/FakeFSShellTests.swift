import XCTest
@testable import GrokFS

final class FakeFSShellTests: XCTestCase {
    func testEchoWriteAndCat() async throws {
        let workspace = WorkspaceStore()
        workspace.bootstrap()
        let shell = FakeFSShell(workspace: workspace)

        let write = shell.run("echo hello > /root/test.txt", cwd: "/root")
        XCTAssertEqual(write.exitCode, 0)

        let read = shell.run("cat /root/test.txt", cwd: "/root")
        XCTAssertEqual(read.exitCode, 0)
        XCTAssertEqual(read.output, "hello\n")
    }
}
