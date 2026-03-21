// sops_page.dart - SOP/protocol library: list with type/status/tag filters,
// file upload to Supabase storage, PDF/DOCX viewer integration.
// Widget and dialog classes extracted to sops_widgets.dart (part).

import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/core/data_cache.dart';
import '/core/sop_db_schema.dart';
import '/theme/theme.dart';
import '../fish_facility/shared_widgets.dart';
import 'sop_model.dart';
import 'doc_viewer_page.dart';

part 'sops_widgets.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
class _DS {
  static const accent        = Color(0xFF06B6D4); // cyan — matches nav item
  static const yellow        = AppDS.yellow;
  static const red           = AppDS.red;

  static Color typeColor(String? t) {
    switch (t) {
      case 'sop':       return const Color(0xFF06B6D4);
      case 'protocol':  return AppDS.purple;
      case 'guideline': return AppDS.green;
      case 'checklist': return AppDS.orange;
      case 'form':      return AppDS.blue;
      case 'training':  return AppDS.pink;
      default:          return AppDS.textSecondary;
    }
  }

  static Color statusColor(String? s) {
    switch (s) {
      case 'active':       return AppDS.green;
      case 'draft':        return AppDS.yellow;
      case 'under_review': return const Color(0xFF06B6D4);
      case 'archived':     return AppDS.textMuted;
      case 'superseded':   return AppDS.red;
      default:             return AppDS.textSecondary;
    }
  }
}

final _dateFmt = DateFormat('yyyy-MM-dd');

// Deterministic tag colour — same text always maps to same colour.
Color _tagColor(String tag) {
  const palette = [
    Color(0xFF06B6D4), // cyan
    Color(0xFF8B5CF6), // violet
    Color(0xFF10B981), // emerald
    Color(0xFFF59E0B), // amber
    Color(0xFFEC4899), // pink
    Color(0xFF3B82F6), // blue
    Color(0xFFF97316), // orange
    Color(0xFFEF4444), // red
    Color(0xFF14B8A6), // teal
    Color(0xFFA3E635), // lime
  ];
  final hash = tag.codeUnits.fold(0, (h, c) => (h * 31 + c) & 0x7FFFFFFF);
  return palette[hash % palette.length];
}

// ═════════════════════════════════════════════════════════════════════════════
// SopPage
// ═════════════════════════════════════════════════════════════════════════════
class SopPage extends StatefulWidget {
  /// 'fish_facility' | 'culture_collection'
  final String sopContext;
  const SopPage({super.key, required this.sopContext});

  @override
  State<SopPage> createState() => _SopPageState();
}

