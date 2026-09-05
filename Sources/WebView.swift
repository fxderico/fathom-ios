import SwiftUI
import WebKit

/// One WKWebView per tab. Reports back the visible (real) URL + title + nav state.
struct WebView: UIViewRepresentable {
    @ObservedObject var tab: Tab

    func makeCoordinator() -> Coordinator { Coordinator(tab: tab) }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.limitsNavigationsToAppBoundDomains = true          // required for service workers in WKWebView
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true
        cfg.websiteDataStore = .default()

        // Native ad / tracker blocking — compiled once, applied to every page.
        if let rules = context.coordinator.contentRules {
            cfg.userContentController.add(rules)
        }

        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.navigationDelegate = context.coordinator
        wv.allowsBackForwardNavigationGestures = true
        wv.customUserAgent = Tab.mobileUA
        context.coordinator.webView = wv
        tab.webView = wv
        wv.load(URLRequest(url: tab.currentProxied))
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {
        if context.coordinator.lastLoaded != tab.currentProxied {
            context.coordinator.lastLoaded = tab.currentProxied
            wv.load(URLRequest(url: tab.currentProxied))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let tab: Tab
        weak var webView: WKWebView?
        var lastLoaded: URL?
        var contentRules: WKContentRuleList?

        init(tab: Tab) {
            self.tab = tab
            super.init()
            lastLoaded = tab.currentProxied
            WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "fathom-block", encodedContentRuleList: Coordinator.blockJSON
            ) { list, _ in self.contentRules = list }
        }

        func webView(_ w: WKWebView, didStartProvisionalNavigation n: WKNavigation!) {
            DispatchQueue.main.async { self.tab.isLoading = true }
        }

        func webView(_ w: WKWebView, didFinish n: WKNavigation!) {
            DispatchQueue.main.async {
                self.tab.isLoading = false
                self.tab.canGoBack = w.canGoBack
                self.tab.canGoForward = w.canGoForward
                self.tab.title = w.title?.isEmpty == false ? w.title! : self.tab.title
                if let u = w.url, let real = UV.realURL(from: u) { self.tab.displayURL = real }
            }
        }

        // Fail over to the next proxy origin on network failure.
        func webView(_ w: WKWebView, didFail n: WKNavigation!, withError e: Error) { failover() }
        func webView(_ w: WKWebView, didFailProvisionalNavigation n: WKNavigation!, withError e: Error) { failover() }

        private func failover() {
            guard tab.originIndex < UV.origins.count - 1 else {
                DispatchQueue.main.async { self.tab.isLoading = false }
                return
            }
            tab.originIndex += 1
            DispatchQueue.main.async {
                self.tab.reloadProxied()
                self.webView?.load(URLRequest(url: self.tab.currentProxied))
            }
        }

        /// Minimal ad/tracker block list. Extend freely.
        static let blockJSON = """
        [
          {"trigger":{"url-filter":".*","if-domain":["*doubleclick.net","*googlesyndication.com","*google-analytics.com","*googletagmanager.com","*adservice.google.com","*amazon-adsystem.com","*adnxs.com","*criteo.com","*taboola.com","*outbrain.com","*scorecardresearch.com","*moatads.com","*rubiconproject.com","*pubmatic.com","*adsterra.com","*exoclick.com","*juicyads.com","*popads.net","*propellerads.com","*hilltopads.net","*trafficjunky.com","*ethicalads.io","*hotjar.com","*mixpanel.com","*segment.io","*bat.bing.com"]},"action":{"type":"block"}},
          {"trigger":{"url-filter":"(/pagead/|/gampad/|/adsbygoogle|/gtag/js|/analytics\\\\.js|/fbevents\\\\.js|/prebid|/adserver|/adframe)"},"action":{"type":"block"}}
        ]
        """
    }
}
