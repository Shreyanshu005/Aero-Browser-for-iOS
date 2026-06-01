import Foundation

let str = "https://x.com"
if let url = URL(string: str) {
    print("Host: \(url.host ?? "nil")")
} else {
    print("Invalid URL")
}
