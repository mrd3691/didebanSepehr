import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'traccar_api.dart';
import 'tracking_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DidebanApp());
}

const ink = Color(0xFF10283F);
const sea = Color(0xFF007F78);
const paper = Color(0xFFF4F7F8);
const defaultTraccarServer = 'http://37.202.178.136:8082/';

class DidebanApp extends StatefulWidget {
  const DidebanApp({super.key});
  @override
  State<DidebanApp> createState() => _DidebanAppState();
}

class _DidebanAppState extends State<DidebanApp> {
  static const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  TraccarApi? api;
  bool restoring = true, configuring = false;
  String? message;
  String server = const String.fromEnvironment('TRACCAR_URL');
  int sessionGeneration = 0;

  @override
  void initState() {
    super.initState();
    restore();
  }

  Future<void> restore() async {
    TraccarApi? restored;
    try {
      server = await storage.read(key: 'server') ?? server;
      final value = await storage.read(key: 'session');
      if (value != null) {
        final saved = jsonDecode(value) as Map<String, dynamic>;
        server = saved['server'] as String;
        restored = TraccarApi(server, cookie: saved['cookie'] as String);
        await restored.session();
        if (!mounted) {
          restored.close();
          return;
        }
        accept(restored);
      }
    } catch (_) {
      restored?.close();
      message = 'Please sign in again to continue.';
    } finally {
      if (mounted) setState(() => restoring = false);
    }
  }

  Future<void> configureServer(String value) async {
    final normalized = TraccarApi.normalizeServer(value).toString();
    try {
      await storage.delete(key: 'session');
      await storage.write(key: 'server', value: normalized);
    } catch (_) {
      throw ApiException(
        'Unable to save the server address. Please try again.',
      );
    }
    if (mounted) {
      setState(() {
        server = normalized;
        configuring = false;
        message = null;
      });
    }
  }

  void accept(TraccarApi next) {
    final generation = ++sessionGeneration;
    next.onUnauthorized = () {
      if (generation != sessionGeneration) return;
      scheduleMicrotask(() => logout(expired: true));
    };
    setState(() {
      api = next;
      message = null;
    });
  }

  Future<void> login(
    String url,
    String username,
    String password,
    bool remember,
  ) async {
    final next = TraccarApi(url);
    try {
      await next.login(username, password);
      try {
        if (remember) {
          await storage.write(
            key: 'session',
            value: jsonEncode({
              'server': next.base.toString(),
              'cookie': next.cookie,
            }),
          );
        } else {
          await storage.delete(key: 'session');
        }
      } catch (_) {
        throw ApiException(
          'Unable to securely save your session. Please try again.',
        );
      }
      if (!mounted) {
        next.close();
        return;
      }
      server = url;
      accept(next);
    } catch (_) {
      next.close();
      rethrow;
    }
  }

  Future<void> logout({bool expired = false}) async {
    final previous = api;
    if (previous == null) return;
    sessionGeneration++;
    previous.onUnauthorized = null;
    setState(() {
      api = null;
      message = expired
          ? 'Your session has expired. Please sign in again.'
          : null;
    });
    try {
      await storage.delete(key: 'session');
    } catch (_) {
      if (mounted) {
        setState(
          () => message =
              'Unable to clear the saved session. Please sign in again.',
        );
      }
    }
    if (!expired) {
      try {
        await previous.request('DELETE', 'session');
      } catch (_) {
        /* Local session is already cleared. */
      }
    }
    previous.close();
  }

