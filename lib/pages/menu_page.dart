import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'samples/samples_page.dart';
import 'strains/strains_page.dart';
import 'dashboard_page.dart';

class _Module {
  final String id;
  final String label;
  final IconData icon;
  final Color accent;
  final bool comingSoon;
  final bool enabled;
  final Widget Function(_MenuPageState state)? builder;

  const _Module({
    required this.id,
    required this.label,
    required this.icon,
    required this.accent,
    this.builder,
    this.comingSoon = false,
    this.enabled = true,
  });
}

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  String _selectedId = 'dashboard';
  Map<String, dynamic> _userInfo = {};
  List<Map<String, dynamic>> _pendingUsers = [];
  bool _loadingUser = true;
  bool _sidebarCollapsed = false;

  late final List<_Module> _modules = [
    _Module(
      id: 'dashboard',
      label: 'Dashboard',
      icon: Icons.space_dashboard_outlined,
      accent: const Color(0xFF6366F1),
      builder: (s) => DashboardPage(
        userInfo: s._userInfo,
        pendingUsers: s._pendingUsers,
        onGoToPendingUsers: () => s._select('pending'),
      ),
    ),
    _Module(
      id: 'strains',
      label: 'Strains',
      icon: Icons.biotech_outlined,
      accent: const Color(0xFF10B981),
      builder: (_) => const StrainsPage(),
    ),
    _Module(
      id: 'samples',
      label: 'Samples',
      icon: Icons.colorize_outlined,
      accent: const Color(0xFF3B82F6),
      builder: (_) => const SamplesPage(),
    ),
    const _Module(id: 'reagents', label: 'Reagents', icon: Icons.water_drop_outlined, accent: const Color(0xFFF59E0B), comingSoon: true),
    const _Module(id: 'zebrafish', label: 'Zebrafish Facility', icon: Icons.set_meal_outlined, accent: const Color(0xFF8B5CF6), comingSoon: true),
    const _Module(id: 'reservations', label: 'Reservations', icon: Icons.event_outlined, accent: const Color(0xFFEC4899), comingSoon: true),
    const _Module(id: 'equipment', label: 'Equipment', icon: Icons.precision_manufacturing_outlined, accent: const Color(0xFF14B8A6), comingSoon: true),
    const _Module(id: 'orders', label: 'Orders', icon: Icons.shopping_bag_outlined, accent: const Color(0xFFF97316), comingSoon: true),
    const _Module(id: 'protocols', label: 'Protocols', icon: Icons.menu_book_outlined, accent: const Color(0xFF06B6D4), comingSoon: true),
    const _Module(id: 'audit', label: 'Audit Log', icon: Icons.manage_search_outlined, accent: const Color(0xFF6B7280), comingSoon: true),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final email = session?.user.email ?? '';
      final rows = await Supabase.instance.client.from('users').select().eq('username', email).limit(1);
      if (rows.isNotEmpty) {
        setState(() {
          _userInfo = Map<String, dynamic>.from(rows[0]);
          _loadingUser = false;
        });
        if (_userInfo['role'] == 'superadmin') _loadPendingUsers();
      }
    } catch (_) {
      setState(() => _loadingUser = false);
    }
  }

  Future<void> _loadPendingUsers() async {
    try {
      final res = await Supabase.instance.client.from('users').select().eq('status', 'pending');
      setState(() => _pendingUsers = List<Map<String, dynamic>>.from(res));
    } catch (_) {}
  }

  Future<void> _approveUser(dynamic userId) async {
    await Supabase.instance.client.from('users').update({'status': 'active'}).eq('id', userId);
    _loadPendingUsers();
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/connections');
  }

  _Module? get _currentModule => _modules.where((m) => m.id == _selectedId).firstOrNull;

  void _select(String id, [NavigatorState? nav]) {
    setState(() => _selectedId = id);
    nav?.pop();
  }

  Widget _buildPageContent() {
    if (_selectedId == 'pending') return _buildPendingUsers();
    final module = _currentModule;
    if (module?.builder != null) return module!.builder!(this);
    return _buildComingSoon(module);
  }

  Widget _buildPendingUsers() => const Center(child: Text('Pending Approvals Page'));

  Widget _buildComingSoon(_Module? m) => Center(child: Text('${m?.label} coming soon'));

  // ── REPAIRED SIDEBAR ──────────────────────────────────────────────────────
  
  Widget _buildSidebar({bool isDrawer = false}) {
    final isSuperAdmin = _userInfo['role'] == 'superadmin';
    final bool collapsed = !isDrawer && _sidebarCollapsed;
    final double sidebarW = collapsed ? 70.0 : 250.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: sidebarW,
      child: Material(
        color: const Color(0xFF0F172A),
        child: Column(
          children: [
            // Logo / Header
            SizedBox(
              height: 64,
              child: Center(
                child: ListTile(
                  leading: const Icon(Icons.biotech, color: Color(0xFF6366F1)),
                  title: collapsed ? null : const Text('BlueOpenLIMS', 
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, overflow: TextOverflow.ellipsis)),
                ),
              ),
            ),
            
            // Nav Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  ..._modules.where((m) => m.enabled).map((m) => _buildNavItem(m, collapsed, isDrawer)),
                  if (isSuperAdmin)
                    _buildNavItemRaw(
                      id: 'pending',
                      icon: Icons.how_to_reg_outlined,
                      label: 'Pending',
                      accent: Colors.redAccent,
                      collapsed: collapsed,
                      isDrawer: isDrawer,
                      badge: _pendingUsers.isNotEmpty ? '${_pendingUsers.length}' : null,
                    ),
                ],
              ),
            ),

            // Collapse Toggle Button
            if (!isDrawer)
              IconButton(
                icon: Icon(collapsed ? Icons.chevron_right : Icons.chevron_left, color: Colors.white38),
                onPressed: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
              ),
            
            // Logout
            ListTile(
              onTap: _logout,
              leading: const Icon(Icons.logout, color: Colors.white38),
              title: collapsed ? null : const Text('Logout', style: TextStyle(color: Colors.white70)),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(_Module m, bool collapsed, bool isDrawer) {
    return _buildNavItemRaw(
      id: m.id,
      icon: m.icon,
      label: m.label,
      accent: m.accent,
      collapsed: collapsed,
      isDrawer: isDrawer,
      comingSoon: m.comingSoon,
    );
  }

  Widget _buildNavItemRaw({
    required String id,
    required IconData icon,
    required String label,
    required Color accent,
    required bool collapsed,
    required bool isDrawer,
    bool comingSoon = false,
    String? badge,
  }) {
    final bool selected = _selectedId == id;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Tooltip(
        message: collapsed ? label : "",
        child: ListTile(
          selected: selected,
          onTap: comingSoon ? null : () => _select(id, isDrawer ? Navigator.of(context) : null),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minLeadingWidth: 56,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: Icon(icon, color: selected ? accent : (comingSoon ? Colors.white24 : Colors.white54)),
          title: collapsed ? null : Text(
            label, 
            maxLines: 1,
            overflow: TextOverflow.fade,
            style: TextStyle(
              color: selected ? Colors.white : (comingSoon ? Colors.white24 : Colors.white70),
              fontSize: 13,
            ),
          ),
          trailing: !collapsed && badge != null 
            ? Container(
                padding: const EdgeInsets.all(6), 
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                child: Text(badge, style: const TextStyle(fontSize: 10, color: Colors.white)),
              )
            : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      drawer: isMobile ? Drawer(child: _buildSidebar(isDrawer: true)) : null,
      body: _loadingUser
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Row(
                children: [
                  if (!isMobile) _buildSidebar(),
                  Expanded(
                    child: Stack(
                      children: [
                        _buildPageContent(),
                        if (isMobile)
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Builder(builder: (ctx) => IconButton(
                              icon: const Icon(Icons.menu),
                              onPressed: () => Scaffold.of(ctx).openDrawer(),
                            )),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}