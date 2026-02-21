import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class BrowserPage extends StatefulWidget {
  final List<String> allowedSites;
  final String initialUrl;
  final Function(String)? onPermanentAdd;

  const BrowserPage({
    super.key,
    required this.allowedSites,
    required this.initialUrl,
    this.onPermanentAdd,
  });

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  InAppWebViewController? webViewController;
  double progress = 0;

  // Set of hosts allowed just for this session
  final Set<String> sessionAllowedHosts = {};

  String _getDomainRoot(String host) {
    final parts = host.toLowerCase().split('.');
    if (parts.length >= 2) {
      // Basic root domain extraction (e.g., google.com from mail.google.com)
      // Note: Doesn't handle .co.uk perfectly but works for most common sites
      return parts.sublist(parts.length - 2).join('.');
    }
    return host;
  }

  bool isUrlAllowed(WebUri? uri) {
    if (uri == null) return false;

    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'data' ||
        scheme == 'blob' ||
        scheme == 'about' ||
        scheme == 'file') {
      return true;
    }

    final host = uri.host.toLowerCase();
    if (host.isEmpty) return true;

    final targetRoot = _getDomainRoot(host);

    // 1. Check permanent whitelist
    for (final site in widget.allowedSites) {
      try {
        final allowedHost = Uri.parse(site).host.toLowerCase();
        final allowedRoot = _getDomainRoot(allowedHost);
        if (targetRoot == allowedRoot) return true;
      } catch (_) {}
    }

    // 2. Check session whitelist
    if (sessionAllowedHosts.contains(targetRoot)) return true;

    return false;
  }

  void _handleBlocked(WebUri? uri) {
    if (!mounted || uri == null) return;

    final host = uri.host.toLowerCase();
    final root = _getDomainRoot(host);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Bloqué: $host"),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: "AUTORISER",
          textColor: Colors.white,
          onPressed: () {
            setState(() => sessionAllowedHosts.add(root));
            webViewController?.loadUrl(urlRequest: URLRequest(url: uri));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (webViewController != null && await webViewController!.canGoBack()) {
          webViewController!.goBack();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: progress < 1.0
              ? LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  color: Colors.blueAccent,
                )
              : const SizedBox.shrink(),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    domStorageEnabled: true,
                    databaseEnabled: true,
                    useShouldOverrideUrlLoading: true,
                    supportMultipleWindows: true,
                    javaScriptCanOpenWindowsAutomatically: true,
                    allowsInlineMediaPlayback: true,
                  ),
                  onWebViewCreated: (c) => webViewController = c,
                  onProgressChanged: (_, p) =>
                      setState(() => progress = p / 100),

                  shouldOverrideUrlLoading: (controller, action) async {
                    final uri = action.request.url;
                    if (isUrlAllowed(uri)) return NavigationActionPolicy.ALLOW;
                    _handleBlocked(uri);
                    return NavigationActionPolicy.CANCEL;
                  },

                  onLoadStart: (controller, uri) async {
                    if (!isUrlAllowed(uri)) {
                      controller.stopLoading();
                      _handleBlocked(uri);
                    }
                  },

                  onCreateWindow: (controller, action) async {
                    final uri = action.request.url;
                    if (isUrlAllowed(uri)) {
                      controller.loadUrl(urlRequest: URLRequest(url: uri));
                    } else {
                      _handleBlocked(uri);
                    }
                    return false;
                  },
                ),
              ),
              _buildControlBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlBar() {
    return Container(
      height: 50,
      color: const Color(0xFF1E1E1E),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: () async {
              if (await webViewController?.canGoBack() ?? false) {
                webViewController?.goBack();
              } else {
                Navigator.pop(context);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => webViewController?.reload(),
          ),
          IconButton(
            icon: const Icon(
              Icons.add_moderator,
              size: 20,
              color: Colors.blueAccent,
            ),
            onPressed: () async {
              final url = (await webViewController?.getUrl())?.toString();
              if (url != null && widget.onPermanentAdd != null) {
                widget.onPermanentAdd!(url);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Site ajouté en permanence")),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