  @override
  void dispose() {
    api?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Dideban Sepehr',
    theme: buildDidebanTheme(),
    home: restoring
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : api == null
        ? (server.isEmpty || configuring
              ? ServerSetupScreen(
                  initialServer: server.isEmpty ? defaultTraccarServer : server,
                  onSave: configureServer,
                  onCancel: server.isEmpty
                      ? null
                      : () => setState(() => configuring = false),
                )
              : LoginScreen(
                  server: server,
                  message: message,
                  onLogin: login,
                  onChangeServer: () => setState(() => configuring = true),
                ))
        : TrackingScreen(
            key: ObjectKey(api),
            api: api!,
            onLogout: () => logout(),
          ),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.server,
    this.message,
    this.onChangeServer,
    required this.onLogin,
  });
  final String server;
  final String? message;
  final VoidCallback? onChangeServer;
  final Future<void> Function(String, String, String, bool) onLogin;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final form = GlobalKey<FormState>();
  final username = TextEditingController(), password = TextEditingController();
  bool busy = false, obscure = true, remember = true;
  String? error;
  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onLogin(
        widget.server,
        username.text.trim(),
        password.text,
        remember,
      );
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is ApiException
              ? e.message
              : 'Sign-in failed. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ink,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.radar_rounded,
                        size: 30,
                        color: Color(0xFF53DDCA),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Flexible(
                      child: Text(
                        'Dideban Sepehr',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE1E8EB)),
                  ),
                  child: Form(
                    key: form,
                    child: AutofillGroup(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: username,
                            enabled: !busy,
                            autofillHints: const [AutofillHints.username],
                            autocorrect: false,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Enter your username.'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: password,
                            enabled: !busy,
                            obscureText: obscure,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => submit(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => obscure = !obscure),
                                tooltip: obscure
                                    ? 'Show password'
                                    : 'Hide password',
                                icon: Icon(
                                  obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (v) => v == null || v.isEmpty
                                ? 'Enter your password.'
                                : null,
                          ),
                          const SizedBox(height: 4),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: const Text(
                              'Remember me',
                              style: TextStyle(fontSize: 14),
                            ),
                            value: remember,
                            onChanged: busy
                                ? null
                                : (v) => setState(() => remember = v!),
                          ),
                          if (error != null || widget.message != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                error ?? widget.message!,
                                style: const TextStyle(
                                  color: Colors.deepOrange,
                                ),
                              ),
                            ),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: busy ? null : submit,
                              child: busy
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Sign in'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.dns_outlined,
                      color: Colors.blueGrey,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.server,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.blueGrey,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (widget.onChangeServer != null)
                      TextButton(
                        onPressed: busy ? null : widget.onChangeServer,
                        child: const Text('Change'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class ServerSetupScreen extends StatefulWidget {
  const ServerSetupScreen({
    super.key,
    this.initialServer = defaultTraccarServer,
    required this.onSave,
    this.onCancel,
  });
  final String initialServer;
  final Future<void> Function(String) onSave;
  final VoidCallback? onCancel;
  @override
  State<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends State<ServerSetupScreen> {
  final form = GlobalKey<FormState>();
  late final url = TextEditingController(text: widget.initialServer);
  bool busy = false;
  String? error;
  @override
  void dispose() {
    url.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onSave(url.text.trim());
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is ApiException
              ? e.message
              : 'Unable to save. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.onCancel == null
        ? null
        : AppBar(
            leading: IconButton(
              onPressed: busy ? null : widget.onCancel,
              icon: const Icon(Icons.arrow_back),
            ),
          ),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: ink,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.radar_rounded,
                      color: Color(0xFF53DDCA),
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'DIDEBAN SEPEHR',
                    style: TextStyle(
                      color: sea,
                      fontSize: 12,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Set up your server',
                    style: TextStyle(
                      color: ink,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Enter your Traccar server address once. It will be saved for future sign-ins.',
                    style: TextStyle(color: Colors.blueGrey, height: 1.6),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: url,
                    enabled: !busy,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    onFieldSubmitted: (_) => save(),
                    decoration: const InputDecoration(
                      labelText: 'Traccar server address',
                      hintText: 'http://37.202.178.136:8082',
                      prefixIcon: Icon(Icons.dns_outlined),
                    ),
                    validator: (value) {
                      try {
                        TraccarApi.normalizeServer(value ?? '');
                        return null;
                      } catch (e) {
                        return e is ApiException
                            ? e.message
                            : 'Enter a valid server address.';
                      }
                    },
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        error!,
                        style: const TextStyle(color: Colors.deepOrange),
                      ),
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: busy ? null : save,
                      icon: busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_forward),
                      label: Text(busy ? 'Saving...' : 'Save and continue'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

ThemeData buildDidebanTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'SepehrSans',
  colorScheme: ColorScheme.fromSeed(
    seedColor: sea,
    primary: sea,
    secondary: ink,
  ),
  scaffoldBackgroundColor: paper,
  appBarTheme: const AppBarTheme(
    backgroundColor: paper,
    foregroundColor: ink,
    centerTitle: false,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFDCE4E8)),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
);
