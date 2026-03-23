// label_print_dialog.dart - Part of label_page.dart.
// Print Dialog: batch record selection, live label preview, ZPL/QL dispatch.
// Widgets: _PrintDialog, _RecordList, _EmptyRecordsPanel.

part of 'label_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Print Dialog — batch select, preview, real ZPL/TCP printing
// ─────────────────────────────────────────────────────────────────────────────
class _PrintDialog extends StatefulWidget {
  final LabelTemplate template;
  final PrinterConfig printer;
  final List<Map<String, dynamic>> initialRecords;
  final String entityType;

  const _PrintDialog({
    required this.template,
    required this.printer,
    this.initialRecords = const [],
    this.entityType = 'General',
  });

  @override
  State<_PrintDialog> createState() => _PrintDialogState();
}

class _PrintDialogState extends State<_PrintDialog> {
  List<Map<String, dynamic>> _records = [];
  late List<bool> _selected;
  int _previewIndex = 0;
  bool _loading = false;
  bool _isPrinting = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _records = List.from(widget.initialRecords);
    _selected = List.filled(_records.length, true);
  }

  List<Map<String, dynamic>> get _selectedRecords =>
      [for (int i = 0; i < _records.length; i++) if (_selected[i]) _records[i]];

  int get _totalLabels =>
      (_selectedRecords.isEmpty ? 1 : _selectedRecords.length) *
      widget.template.copies;

  Map<String, dynamic> get _previewData {
    if (_records.isEmpty) return _sampleDataFor(widget.entityType);
    return _records[_previewIndex.clamp(0, _records.length - 1)];
  }

  Future<void> _loadFromDb() async {
    setState(() { _loading = true; _status = null; });
    try {
      final rows = await Supabase.instance.client
          .from(_tableForEntity(widget.entityType))
          .select() as List<dynamic>;
      final records = rows.cast<Map<String, dynamic>>();
      _injectQr(records, widget.entityType);
      setState(() {
        _records = records;
        _selected = List.filled(_records.length, true);
        _previewIndex = 0;
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; _status = 'Failed to load: $e'; });
    }
  }

  Future<void> _doPrint() async {
    if (_isPrinting) return;
    final proto = widget.printer.protocol == 'brother_ql' ? 'Brother QL' : 'ZPL';
    setState(() { _isPrinting = true; _status = 'Generating $proto data…'; });
    try {
      final batch =
          _selectedRecords.isEmpty ? <Map<String, dynamic>>[] : _selectedRecords;
      setState(() => _status = 'Connecting to ${widget.printer.ipAddress}…');
      await _sendToPrinter(widget.template, batch, widget.printer);
      final n = _totalLabels;
      setState(() {
        _isPrinting = false;
        _status = 'Sent $n label${n != 1 ? 's' : ''} to printer ✓';
      });
    } catch (e) {
      setState(() { _isPrinting = false; _status = 'Error: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasRecords = _records.isNotEmpty;
    final isError = _status != null && _status!.startsWith('Error');
    final isDone  = _status != null && _status!.contains('✓');

    return Dialog(
      backgroundColor: context.appSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 560),
        child: Column(children: [
          // ── Header ──────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            child: Row(children: [
              const Icon(Icons.print_rounded, size: 18, color: AppDS.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.template.name,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.appTextPrimary)),
                  Text(
                    '${widget.template.labelW.toInt()}×${widget.template.labelH.toInt()} mm · ${widget.entityType}',
                    style:
                        TextStyle(fontSize: 11, color: context.appTextSecondary),
                  ),
                ]),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 18, color: context.appTextSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          Divider(height: 1, color: context.appBorder),

          // ── Body ────────────────────────────────────────────────────────────
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Left: label preview + record navigation
              Container(
                width: 220,
                color: const Color(0xFF0A0F1A),
                child: Column(children: [
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
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
                            Text('Sample preview',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: context.appTextSecondary)),
                          ],
                        ]),
                      ),
                    ),
                  ),
                  if (hasRecords)
                    Container(
                      color: context.appSurface,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      child: Row(children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded, size: 18),
                          color: context.appTextSecondary,
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: _previewIndex > 0
                              ? () => setState(() => _previewIndex--)
                              : null,
                        ),
                        Expanded(
                          child: Text(
                            '${_previewIndex + 1} / ${_records.length}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 11,
                                color: context.appTextSecondary),
                          ),
                        ),
                        IconButton(
                          icon:
                              const Icon(Icons.chevron_right_rounded, size: 18),
                          color: context.appTextSecondary,
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: _previewIndex < _records.length - 1
                              ? () => setState(() => _previewIndex++)
                              : null,
                        ),
                      ]),
                    ),
                ]),
              ),
              VerticalDivider(width: 1, color: context.appBorder),

              // Right: record list or empty state
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppDS.accent, strokeWidth: 2))
                    : hasRecords
                        ? _RecordList(
                            records: _records,
                            selected: _selected,
                            previewIndex: _previewIndex,
                            onToggle: (i) =>
                                setState(() => _selected[i] = !_selected[i]),
                            onToggleAll: () => setState(() {
                              final allOn = _selected.every((s) => s);
                              for (int i = 0; i < _selected.length; i++) {
                                _selected[i] = !allOn;
                              }
                            }),
                            onTapRow: (i) =>
                                setState(() => _previewIndex = i),
                          )
                        : _EmptyRecordsPanel(
                            entityType: widget.entityType,
                            onLoad: _loadFromDb,
                          ),
              ),
            ]),
          ),
          Divider(height: 1, color: context.appBorder),

          // ── Footer ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(children: [
              Expanded(
                child: _status != null
                    ? Text(_status!,
                        style: TextStyle(
                          fontSize: 11,
                          color: isError
                              ? AppDS.red
                              : isDone
                                  ? AppDS.green
                                  : context.appTextSecondary,
                        ))
                    : Text(
                        hasRecords
                            ? '${_selectedRecords.length} of ${_records.length} records · $_totalLabels label${_totalLabels != 1 ? 's' : ''}'
                            : '1 label (sample data)',
                        style: TextStyle(
                            fontSize: 11, color: context.appTextSecondary),
                      ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close',
                    style: TextStyle(color: context.appTextSecondary)),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: AppDS.accent,
                    foregroundColor: AppDS.bg,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8)),
                icon: _isPrinting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            color: AppDS.bg, strokeWidth: 2))
                    : const Icon(Icons.print_rounded, size: 15),
                label: Text(
                    _isPrinting ? 'Printing…' : 'Print',
                    style: const TextStyle(fontSize: 13)),
                onPressed: _isPrinting ? null : _doPrint,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Record list — shows all DB records with select checkboxes
