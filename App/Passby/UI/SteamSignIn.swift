import PassbyCore
import SwiftUI
import WebKit

/// Steam's own sign-in page, in a sheet.
///
/// Steam's sign-in was made for websites: it ends by sending the browser to an address of the
/// site's. The app has no such address, so it shows the page itself and watches for that last
/// move, which is all it ever looks at: what is typed on Steam's page stays between the person
/// and Steam. The bar across the top always says which site is showing, so it can be seen to be
/// Steam's.
struct SteamSignIn: View {
    /// Called once, with who Steam says signed in, or nil if they backed out.
    let onDone: (SteamLogin.Claim?) -> Void

    @State private var loading = true
    @State private var host = SteamLogin.page.host ?? ""

    var body: some View {
        NavigationStack {
            SteamPage(loading: $loading, host: $host) { url in onDone(SteamLogin.claim(from: url)) }
                .ignoresSafeArea(edges: .bottom)
                .overlay {
                    if loading { ProgressView().controlSize(.large) }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { onDone(nil) }
                    }
                    ToolbarItem(placement: .principal) {
                        Label(host, systemImage: "lock.fill")
                            .labelStyle(.titleAndIcon)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Showing \(host)")
                    }
                }
        }
        .interactiveDismissDisabled()
    }
}

private struct SteamPage: UIViewRepresentable {
    @Binding var loading: Bool
    @Binding var host: String
    let onReturn: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        // The ordinary store, so Steam can remember this phone the way it would in a browser.
        let view = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        view.navigationDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = true
        view.load(URLRequest(url: SteamLogin.page))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: SteamPage
        private var handedBack = false

        init(_ parent: SteamPage) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url, SteamLogin.isReturn(url) else {
                decisionHandler(.allow)
                return
            }
            // Steam is handing the person back. There is nothing at that address to open.
            decisionHandler(.cancel)
            guard !handedBack else { return }
            handedBack = true
            parent.onReturn(url)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            parent.host = webView.url?.host ?? parent.host
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.loading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.loading = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.loading = false
        }
    }
}
