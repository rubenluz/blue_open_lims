import 'package:flutter/material.dart';
import '../core/local_storage.dart';
import '../core/supabase_manager.dart';
import '../models/connection_model.dart';

class AddConnectionPage extends StatefulWidget {
  const AddConnectionPage({super.key});

  @override
  State<AddConnectionPage> createState() => _AddConnectionPageState();
}

class _AddConnectionPageState extends State<AddConnectionPage> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final urlController = TextEditingController();
  final anonKeyController = TextEditingController();

  bool _obscureKey = true;
  bool _isSaving = false;
  bool _isTesting = false;
  bool? _testResult; // null = untested, true = ok, false = failed

  ConnectionModel? _editingConn; // non-null when editing

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is ConnectionModel && _editingConn == null) {
      _editingConn = args;
      nameController.text = args.name;
      urlController.text = args.url;
      anonKeyController.text = args.anonKey;
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    urlController.dispose();
    anonKeyController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isTesting = true;
      _testResult = null;
    });
    final ok = await SupabaseManager.testConnection(
      ConnectionModel(
        name: nameController.text.trim(),
        url: urlController.text.trim(),
        anonKey: anonKeyController.text.trim(),
      ),
    );
    if (mounted) setState(() {
      _isTesting = false;
      _testResult = ok;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final conn = ConnectionModel(
      name: nameController.text.trim(),
      url: urlController.text.trim(),
      anonKey: anonKeyController.text.trim(),
      lastConnected: _editingConn?.lastConnected,
    );

    if (_editingConn != null) {
      final list = await LocalStorage.loadConnections();
      final idx = list.indexWhere((c) => c.url == _editingConn!.url);
      if (idx != -1) list[idx] = conn;
      await LocalStorage.saveConnections(list);
    } else {
      await LocalStorage.addConnection(conn);
    }

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isEditing = _editingConn != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Connection' : 'New Connection'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Header ─────────────────────────────────────
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.storage_rounded,
                              color: scheme.onPrimaryContainer, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEditing ? 'Edit Connection' : 'New Connection',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Enter your Supabase project details',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: scheme.outline),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // ── Fields ─────────────────────────────────────
                    _SectionLabel(label: 'Connection Name'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: nameController,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(
                        context,
                        hint: 'e.g. Production DB',
                        icon: Icons.label_outline,
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                      onChanged: (_) => setState(() => _testResult = null),
                    ),

                    const SizedBox(height: 20),
                    _SectionLabel(label: 'Supabase URL'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: urlController,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(
                        context,
                        hint: 'https://xxxx.supabase.co',
                        icon: Icons.link_rounded,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (!v.trim().startsWith('https://')) {
                          return 'Must start with https://';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() => _testResult = null),
                    ),

                    const SizedBox(height: 20),
                    _SectionLabel(label: 'Anon Key'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: anonKeyController,
                      obscureText: _obscureKey,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _save(),
                      decoration: _inputDecoration(
                        context,
                        hint: 'eyJhbGciOiJIUzI1NiIs...',
                        icon: Icons.vpn_key_outlined,
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(_obscureKey
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () =>
                              setState(() => _obscureKey = !_obscureKey),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                      onChanged: (_) => setState(() => _testResult = null),
                    ),

                    const SizedBox(height: 28),

                    // ── Test result banner ─────────────────────────
                    if (_testResult != null)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: _testResult!
                              ? Colors.green.withOpacity(.1)
                              : scheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _testResult!
                                ? Colors.green
                                : scheme.error,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _testResult!
                                  ? Icons.check_circle_outline
                                  : Icons.error_outline,
                              color: _testResult!
                                  ? Colors.green
                                  : scheme.error,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _testResult!
                                  ? 'Connection successful!'
                                  : 'Could not reach the database.',
                              style: TextStyle(
                                color: _testResult!
                                    ? Colors.green
                                    : scheme.onErrorContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── Buttons ────────────────────────────────────
                    Row(
                      children: [
                        // Test button
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (_isTesting || _isSaving)
                                ? null
                                : _testConnection,
                            icon: _isTesting
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: scheme.primary),
                                  )
                                : const Icon(Icons.wifi_tethering_rounded),
                            label: Text(_isTesting ? 'Testing…' : 'Test'),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Save button
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: (_isSaving || _isTesting)
                                ? null
                                : _save,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white),
                                  )
                                : Icon(isEditing
                                    ? Icons.save_outlined
                                    : Icons.add_rounded),
                            label: Text(_isSaving
                                ? 'Saving…'
                                : isEditing
                                    ? 'Save Changes'
                                    : 'Add Connection'),
                            style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
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

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest
          .withOpacity(.4),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
    );
  }
}