import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;

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

  final Set<String> sessionAllowedHosts = {};

  String _getDomainRoot(String host) {
    final parts = host.toLowerCase().split('.');
    if (parts.length >= 2) {
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

    for (final site in widget.allowedSites) {
      try {
        final allowedHost = Uri.parse(site).host.toLowerCase();
        final allowedRoot = _getDomainRoot(allowedHost);
        if (targetRoot == allowedRoot) return true;
      } catch (_) {}
    }

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

  Future<void> _translateText(String text) async {
    // Show a loading indicator
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => const SizedBox(
        height: 150,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    try {
      final response = await http.get(Uri.parse(
          "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=fr&dt=t&q=${Uri.encodeComponent(text)}"));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        
        // Extract and join all translation segments
        String fullTranslation = "";
        if (data.isNotEmpty && data[0] is List) {
          for (var segment in data[0]) {
            if (segment is List && segment.isNotEmpty) {
              fullTranslation += segment[0].toString();
            }
          }
        }

        if (mounted) {
          Navigator.pop(context); // Close loading
          if (fullTranslation.isNotEmpty) {
            _showTranslationResult(fullTranslation);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Erreur de traduction")));
      }
    }
  }

  void _showTranslationResult(String translation) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.2,
        maxChildSize: 0.75,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const Text("TRADUCTION",
                  style: TextStyle(
                      color: Colors.blueAccent,
                      letterSpacing: 1.5,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              SelectableText(
                translation,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    height: 1.6,
                    fontWeight: FontWeight.w400),
                textAlign: TextAlign.left,
              ),
            ],
          ),
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
                  contextMenu: ContextMenu(
                    menuItems: [
                      ContextMenuItem(
                        id: 1,
                        androidId: 1,
                        iosId: "1",
                        title: "Traduire en Français",
                        action: () async {
                          final selectedText =
                              await webViewController?.getSelectedText();
                          if (selectedText != null && selectedText.isNotEmpty) {
                            _translateText(selectedText);
                          }
                        },
                      ),
                    ],
                    settings: ContextMenuSettings(
                        hideDefaultSystemContextMenuItems: false),
                  ),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    domStorageEnabled: true,
                    databaseEnabled: true,
                    useShouldOverrideUrlLoading: true,
                    supportMultipleWindows: true,
                    javaScriptCanOpenWindowsAutomatically: true,
                    allowsInlineMediaPlayback: true,
                  ),
                  onWebViewCreated: (c) {
                    webViewController = c;
                    // Inject CSS to fix selection transparency inside the WebView
                    c.addUserScript(userScript: UserScript(
                      source: "var style = document.createElement('style'); style.innerHTML = '*::selection { background: rgba(68, 138, 255, 0.3) !important; }'; document.head.appendChild(style);",
                      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                    ));
                  },
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
