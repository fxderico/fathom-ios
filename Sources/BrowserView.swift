import SwiftUI

struct BrowserView: View {
    @StateObject private var store = TabStore()
    @State private var editing = false
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            tabStrip
            addressBar
            ZStack {
                ForEach(store.tabs) { tab in
                    WebView(tab: tab)
                        .opacity(tab.id == store.active?.id ? 1 : 0)
                        .allowsHitTesting(tab.id == store.active?.id)
                }
                if store.active == nil { Color.black }
            }
            toolbar
        }
        .background(Color.black.ignoresSafeArea())
        .tint(Color(red: 0.23, green: 0.51, blue: 0.96))
    }

    // MARK: tab strip
    private var tabStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(store.tabs) { tab in
                    HStack(spacing: 6) {
                        Text(tab.title).lineLimit(1).font(.caption)
                        Button { store.close(tab) } label: { Image(systemName: "xmark").font(.system(size: 9)) }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(tab.id == store.active?.id ? Color.white.opacity(0.14) : Color.white.opacity(0.05))
                    .clipShape(Capsule())
                    .onTapGesture { store.active = tab }
                }
                Button { store.newTab() } label: { Image(systemName: "plus").padding(8) }
            }
            .padding(.horizontal, 10).padding(.top, 6)
        }
        .frame(height: 42)
    }

    // MARK: address bar
    private var addressBar: some View {
        HStack(spacing: 8) {
            Button { store.active?.goBack() } label: { Image(systemName: "chevron.left") }
                .disabled(!(store.active?.canGoBack ?? false))
            Button { store.active?.goForward() } label: { Image(systemName: "chevron.right") }
                .disabled(!(store.active?.canGoForward ?? false))
            Button { store.active?.reload() } label: { Image(systemName: "arrow.clockwise") }

            TextField("Search or enter a URL", text: $draft, onEditingChanged: { editing = $0 })
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.webSearch)
                .submitLabel(.go)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
                .onSubmit { store.active?.navigate(draft); editing = false; hideKeyboard() }
                .onChange(of: store.active?.displayURL) { new in if !editing { draft = new ?? "" } }
                .onAppear { draft = store.active?.displayURL ?? "" }

            if store.active?.isLoading == true { ProgressView().scaleEffect(0.8) }
        }
        .font(.system(size: 17))
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    private var toolbar: some View {
        HStack {
            Text("Fathom").font(.caption2).foregroundStyle(.secondary)
            Spacer()
            Text("\(store.tabs.count) tab\(store.tabs.count == 1 ? "" : "s")").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 6)
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

final class TabStore: ObservableObject {
    @Published var tabs: [Tab]
    @Published var active: Tab?

    init() {
        let first = Tab()
        tabs = [first]
        active = first
    }
    func newTab() {
        let t = Tab()
        tabs.append(t)
        active = t
    }
    func close(_ tab: Tab) {
        tabs.removeAll { $0.id == tab.id }
        if tabs.isEmpty { newTab() }
        else if active?.id == tab.id { active = tabs.last }
    }
}
