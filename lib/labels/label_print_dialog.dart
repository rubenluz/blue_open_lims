// label_print_dialog.dart - Part of label_page.dart.
// Print full page: batch record selection, search/filter, live preview, ZPL/QL dispatch.
// Widgets: _PrintLabelPage, _FilterBar, _RecordList, _EmptyRecordsPanel.

part of 'label_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Print full page — record selection, filtering, live preview, print dispatch
// ─────────────────────────────────────────────────────────────────────────────
class _PrintLabelPage extends StatefulWidget {
  final LabelTemplate template;
  final PrinterConfig printer;
  final List<Map<String, dynamic>> initialRecords;
  final String entityType;

  const _PrintLabelPage({
    required this.template,
    required this.printer,
    this.initialRecords = const [],
    this.entityType = 'General',
  });

  @override
  State<_PrintLabelPage> createState() => _PrintLabelPageState();
}

class _PrintLabelPageState extends State<_PrintLabelPage> {
  List<Map<String, dynamic>> _records = [];
  Set<dynamic> _selectedIds = {};
  int _previewIndex = 0;
  bool _loading = false;
  bool _isPrinting = false;
  String? _status;

  String _search = '';
  String _statusFilter = '';
  final _searchCtrl = TextEditingController();

  String get _idCol => _idColForCategory(widget.entityType);

  String? get _filterCol => switch (widget.entityType) {
    'Strains'   => 'strain_status',
    'Stocks'    => 'fish_stocks_status',
    'Equipment' => 'eq_status',
    'Samples'   => 'sample_type',
    _ => null,
  };

