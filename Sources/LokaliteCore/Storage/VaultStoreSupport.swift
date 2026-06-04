import Foundation

let sharedDateFormatter = ISO8601DateFormatter()

func iso8601() -> String {
    sharedDateFormatter.string(from: Date())
}
