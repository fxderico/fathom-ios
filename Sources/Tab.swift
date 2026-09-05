import Foundation
import WebKit
import Combine

final class Tab: ObservableObject, Identifiable {
    let id = UUID()
    @Published var displayURL: String          // real destination, shown in the bar
    @Published var title: String
    @Published var isLoading = false
    @Published var canGoBack = false
    @Published var canGoForward = false

    var originIndex = 0
    private(set) var currentProxied: URL
    weak var webView: WKWebView?

    static let mobileUA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    static let home = "https://duckduckgo.com/"

    init(url: String = Tab.home) {
        displayURL = url
        title = "New Tab"
        currentProxied = UV.proxied(url)
    }

    func navigate(_ input: String) {
        originIndex = 0
        let real = UV.normalize(input)
        displayURL = real
        currentProxied = UV.proxied(real, originIndex: originIndex)
        objectWillChange.send()
    }

    func reloadProxied() {
        currentProxied = UV.proxied(displayURL, originIndex: originIndex)
        objectWillChange.send()
    }

    func goBack()    { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func reload()    { webView?.reload() }
}
