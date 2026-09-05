import Foundation

/// Server-side proxy stays unchanged — this just builds the /uv/service/<encoded> URLs
/// the VPS already understands. Port of Ultraviolet.codec.xor.encode / .decode.
enum UV {
    /// Ordered list of proxy origins. The app fails over to the next one if a
    /// load fails (a website can't do this — an app can).
    static let origins: [String] = [
        "https://luxarcanum.art",
        // add backups here, e.g. "https://<mirror-domain>", "http://<vps-ip>:58220"
    ]

    static func encode(_ url: String) -> String {
        var scalars = String.UnicodeScalarView()
        for (i, ch) in url.unicodeScalars.enumerated() {
            if i % 2 == 1, let x = Unicode.Scalar(ch.value ^ 2) {
                scalars.append(x)
            } else {
                scalars.append(ch)
            }
        }
        let xored = String(scalars)
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.!~*'()")
        return xored.addingPercentEncoding(withAllowedCharacters: allowed) ?? xored
    }

    static func decode(_ encoded: String) -> String {
        let unescaped = encoded.removingPercentEncoding ?? encoded
        var scalars = String.UnicodeScalarView()
        for (i, ch) in unescaped.unicodeScalars.enumerated() {
            if i % 2 == 1, let x = Unicode.Scalar(ch.value ^ 2) {
                scalars.append(x)
            } else {
                scalars.append(ch)
            }
        }
        return String(scalars)
    }

    /// Turn whatever the user typed into a real URL.
    static func normalize(_ input: String) -> String {
        let t = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("http://") || t.hasPrefix("https://") { return t }
        // looks like a domain?
        if t.contains(".") && !t.contains(" ") { return "https://\(t)" }
        let q = t.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? t
        return "https://duckduckgo.com/?q=\(q)"
    }

    static func proxied(_ realUrl: String, originIndex: Int = 0) -> URL {
        let base = origins[min(originIndex, origins.count - 1)]
        return URL(string: "\(base)/uv/service/\(encode(realUrl))")!
    }

    /// Given a proxied URL, get the real destination back (for the address bar).
    static func realURL(from proxied: URL) -> String? {
        let s = proxied.absoluteString
        guard let range = s.range(of: "/uv/service/") else { return nil }
        return decode(String(s[range.upperBound...]))
    }
}