  List<Map<String, dynamic>> get _displayRecords {
    var list = _records;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where((r) =>
              r.values.any((v) => v?.toString().toLowerCase().contains(q) == true))
          .toList();
    }
    if (_statusFilter.isNotEmpty) {
      final col = _filterCol;
      if (col != null) {
        list = list.where((r) => r[col]?.toString() == _statusFilter).toList();
      }
    }
    return list;
  }

  List<Map<String, dynamic>> get _selectedRecords =>
      _displayRecords.where((r) => _selectedIds.contains(r[_idCol])).toList();

  List<String> get _filterOptions {
    final col = _filterCol;
    if (col == null) return [];
    return (_records
            .map((r) => r[col]?.toString() ?? '')
            .where((v) => v.isNotEmpty)
            .toSet()
            .toList()
          ..sort());
  }

  int get _totalLabels =>
      (_selectedRecords.isEmpty ? 1 : _selectedRecords.length) *
      widget.template.copies;

  Map<String, dynamic> get _previewData {
    final display = _displayRecords;
    if (display.isEmpty) return _sampleDataFor(widget.entityType);
    return display[_previewIndex.clamp(0, display.length - 1)];
  }

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    if (widget.initialRecords.isNotEmpty) {
      _records = List.from(widget.initialRecords);
      _selectedIds = _records.map((r) => r[_idCol]).toSet();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _search = prefs.getString('print_search_${widget.entityType}') ?? '';
      _statusFilter = prefs.getString('print_status_${widget.entityType}') ?? '';
      _searchCtrl.text = _search;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('print_search_${widget.entityType}', _search);
    await prefs.setString('print_status_${widget.entityType}', _statusFilter);
  }

  Future<void> _loadFromDb() async {
    setState(() { _loading = true; _status = null; });
    try {
      final rows = await Supabase.instance.client
          .from(_tableForEntity(widget.entityType))
          .select() as List<dynamic>;
      final records = rows.cast<Map<String, dynamic>>();
      _injectQr(records, widget.entityType);
      if (!mounted) return;
      setState(() {
        _records = records;
        _selectedIds = records.map((r) => r[_idCol]).toSet();
        _previewIndex = 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _status = 'Failed to load: $e'; });
    }
  }

  Future<void> _doPrint() async {
    if (_isPrinting) return;
    final proto = (widget.printer.protocol == 'brother_ql' ||
            widget.printer.protocol == 'brother_ql_legacy')
        ? 'Brother QL'
        : 'ZPL';
    setState(() { _isPrinting = true; _status = 'Generating $proto data…'; });
    try {
      final batch =
          _selectedRecords.isEmpty ? <Map<String, dynamic>>[] : _selectedRecords;
      setState(() => _status = 'Connecting to ${widget.printer.ipAddress}…');
      await _sendToPrinter(widget.template, batch, widget.printer);
      final n = _totalLabels;
      if (!mounted) return;
      setState(() {
        _isPrinting = false;
        _status = 'Sent $n label${n != 1 ? 's' : ''} to printer ✓';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _isPrinting = false; _status = 'Error: $e'; });
    }
  }

  void _toggleAll() {
    final display = _displayRecords;
    final displayIds = display.map((r) => r[_idCol]).toSet();
    final allSel = displayIds.every(_selectedIds.contains);
    setState(() {
      if (allSel) {
        _selectedIds.removeAll(displayIds);
      } else {
        _selectedIds.addAll(displayIds);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final display = _displayRecords;
    final hasRecords = _records.isNotEmpty;
    final isError = _status != null && _status!.startsWith('Error');
    final isDone  = _status != null && _status!.contains('✓');

    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: AppDS.bg,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.template.name,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          Text(
            '${widget.template.labelW.toInt()}×${widget.template.labelH.toInt()} mm · ${widget.entityType}',
            style: const TextStyle(color: AppDS.textSecondary, fontSize: 11),
          ),
        ]),
        actions: [
          if (_status != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Center(
                child: Text(_status!,
                    style: TextStyle(
                        fontSize: 12,
                        color: isError
                            ? AppDS.red
                            : isDone
                                ? AppDS.green
                                : AppDS.textSecondary)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: AppDS.accent,
                  foregroundColor: AppDS.bg,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
              icon: _isPrinting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          color: AppDS.bg, strokeWidth: 2))
                  : const Icon(Icons.print_rounded, size: 15),
              label: Text(
                  _isPrinting
                      ? 'Printing…'
                      : 'Print $_totalLabels label${_totalLabels != 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 13)),
              onPressed: _isPrinting ? null : _doPrint,
            ),
          ),
        ],
      ),
      body: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Left: label preview ──────────────────────────────────────────────
        Container(
          width: 260,
          color: const Color(0xFF0A0F1A),
          child: Column(children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 12)
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _PreviewCanvas(
                        template: widget.template,
                        scale: 3.0,
                        sampleData: _previewData,
                      ),
                    ),
                    if (!hasRecords) ...[
                      const SizedBox(height: 10),
                      const Text('Sample preview',
                          style: TextStyle(
                              fontSize: 10, color: AppDS.textSecondary)),
                    ],
                  ]),
                ),
              ),
            ),
            if (display.isNotEmpty)
              Container(
                color: AppDS.surface,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 18),
                    color: AppDS.textSecondary,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: _previewIndex > 0
                        ? () => setState(() => _previewIndex--)
                        : null,
                  ),
                  Expanded(
                    child: Text(
                      '${_previewIndex + 1} / ${display.length}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 11, color: AppDS.textSecondary),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 18),
                    color: AppDS.textSecondary,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: _previewIndex < display.length - 1
                        ? () => setState(() => _previewIndex++)
                        : null,
                  ),
                ]),
              ),
          ]),
        ),
        VerticalDivider(width: 1, color: context.appBorder),

        // ── Right: filter bar + record list ─────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppDS.accent, strokeWidth: 2))
              : Column(children: [
                  _FilterBar(
                    search: _search,
                    searchCtrl: _searchCtrl,
                    statusFilter: _statusFilter,
                    filterOptions: _filterOptions,
                    filterLabel: _filterLabelFor(widget.entityType),
                    hasRecords: hasRecords,
                    onLoad: _loadFromDb,
                    onSearchChanged: (v) {
                      setState(() { _search = v; _previewIndex = 0; });
                      _savePrefs();
                    },
                    onStatusChanged: (v) {
                      setState(() { _statusFilter = v ?? ''; _previewIndex = 0; });
                      _savePrefs();
                    },
                  ),
                  Divider(height: 1, color: context.appBorder),
                  if (!hasRecords)
                    Expanded(
                        child: _EmptyRecordsPanel(
                            entityType: widget.entityType, onLoad: _loadFromDb))
                  else if (display.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text('No records match the filter.',
                            style: TextStyle(
                                fontSize: 13,
                                color: context.appTextSecondary)),
                      ),
                    )
                  else
                    Expanded(
                      child: _RecordList(
                        records: display,
                        selectedIds: _selectedIds,
                        idCol: _idCol,
                        previewIndex: _previewIndex,
                        onToggle: (r) {
                          final id = r[_idCol];
                          setState(() {
                            if (_selectedIds.contains(id)) {
                              _selectedIds.remove(id);
                            } else {
                              _selectedIds.add(id);
                            }
                          });
                        },
                        onToggleAll: _toggleAll,
                        onTapRow: (i) => setState(() => _previewIndex = i),
                      ),
                    ),
                  Divider(height: 1, color: context.appBorder),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(children: [
                      Text(
                        hasRecords
                            ? '${_selectedRecords.length} of ${display.length} shown · ${_records.length} total · $_totalLabels label${_totalLabels != 1 ? 's' : ''}'
                            : 'No records loaded — printing will use sample data',
                        style: TextStyle(
                            fontSize: 11,
                            color: context.appTextSecondary),
                      ),
                    ]),
                  ),
                ]),
        ),
      ]),
    );
  }
}

