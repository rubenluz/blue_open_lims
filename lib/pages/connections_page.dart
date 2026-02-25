import 'package:flutter/material.dart';
import '../core/local_storage.dart';
import '../models/connection_model.dart';
import '../core/supabase_manager.dart';

class ConnectionsPage extends StatefulWidget {
  const ConnectionsPage({super.key});

  @override
  State<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends State<ConnectionsPage> {
  List<ConnectionModel> connections = [];
  int? selectedIndex;
  final Map<int, bool> healthStatus = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await LocalStorage.loadConnections();
    setState(() => connections = list);
    _checkHealth();
  }

  Future<void> _checkHealth() async {
    for (int i = 0; i < connections.length; i++) {
      try {
        await SupabaseManager.initialize(connections[i]);
        healthStatus[i] = true;
      } catch (_) {
        healthStatus[i] = false;
      }
      if (mounted) setState(() {});
    }
  }

  Future<void> _deleteConnection(int index) async {
    connections.removeAt(index);
    await LocalStorage.saveConnections(connections);
    setState(() {});
  }

  void _showActions(int index) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.pushNamed(
                  context,
                  '/add_connection',
                  arguments: connections[index],
                );
                _load();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                _deleteConnection(index);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _connect(ConnectionModel conn, int index) async {
    setState(() => selectedIndex = index);

    await SupabaseManager.initialize(conn);

    conn.lastConnected = DateTime.now();
    await LocalStorage.saveConnections(connections);

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/db_check');
  }

  String _lastConnectedText(ConnectionModel conn) {
    if (conn.lastConnected == null) return 'Never connected';

    final diff = DateTime.now().difference(conn.lastConnected!);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} h ago';

    return '${diff.inDays} d ago';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Database'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.pushNamed(context, '/add_connection');
              _load();
            },
          )
        ],
      ),

      floatingActionButton: connections.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.pushNamed(context, '/add_connection');
                _load();
              },
              icon: const Icon(Icons.add),
              label: const Text('New'),
            )
          : null,

      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: connections.isEmpty
            ? _emptyState()
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: connections.length,
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 320,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                ),
                itemBuilder: (context, index) {
                  final conn = connections[index];
                  final selected = selectedIndex == index;

                  return GestureDetector(
                    onLongPress: () => _showActions(index),
                    onTap: () => _connect(conn, index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: selected
                              ? scheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: [
                          if (selected)
                            BoxShadow(
                              color: scheme.primary.withOpacity(.25),
                              blurRadius: 12,
                            )
                        ],
                      ),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.storage,
                                      color: scheme.primary),
                                  const Spacer(),

                                  /// ✅ health dot
                                  AnimatedContainer(
                                    duration: const Duration(
                                        milliseconds: 300),
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: healthStatus[index] ==
                                              true
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  )
                                ],
                              ),

                              const Spacer(),

                              Text(
                                conn.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium,
                              ),

                              const SizedBox(height: 6),

                              Text(
                                conn.url,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall,
                              ),

                              const SizedBox(height: 12),

                              Text(
                                _lastConnectedText(conn),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall,
                              ),

                              /// ✅ animated check
                              Align(
                                alignment: Alignment.bottomRight,
                                child: AnimatedScale(
                                  scale: selected ? 1 : 0,
                                  duration:
                                      const Duration(milliseconds: 250),
                                  child: Icon(Icons.check_circle,
                                      color: scheme.primary),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.storage_rounded,
              size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('No connections saved'),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Connection'),
            onPressed: () async {
              await Navigator.pushNamed(context, '/add_connection');
              _load();
            },
          )
        ],
      ),
    );
  }
}