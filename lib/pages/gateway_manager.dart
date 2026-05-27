import 'dart:convert';
import 'dart:io' show HttpClient;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'gateway_setup_page.dart';

// ─── Gateway Auth State ──────────────────────────────────────────────────────

enum _GatewayState { setup, login, authenticated }

class GatewayManager extends StatefulWidget {
  final Widget child;

  const GatewayManager({super.key, required this.child});

  @override
  State<GatewayManager> createState() => _GatewayManagerState();
}

class _GatewayManagerState extends State<GatewayManager> {
  _GatewayState _state = _GatewayState.setup;
  String _baseUrl = '';
  String _ownerName = 'Spark';
  Map<String, dynamic>? _user;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('gateway_base_url');
      final savedUser = prefs.getString('gateway_user');
      final savedOwner = prefs.getString('gateway_owner_name');

      if (savedUrl != null && savedUser != null) {
        final user = jsonDecode(savedUser) as Map<String, dynamic>;
        setState(() {
          _baseUrl = savedUrl;
          _ownerName = savedOwner ?? 'Spark';
          _user = user;
          _state = _GatewayState.authenticated;
        });
      } else if (savedUrl != null) {
        setState(() {
          _baseUrl = savedUrl;
          _ownerName = savedOwner ?? 'Spark';
          _state = _GatewayState.login;
        });
      } else {
        setState(() => _state = _GatewayState.setup);
      }
    } catch (_) {
      setState(() => _state = _GatewayState.setup);
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _onGatewaySet(String url) async {
    String ownerName = 'Spark';
    try {
      final uri = Uri.parse('$url/api/config');
      final client = HttpClient();
      final req = await client.getUrl(uri);
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      client.close();
      // If your worker config has a gateway_name key, use it
      final configMap = data['config'] as Map<String, dynamic>?;
      if (configMap != null && configMap['gateway_name'] != null) {
        ownerName = configMap['gateway_name'].toString();
      }
    } catch (_) {
      // Keep default name on error
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gateway_base_url', url);
    await prefs.setString('gateway_owner_name', ownerName);

    if (mounted) {
      setState(() {
        _baseUrl = url;
        _ownerName = ownerName;
        _state = _GatewayState.login;
      });
    }
  }

  Future<void> _onLoginSuccess(
    Map<String, dynamic> user,
    String baseUrl,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gateway_user', jsonEncode(user));
    await prefs.setString('gateway_base_url', baseUrl);

    if (mounted) {
      setState(() {
        _user = user;
        _state = _GatewayState.authenticated;
      });
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('gateway_user');
    if (mounted) {
      setState(() {
        _user = null;
        _state = _GatewayState.login;
      });
    }
  }

  Future<void> _resetGateway() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('gateway_base_url');
    await prefs.remove('gateway_user');
    await prefs.remove('gateway_owner_name');
    if (mounted) {
      setState(() {
        _baseUrl = '';
        _ownerName = 'Spark';
        _user = null;
        _state = _GatewayState.setup;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Scaffold(
        backgroundColor: Color(0xFF000000),
        body: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Color(0xFF333333),
            ),
          ),
        ),
      );
    }

    switch (_state) {
      case _GatewayState.setup:
        return GatewaySetupPage(onGatewaySet: _onGatewaySet);

      case _GatewayState.login:
        return GatewayLoginPage(
          baseUrl: _baseUrl,
          ownerName: _ownerName,
          onLoginSuccess: _onLoginSuccess,
          onBack: _resetGateway,
        );

      case _GatewayState.authenticated:
        return GatewayUserScope(
          user: _user!,
          baseUrl: _baseUrl,
          ownerName: _ownerName,
          onLogout: _logout,
          child: widget.child,
        );
    }
  }
}

// ─── Inherited widget so child screens can access gateway user info ───────────

class GatewayUserScope extends InheritedWidget {
  final Map<String, dynamic> user;
  final String baseUrl;
  final String ownerName;
  final VoidCallback onLogout;

  const GatewayUserScope({
    super.key,
    required this.user,
    required this.baseUrl,
    required this.ownerName,
    required this.onLogout,
    required super.child,
  });

  static GatewayUserScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<GatewayUserScope>();
  }

  @override
  bool updateShouldNotify(GatewayUserScope old) =>
      user != old.user || baseUrl != old.baseUrl;
}
