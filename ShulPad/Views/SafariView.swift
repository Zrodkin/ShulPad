// WebView.swift
import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.isInspectable = true
        webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        
        print("🌐 WebView loading URL: \(url.absoluteString)")
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
            super.init()
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("🌐 WebView started loading")
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ WebView finished loading")
            
            // Check what actually loaded
            webView.evaluateJavaScript("document.title") { result, error in
                if let title = result as? String {
                    print("📄 Page title: \(title)")
                } else {
                    print("❌ Failed to get page title: \(error?.localizedDescription ?? "unknown")")
                }
            }
            
            webView.evaluateJavaScript("document.body ? document.body.innerHTML.length : 0") { result, error in
                if let length = result as? Int {
                    print("📄 Page HTML length: \(length) characters")
                    if length == 0 {
                        print("❌ Page is empty!")
                    }
                } else {
                    print("❌ Failed to get page content: \(error?.localizedDescription ?? "unknown")")
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("❌ WebView failed to load: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ WebView navigation failed: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url {
                print("🔗 WebView wants to navigate to: \(url.absoluteString)")
                
                // Handle your custom URL schemes
                if url.scheme == "shulpad" {
                    print("🔄 Handling shulpad:// redirect")
                    
                    // ✅ IMPORTANT: Open the URL in the system so AppDelegate can handle it
                    DispatchQueue.main.async {
                        UIApplication.shared.open(url) { success in
                            if success {
                                print("✅ Successfully opened deep link: \(url.absoluteString)")
                                self.parent.dismiss()
                            } else {
                                print("❌ Failed to open deep link: \(url.absoluteString)")
                            }
                        }
                    }
                    
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
    }
}
