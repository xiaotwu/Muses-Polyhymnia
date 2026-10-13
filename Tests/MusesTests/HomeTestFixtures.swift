import Darwin
import Foundation

/// Physical paths let retirement tests distinguish app-created links from
/// macOS's /var alias without granting cleanup permission through either link.
func isolatedHomeTestDirectory(_ prefix: String) -> URL {
    let temporary = FileManager.default.temporaryDirectory
    let physicalPath: String
    if let resolved = realpath(temporary.path, nil) {
        physicalPath = String(cString: resolved)
        free(resolved)
    } else {
        physicalPath = temporary.path
    }
    return URL(fileURLWithPath: physicalPath, isDirectory: true)
        .appendingPathComponent(prefix + UUID().uuidString, isDirectory: true)
}