String _filterLabelFor(String entityType) => switch (entityType) {
  'Strains'   => 'Status',
  'Stocks'    => 'Status',
  'Equipment' => 'Status',
  'Samples'   => 'Type',
  _ => '',
};

// ─────────────────────────────────────────────────────────────────────────────
// Filter bar — search + entity-specific dropdown + load/reload button
// ─────────────────────────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  final String search;
  final TextEditingController searchCtrl;
  final String statusFilter;
  final List<String> filterOptions;
  final String filterLabel;
  final bool hasRecords;
  final VoidCallback onLoad;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onStatusChanged;

  const _FilterBar({
    required this.search,
    required this.searchCtrl,
    required this.statusFilter,
    required this.filterOptions,
    required this.filterLabel,
    required this.hasRecords,
    required this.onLoad,
    required this.onSearchChanged,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.appSurface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: searchCtrl,
            style: TextStyle(fontSize: 13, color: context.appTextPrimary),
            decoration: InputDecoration(
              hintText: 'Search…',
              hintStyle:
                  TextStyle(color: context.appTextMuted, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded,
                  size: 16, color: context.appTextMuted),
              suffixIcon: search.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded,
                          size: 14, color: context.appTextSecondary),
                      onPressed: () {
                        searchCtrl.clear();
                        onSearchChanged('');
                      })
                  : null,
              isDense: true,
              filled: true,
              fillColor: context.appSurface2,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: context.appBorder)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: context.appBorder)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppDS.accent, width: 1.5)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            onChanged: onSearchChanged,
          ),
        ),
        if (filterLabel.isNotEmpty && filterOptions.isNotEmpty) ...[
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: statusFilter.isEmpty ? null : statusFilter,
              hint: Text(filterLabel,
                  style: TextStyle(
                      color: context.appTextMuted, fontSize: 12)),
              dropdownColor: context.appSurface2,
              style: TextStyle(
                  color: context.appTextPrimary, fontSize: 12),
              items: [
                DropdownMenuItem<String>(
                  value: '',
                  child: Text('All $filterLabel',
                      style: TextStyle(
                          color: context.appTextSecondary, fontSize: 12)),
                ),
                ...filterOptions.map((v) =>
                    DropdownMenuItem<String>(value: v, child: Text(v))),
              ],
              onChanged: onStatusChanged,
            ),
          ),
        ],
        const SizedBox(width: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              foregroundColor: AppDS.accent,
              side: const BorderSide(color: AppDS.accent),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
          icon: const Icon(Icons.refresh_rounded, size: 14),
          label: Text(hasRecords ? 'Reload' : 'Load',
              style: const TextStyle(fontSize: 12)),
          onPressed: onLoad,
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Record list — shows filtered records with select checkboxes
// ─────────────────────────────────────────────────────────────────────────────
class _RecordList extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final Set<dynamic> selectedIds;
  final String idCol;
  final int previewIndex;
  final void Function(Map<String, dynamic>) onToggle;
  final VoidCallback onToggleAll;
  final void Function(int) onTapRow;

  const _RecordList({
    required this.records,
    required this.selectedIds,
    required this.idCol,
    required this.previewIndex,
    required this.onToggle,
    required this.onToggleAll,
    required this.onTapRow,
  });

  String _recordLabel(Map<String, dynamic> r) {
    for (final k in [
      'strain_code', 'reagent_code', 'eq_code', 'sample_code',
      'fish_stocks_tank_id', 'code', 'name', 'id',
    ]) {
      final v = r[k];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return r.values.firstOrNull?.toString() ?? '—';
  }

  String _recordSubLabel(Map<String, dynamic> r) {
    for (final k in [
      'strain_species', 'reagent_name', 'eq_name', 'sample_type',
      'fish_stocks_line', 'name', 'type',
    ]) {
      final v = r[k];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = records.every((r) => selectedIds.contains(r[idCol]));
    final selCount = records.where((r) => selectedIds.contains(r[idCol])).length;
    return Column(children: [
      InkWell(
        onTap: onToggleAll,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          color: context.appSurface,
          child: Row(children: [
            Icon(
              allSelected
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 17,
              color: allSelected ? AppDS.accent : context.appTextSecondary,
            ),
            const SizedBox(width: 10),
            Text(allSelected ? 'Deselect all' : 'Select all',
                style: TextStyle(
                    fontSize: 12, color: context.appTextSecondary)),
            const Spacer(),
            Text('$selCount/${records.length}',
                style: TextStyle(
                    fontSize: 11, color: context.appTextSecondary)),
          ]),
        ),
      ),
      Divider(height: 1, color: context.appBorder),
      Expanded(
        child: ListView.builder(
          itemCount: records.length,
          itemBuilder: (ctx, i) {
            final r = records[i];
            final id = r[idCol];
            final isSel = selectedIds.contains(id);
            final isPreview = i == previewIndex;
            return InkWell(
              onTap: () => onTapRow(i),
              child: Container(
                color: isPreview
                    ? AppDS.accent.withValues(alpha: 0.08)
                    : Colors.transparent,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => onToggle(r),
                    child: Icon(
                      isSel
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 16,
                      color:
                          isSel ? AppDS.accent : ctx.appTextSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                        _recordLabel(r),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isPreview
                                ? AppDS.accent
                                : ctx.appTextPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_recordSubLabel(r).isNotEmpty)
                        Text(
                          _recordSubLabel(r),
                          style: TextStyle(
                              fontSize: 10, color: ctx.appTextSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ]),
                  ),
                  if (isPreview)
                    const Icon(Icons.visibility_rounded,
                        size: 13, color: AppDS.accent),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty records state
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyRecordsPanel extends StatelessWidget {
  final String entityType;
  final VoidCallback onLoad;
  const _EmptyRecordsPanel({required this.entityType, required this.onLoad});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.table_rows_outlined,
              size: 40, color: context.appTextSecondary),
          const SizedBox(height: 14),
          Text('No records loaded',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.appTextPrimary)),
          const SizedBox(height: 6),
          Text(
            'Load $entityType from the database to print with real data,\nor print now using sample placeholder values.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: context.appTextSecondary),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: AppDS.accent,
                side: const BorderSide(color: AppDS.accent)),
            icon: const Icon(Icons.download_rounded, size: 15),
            label: Text('Load all $entityType',
                style: const TextStyle(fontSize: 12)),
            onPressed: onLoad,
          ),
        ]),
      ),
    );
  }
}