class _SopPageState extends State<SopPage> {
  List<FacilitySop> _sops     = [];
  List<FacilitySop> _filtered = [];
  final _search = TextEditingController();
  bool    _loading = true;
  String? _error;
  String? _filterType;
  String? _filterStatus;

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(_applyFilter);
  }

  @override
  void didUpdateWidget(SopPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sopContext != widget.sopContext) {
      _sops     = [];
      _filtered = [];
      _filterType   = null;
      _filterStatus = null;
      _search.clear();
      _load();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    final cacheKey = 'sops_${widget.sopContext}';
    final cached = await DataCache.read(cacheKey);
    if (cached != null && mounted) {
      _sops = cached.map((r) => FacilitySop.fromMap(Map<String, dynamic>.from(r as Map))).toList();
      _applyFilter();
      setState(() { _loading = false; _error = null; });
    } else {
      setState(() { _loading = true; _error = null; });
    }
    try {
      final rows = await Supabase.instance.client
          .from(SopSch.table)
          .select()
          .eq(SopSch.context, widget.sopContext)
          .order(SopSch.name) as List<dynamic>;
      await DataCache.write(cacheKey, rows);
      if (!mounted) return;
      _sops = rows
          .map((r) => FacilitySop.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList();
      _applyFilter();
      setState(() => _loading = false);
    } catch (e) {
      if (cached == null && mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _applyFilter() {
    var d = _sops.toList();
    final q = _search.text.toLowerCase();
    if (q.isNotEmpty) {
      d = d.where((s) =>
        s.name.toLowerCase().contains(q) ||
        (s.code?.toLowerCase().contains(q)        ?? false) ||
        (s.category?.toLowerCase().contains(q)    ?? false) ||
        (s.responsible?.toLowerCase().contains(q) ?? false) ||
        (s.description?.toLowerCase().contains(q) ?? false) ||
        (s.tags?.toLowerCase().contains(q)        ?? false)
      ).toList();
    }
    if (_filterType   != null) d = d.where((s) => s.type   == _filterType).toList();
    if (_filterStatus != null) d = d.where((s) => s.status == _filterStatus).toList();
    setState(() => _filtered = d);
  }

  // ── Actions ───────────────────────────────────────────────────────────────
  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: TextStyle(color: context.appTextPrimary)),
      backgroundColor: isError ? _DS.red : context.appSurface3,
    ));
  }

  Future<void> _deleteSop(FacilitySop sop) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: dlgCtx.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Delete SOP',
            style: GoogleFonts.spaceGrotesk(
                color: dlgCtx.appTextPrimary, fontWeight: FontWeight.w700)),
        content: Text('Delete "${sop.name}"? This cannot be undone.',
            style: GoogleFonts.spaceGrotesk(color: dlgCtx.appTextSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.spaceGrotesk(color: dlgCtx.appTextSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: GoogleFonts.spaceGrotesk(color: _DS.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      if (sop.hasFile) {
        await Supabase.instance.client.storage
            .from(SopSch.bucket)
            .remove([sop.filePath!]);
      }
      await Supabase.instance.client
          .from(SopSch.table)
          .delete()
          .eq(SopSch.id, sop.id!);
      _snack('Deleted "${sop.name}"');
      _load();
    } catch (e) {
      _snack('Delete failed: $e', isError: true);
    }
  }

  Future<void> _openSopFile(
      FacilitySop sop, String filePath, String fileName, DocViewMode mode) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(
      content: Text('Loading file…'), duration: Duration(seconds: 30),
    ));
    try {
      final bytes = await Supabase.instance.client.storage
          .from(SopSch.bucket)
          .download(filePath);
      messenger.hideCurrentSnackBar();
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => DocViewerPage(
          bytes: bytes, title: sop.name, fileName: fileName, viewMode: mode,
        ),
      ));
    } catch (e) {
      messenger.hideCurrentSnackBar();
      if (mounted) _snack('Failed to open: $e', isError: true);
    }
  }

  void _showDialog({FacilitySop? sop}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SopDialog(sop: sop, sopContext: widget.sopContext),
    );
    if (saved == true) _load();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurface2,
        border: Border(bottom: BorderSide(color: context.appBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Title row ────────────────────────────────────────────────────
          Row(children: [
            const Icon(Icons.menu_book_outlined, color: _DS.accent, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text('SOPs / Protocols',
                  style: GoogleFonts.spaceGrotesk(
                      color: context.appTextPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ),
            ElevatedButton.icon(
              onPressed: () => _showDialog(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add SOP'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _DS.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: GoogleFonts.spaceGrotesk(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          // ── Filter row ───────────────────────────────────────────────────
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 240,
                child: AppSearchBar(
                  controller: _search,
                  hint: 'Search SOPs…',
                  onClear: _applyFilter,
                ),
              ),
              _DropFilter(
                value: _filterType,
                hint: 'All Types',
                options: FacilitySop.types,
                labelOf: FacilitySop.typeLabel,
                onChanged: (v) { setState(() => _filterType = v); _applyFilter(); },
              ),
              _DropFilter(
                value: _filterStatus,
                hint: 'All Statuses',
                options: FacilitySop.statuses,
                labelOf: FacilitySop.statusLabel,
                onChanged: (v) { setState(() => _filterStatus = v); _applyFilter(); },
              ),
              Text(
                '${_filtered.length} record${_filtered.length == 1 ? '' : 's'}',
                style: GoogleFonts.spaceGrotesk(fontSize: 12, color: context.appTextMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _DS.accent));
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: _DS.red)));
    }
    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 52, color: context.appTextMuted),
            const SizedBox(height: 14),
            Text(
              _sops.isEmpty
                  ? 'No SOPs yet — add your first one!'
                  : 'No SOPs match your search.',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 14, color: context.appTextSecondary),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _filtered.length,
      itemBuilder: (_, i) {
        final sop = _filtered[i];
        return _SopCard(
          sop: sop,
          onEdit:     () => _showDialog(sop: sop),
          onDelete:   () => _deleteSop(sop),
          onOpenPdf:  sop.hasPdfFile ? () => _openSopFile(sop, sop.filePath!,    sop.fileName    ?? 'document.pdf',  DocViewMode.pdf) : null,
          onOpenTxt:  sop.hasTxtFile ? () => _openSopFile(sop, sop.txtFilePath!, sop.txtFileName ?? 'document.txt',  DocViewMode.txt) : null,
          onOpenDoc:  sop.hasDocFile ? () => _openSopFile(sop, sop.docFilePath!, sop.docFileName ?? 'document.docx', DocViewMode.doc) : null,
        );
      },
    );
  }
}

