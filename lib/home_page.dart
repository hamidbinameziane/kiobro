import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'browser_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<String> sites = [];
  Map<String, String> titles = {};

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  Future<void> _loadSites() async {
    final prefs = await SharedPreferences.getInstance();
    sites = prefs.getStringList('sites') ??
        [
          // English News
          "https://www.bbc.com/news",
          "https://www.reuters.com",
          "https://www.nytimes.com",
          "https://www.theguardian.com",
          "https://www.aljazeera.com",
          // Arabic News
          "https://www.aljazeera.net",
          "https://www.alarabiya.net",
          "https://www.skynewsarabia.com",
          "https://www.bbc.com/arabic",
          "https://aawsat.com",
          // French News
          "https://www.lemonde.fr",
          "https://www.lefigaro.fr",
          "https://www.france24.com/fr",
          "https://www.rfi.fr/fr",
          "https://www.liberation.fr",
          // Algerian News
          "https://www.tsa-algerie.com",
          "https://www.elwatan-dz.com",
          "https://www.elkhabar.com",
          "https://www.echoroukonline.com",
          "https://www.aps.dz"
        ];
    titles = jsonDecode(prefs.getString('site_titles') ?? "{}").cast<String, String>();
    setState(() {});
    _refreshAllTitles();
  }

  Future<void> _refreshAllTitles() async {
    for (final site in sites) {
      if (!titles.containsKey(site) || titles[site]!.isEmpty) {
        _fetchTitle(site);
      }
    }
  }

  Future<void> _saveSites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('sites', sites);
    await prefs.setString('site_titles', jsonEncode(titles));
  }

  String _sanitizeUrl(String url) {
    url = url.trim().replaceAll(' ', '');
    if (url.isEmpty) return "";
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    return url;
  }

  Future<void> _fetchTitle(String url) async {
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final match = RegExp(r'<title>(.*?)</title>', caseSensitive: false, dotAll: true).firstMatch(res.body);
        if (match != null) {
          final title = match.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim();
          setState(() => titles[url] = title);
          _saveSites();
        }
      }
    } catch (_) {}
  }

  void _addSite(String url) {
    final sanitized = _sanitizeUrl(url);
    if (sanitized.isNotEmpty && !sites.contains(sanitized)) {
      setState(() => sites.add(sanitized));
      _saveSites();
      _fetchTitle(sanitized);
    }
  }

  void _openBrowser(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BrowserPage(
          allowedSites: sites,
          initialUrl: url,
          onPermanentAdd: (newUrl) => _addSite(newUrl),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const Icon(Icons.language, color: Colors.blueAccent),
        title: const Text("Kiobro", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_link),
            onPressed: () => _showAddDialog(),
          ),
        ],
      ),
      body: sites.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: sites.length,
              onReorder: (oldIdx, newIdx) {
                if (newIdx > oldIdx) newIdx--;
                setState(() => sites.insert(newIdx, sites.removeAt(oldIdx)));
                _saveSites();
              },
              itemBuilder: (context, index) {
                final url = sites[index];
                final domain = Uri.parse(url).host;
                return _buildSiteTile(url, domain, index);
              },
            ),
    );
  }

  Widget _buildSiteTile(String url, String domain, int index) {
    return Dismissible(
      key: ValueKey(url),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        setState(() {
          sites.removeAt(index);
          titles.remove(url);
        });
        _saveSites();
      },
      background: Container(
        color: Colors.redAccent,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        color: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          onTap: () => _openBrowser(url),
          leading: CircleAvatar(
            backgroundColor: Colors.blueGrey.shade800,
            child: Text(domain.characters.first.toUpperCase(), style: const TextStyle(color: Colors.white)),
          ),
          title: Text(
            titles[url] ?? domain,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(domain, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          trailing: const Icon(Icons.drag_indicator, color: Colors.white24),
        ),
      ),
    );
  }

  void _showAddDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Ajouter un domaine"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: "exemple.com"),
          onSubmitted: (v) {
            _addSite(v);
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () {
              _addSite(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text("Ajouter"),
          ),
        ],
      ),
    );
  }
}