// ─────────────────────────────────────────────────────────────────────────────
class _RecordList extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final List<bool> selected;
  final int previewIndex;
  final void Function(int) onToggle;
  final VoidCallback onToggleAll;
  final void Function(int) onTapRow;

  const _RecordList({
    required this.records,
    required this.selected,
    required this.previewIndex,
    required this.onToggle,
    required this.onToggleAll,
    required this.onTapRow,
  });

  String _recordLabel(Map<String, dynamic> r) {
    for (final k in [
      'strain_code', 'reagent_code', 'eq_code', 'sample_code', 'code', 'name', 'id'
    ]) {
      if (r[k] != null) return r[k].toString();
    }
    return r.values.firstOrNull?.toString() ?? '—';
  }

  String _recordSubLabel(Map<String, dynamic> r) {
    for (final k in [
      'strain_species', 'reagent_name', 'eq_name', 'sample_type', 'name', 'type'
    ]) {
      if (r[k] != null) return r[k].toString();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = selected.every((s) => s);
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
              color:
                  allSelected ? AppDS.accent : context.appTextSecondary,
            ),
            const SizedBox(width: 10),
            Text(allSelected ? 'Deselect all' : 'Select all',
                style:
                    TextStyle(fontSize: 12, color: context.appTextSecondary)),
            const Spacer(),
            Text('${selected.where((s) => s).length}/${records.length}',
                style:
                    TextStyle(fontSize: 11, color: context.appTextSecondary)),
          ]),
        ),
      ),
      Divider(height: 1, color: context.appBorder),
      Expanded(
        child: ListView.builder(
          itemCount: records.length,
          itemBuilder: (ctx, i) {
            final isPreview = i == previewIndex;
            return InkWell(
              onTap: () => onTapRow(i),
              child: Container(
                color: isPreview
                    ? AppDS.accent.withValues(alpha: 0.08)
                    : Colors.transparent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => onToggle(i),
                    child: Icon(
                      selected[i]
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 16,
                      color: selected[i]
                          ? AppDS.accent
                          : context.appTextSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                        _recordLabel(records[i]),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isPreview
                                ? AppDS.accent
                                : ctx.appTextPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_recordSubLabel(records[i]).isNotEmpty)
                        Text(
                          _recordSubLabel(records[i]),
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
            style:
                TextStyle(fontSize: 11, color: context.appTextSecondary),
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
