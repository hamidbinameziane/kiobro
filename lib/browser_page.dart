import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

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
  late Uint8List blackGifBytes;

  final Set<String> sessionAllowedHosts = {};

  @override
  void initState() {
    super.initState();
    blackGifBytes = base64Decode(
      "R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7",
    );
  }

  @override
  void dispose() {
    webViewController?.clearCache();
    super.dispose();
  }

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

  Future<void> _translateText(
    String text,
    String targetLang,
    String label,
  ) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const SizedBox(
        height: 150,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    try {
      final response = await http.get(
        Uri.parse(
          "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=$targetLang&dt=t&q=${Uri.encodeComponent(text)}",
        ),
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);

        String fullTranslation = "";
        if (data.isNotEmpty && data[0] is List) {
          for (var segment in data[0]) {
            if (segment is List && segment.isNotEmpty) {
              fullTranslation += segment[0].toString();
            }
          }
        }

        if (mounted) {
          Navigator.pop(context);
          if (fullTranslation.isNotEmpty) {
            _showTranslationResult(fullTranslation, label);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Erreur de traduction")));
      }
    }
  }

  void _showTranslationResult(String translation, String label) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: Colors.blueAccent,
                  letterSpacing: 1.5,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              SelectableText(
                translation,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  height: 1.6,
                  fontWeight: FontWeight.w400,
                ),
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
                        id: 2,
                        androidId: 2,
                        iosId: "2",
                        title: "Traduire en Arabe",
                        action: () async {
                          final selectedText = await webViewController
                              ?.getSelectedText();
                          if (selectedText != null && selectedText.isNotEmpty) {
                            _translateText(
                              selectedText,
                              'ar',
                              'Traduction Arabe',
                            );
                          }
                        },
                      ),
                      ContextMenuItem(
                        id: 1,
                        androidId: 1,
                        iosId: "1",
                        title: "Traduire en Français",
                        action: () async {
                          final selectedText = await webViewController
                              ?.getSelectedText();
                          if (selectedText != null && selectedText.isNotEmpty) {
                            _translateText(
                              selectedText,
                              'fr',
                              'Traduction Français',
                            );
                          }
                        },
                      ),
                      ContextMenuItem(
                        id: 3,
                        androidId: 3,
                        iosId: "3",
                        title: "Copier",
                        action: () async {
                          final selectedText = await webViewController
                              ?.getSelectedText();
                          if (selectedText != null && selectedText.isNotEmpty) {
                            await Clipboard.setData(
                              ClipboardData(text: selectedText),
                            );
                          }
                        },
                      ),
                      ContextMenuItem(
                        id: 4,
                        androidId: 4,
                        iosId: "4",
                        title: "Recherche Web",
                        action: () async {
                          final selectedText = await webViewController
                              ?.getSelectedText();
                          if (selectedText != null && selectedText.isNotEmpty) {
                            final searchUrl = Uri.parse(
                              "https://www.google.com/search?q=${Uri.encodeComponent(selectedText)}",
                            );
                            if (await canLaunchUrl(searchUrl)) {
                              await launchUrl(
                                searchUrl,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          }
                        },
                      ),
                    ],
                    settings: ContextMenuSettings(
                      hideDefaultSystemContextMenuItems: true,
                    ),
                  ),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    domStorageEnabled: true,
                    databaseEnabled: true,
                    useShouldOverrideUrlLoading: true,
                    useShouldInterceptRequest: true,
                    supportMultipleWindows: true,
                    javaScriptCanOpenWindowsAutomatically: true,
                    allowsInlineMediaPlayback: true,
                    cacheEnabled: true,
                    hardwareAcceleration: true,
                  ),
                  onWebViewCreated: (c) {
                    webViewController = c;

                    c.addUserScript(
                      userScript: UserScript(
                        source:
                            "var style = document.createElement('style'); style.innerHTML = '*::selection { background: rgba(68, 138, 255, 0.3) !important; }'; document.head.appendChild(style);",
                        injectionTime:
                            UserScriptInjectionTime.AT_DOCUMENT_START,
                      ),
                    );

                    c.addUserScript(
                      userScript: UserScript(
                        source: """
                          (function() {
                            const blackGif = 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';
                            function blockImg(img) {
                              if (!img.src || img.src === blackGif || img.src.startsWith('data:')) return;
                              img.style.backgroundColor = 'black';
                              img.draggable = false; // Disable system drag-and-drop
                            }
                            document.querySelectorAll('img').forEach(blockImg);
                            new MutationObserver(ms => {
                              for (let m of ms) {
                                m.addedNodes.forEach(n => {
                                  if (n.nodeType === 1) {
                                    if (n.tagName === 'IMG') blockImg(n);
                                    else n.querySelectorAll('img').forEach(blockImg);
                                  }
                                });
                              }
                            }).observe(document.documentElement, { childList: true, subtree: true });

                            // Aggressively prevent website and system from stealing the long press
                            window.addEventListener('contextmenu', function(e) {
                              if (e.target.tagName === 'IMG' || e.target.closest('img')) {
                                e.stopImmediatePropagation();
                                e.preventDefault();
                              }
                            }, true);
                            
                            window.addEventListener('dragstart', function(e) {
                              if (e.target.tagName === 'IMG' || e.target.closest('img')) {
                                e.preventDefault();
                              }
                            }, true);
                          })();
                        """,
                        injectionTime:
                            UserScriptInjectionTime.AT_DOCUMENT_START,
                      ),
                    );
                  },
                  onProgressChanged: (_, p) =>
                      setState(() => progress = p / 100),
                  onLongPressHitTestResult: (controller, hitTestResult) async {
                    // This native event is our primary hook
                    if (hitTestResult.type ==
                            InAppWebViewHitTestResultType.IMAGE_TYPE ||
                        hitTestResult.type ==
                            InAppWebViewHitTestResultType
                                .SRC_IMAGE_ANCHOR_TYPE) {
                      String? url = hitTestResult.extra;
                      if (url != null && !url.startsWith('data:')) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FullScreenImagePage(url: url),
                          ),
                        );
                      }
                    }
                  },
                  shouldInterceptRequest: (controller, request) async {
                    if (request.isForMainFrame ?? false) return null;
                    final uri = request.url;
                    final url = uri.toString();
                    if (url.contains('kiobro_force=1')) return null;
                    final lowerUrl = url.toLowerCase();
                    final urlWithoutQuery = lowerUrl.split('?').first;
                    final isImg =
                        RegExp(
                          r'\.(jpg|jpeg|png|gif|webp|svg|bmp|ico|avif|heic)',
                        ).hasMatch(urlWithoutQuery) ||
                        (request.headers?['Accept']?.toLowerCase().contains(
                              'image',
                            ) ??
                            false);
                    if (isImg) {
                      return WebResourceResponse(
                        contentType: "image/gif",
                        data: blackGifBytes,
                        statusCode: 200,
                        reasonPhrase: "OK",
                        headers: {
                          'Cache-Control':
                              'no-cache, no-store, must-revalidate',
                        },
                      );
                    }
                    return null;
                  },
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

class FullScreenImagePage extends StatelessWidget {
  final String url;
  const FullScreenImagePage({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            url,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: Colors.blueAccent),
              );
            },
            errorBuilder: (context, error, stackTrace) => const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image, color: Colors.white24, size: 64),
                SizedBox(height: 16),
                Text(
                  "Impossible de charger l'image",
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
