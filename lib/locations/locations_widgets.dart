// locations_widgets.dart - Part of locations_page.dart.
// _RoomCard: expandable card for a top-level room.
// _ChildTile: sub-location row inside a room card.
// _OrphanCard: card for locations with no parent.
// _Btn: small icon button utility.
// _LocationFormDialog: add/edit location form dialog.
// _DarkField, _DarkDropdown: dark-themed form field helpers.
part of 'locations_page.dart';

// ─── Room Card ──────────────────────────────────────────────────────────────────
class _RoomCard extends StatelessWidget {
  final LocationModel room;
  final List<LocationModel> children;
  final VoidCallback onDelete;
  final VoidCallback onQr;
  final VoidCallback onTap;
  final void Function(LocationModel) onDeleteChild;
  final void Function(LocationModel) onQrChild;
  final void Function(LocationModel) onTapChild;
  final VoidCallback onAddChild;

  const _RoomCard({
    required super.key,
    required this.room,
    required this.children,
    required this.onDelete,
    required this.onQr,
    required this.onTap,
    required this.onDeleteChild,
    required this.onQrChild,
    required this.onTapChild,
    required this.onAddChild,
  });

  static const _roomAccent = Color(0xFF6366F1);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildHeader(context),
        if (children.isNotEmpty) ...[
          Divider(height: 1, color: context.appBorder),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: children
                  .map((c) => _ChildTile(
                        loc: c,
                        onDelete: () => onDeleteChild(c),
                        onQr: () => onQrChild(c),
                        onTap: () => onTapChild(c),
                      ))
                  .toList(),
            ),
          ),
        ],
        _buildFooter(context),
      ]),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurface2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      child: Row(children: [
        // Room icon
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _roomAccent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.meeting_room_outlined,
              color: _roomAccent, size: 16),
        ),
        const SizedBox(width: 10),
        // Name + meta — tappable to open detail
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(room.name,
                    style: GoogleFonts.spaceGrotesk(
                        color: context.appTextPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                if (room.temperature != null || room.capacity != null)
                  Row(children: [
                    if (room.temperature != null) ...[
                      Icon(Icons.thermostat_outlined,
                          size: 11, color: context.appTextMuted),
                      const SizedBox(width: 2),
                      Text(room.temperature!,
                          style: GoogleFonts.spaceGrotesk(
                              color: context.appTextMuted, fontSize: 11)),
                      const SizedBox(width: 8),
                    ],
                    if (room.capacity != null) ...[
                      Icon(Icons.storage_outlined,
                          size: 11, color: context.appTextMuted),
                      const SizedBox(width: 2),
                      Text('Cap: ${room.capacity}',
                          style: GoogleFonts.spaceGrotesk(
                              color: context.appTextMuted, fontSize: 11)),
                    ],
                  ]),
              ],
            ),
          ),
        ),
        // Children count badge
        if (children.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: _roomAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('${children.length}',
                style: GoogleFonts.spaceGrotesk(
                    color: _roomAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 4),
        ],
        _Btn(Icons.qr_code, 'QR Code', onQr),
        _Btn(Icons.delete_outline, 'Delete', onDelete),
        const SizedBox(width: 4),
      ]),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onAddChild,
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(12)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: context.appBorder)),
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(12)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add, size: 13, color: context.appTextMuted),
            const SizedBox(width: 4),
            Text('Add location to room',
                style: GoogleFonts.spaceGrotesk(
                    color: context.appTextMuted, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}

// ─── Child Tile ─────────────────────────────────────────────────────────────────
class _ChildTile extends StatelessWidget {
  final LocationModel loc;
  final VoidCallback onDelete;
  final VoidCallback onQr;
  final VoidCallback onTap;

  const _ChildTile({
    required this.loc,
    required this.onDelete,
    required this.onQr,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = LocationModel.typeAccent(loc.type);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
          decoration: BoxDecoration(
            color: context.appSurface3,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.appBorder),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(LocationModel.typeIcon(loc.type), color: accent, size: 16),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(loc.name,
                    style: GoogleFonts.spaceGrotesk(
                        color: context.appTextPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                if (loc.temperature != null)
                  Text(loc.temperature!,
                      style: GoogleFonts.spaceGrotesk(
                          color: context.appTextMuted, fontSize: 11)),
              ],
            ),
            const SizedBox(width: 2),
            _Btn(Icons.qr_code, 'QR', onQr, size: 14),
            _Btn(Icons.delete_outline, 'Delete', onDelete, size: 14),
          ]),
        ),
      ),
    );
  }
}

// ─── Orphan Card ────────────────────────────────────────────────────────────────
class _OrphanCard extends StatelessWidget {
  final List<LocationModel> locations;
  final void Function(LocationModel) onDelete;
  final void Function(LocationModel) onQr;
  final void Function(LocationModel) onTap;
  final VoidCallback onAdd;

  const _OrphanCard({
    required super.key,
    required this.locations,
    required this.onDelete,
    required this.onQr,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          decoration: BoxDecoration(
            color: context.appSurface2,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Icon(Icons.inbox_outlined, color: context.appTextMuted, size: 16),
            const SizedBox(width: 8),
            Text('Unassigned',
                style: GoogleFonts.spaceGrotesk(
                    color: context.appTextSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(
                '${locations.length} location${locations.length == 1 ? '' : 's'} not in a room',
                style: GoogleFonts.spaceGrotesk(
                    color: context.appTextMuted, fontSize: 11)),
          ]),
        ),
        Divider(height: 1, color: context.appBorder),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: locations
                .map((l) => _ChildTile(
                      loc: l,
                      onDelete: () => onDelete(l),
                      onQr: () => onQr(l),
                      onTap: () => onTap(l),
                    ))
                .toList(),
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onAdd,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(12)),
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: context.appBorder)),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add, size: 13, color: context.appTextMuted),
                const SizedBox(width: 4),
                Text('Add unassigned location',
                    style: GoogleFonts.spaceGrotesk(
                        color: context.appTextMuted, fontSize: 12)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─── Small icon button ───────────────────────────────────────────────────────────
class _Btn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;

  const _Btn(this.icon, this.tooltip, this.onPressed, {this.size = 16});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: size, color: context.appTextSecondary),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(4),
      constraints:
          BoxConstraints(minWidth: size + 10, minHeight: size + 10),
    );
  }
}

// ─── Add/Edit Form Dialog ────────────────────────────────────────────────────────
class _LocationFormDialog extends StatefulWidget {
  final LocationModel? existing;
  final List<LocationModel> allLocations;
  final int? defaultParentId;
  final String defaultType;

  const _LocationFormDialog({
    this.existing,
    required this.allLocations,
    this.defaultParentId,
    this.defaultType = 'room',
  });

  @override
  State<_LocationFormDialog> createState() => _LocationFormDialogState();
}

class _LocationFormDialogState extends State<_LocationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _tempCtrl;
  late final TextEditingController _capCtrl;
  late final TextEditingController _notesCtrl;
  late String _type;
  late int? _parentId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _tempCtrl = TextEditingController(text: e?.temperature ?? '');
    _capCtrl = TextEditingController(
        text: e?.capacity != null ? e!.capacity.toString() : '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _type = e?.type ?? widget.defaultType;
    _parentId = e?.parentId ?? widget.defaultParentId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _tempCtrl.dispose();
    _capCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final data = {
        'location_name': _nameCtrl.text.trim(),
        'location_type': _type,
        if (_tempCtrl.text.isNotEmpty)
          'location_temperature': _tempCtrl.text.trim(),
        if (_capCtrl.text.isNotEmpty)
          'location_capacity': int.tryParse(_capCtrl.text.trim()),
        if (_parentId != null) 'location_parent_id': _parentId,
        if (_notesCtrl.text.isNotEmpty)
          'location_notes': _notesCtrl.text.trim(),
      };
      if (widget.existing != null) {
        await Supabase.instance.client
            .from('storage_locations')
            .update(data)
            .eq('location_id', widget.existing!.id);
      } else {
        await Supabase.instance.client
            .from('storage_locations')
            .insert(data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final parentChoices = widget.allLocations
        .where((l) => widget.existing == null || l.id != widget.existing!.id)
        .toList();

    return AlertDialog(
      backgroundColor: context.appSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(isEdit ? 'Edit Location' : 'Add Location',
          style: GoogleFonts.spaceGrotesk(
              color: context.appTextPrimary, fontWeight: FontWeight.w600)),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _DarkField(
                controller: _nameCtrl,
                label: 'Name *',
                validator: (v) =>
                    v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              _DarkDropdown<String>(
                label: 'Type',
                value: _type,
                items: LocationModel.typeOptions
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(LocationModel.typeLabel(t),
                              style: GoogleFonts.spaceGrotesk(
                                  color: context.appTextPrimary, fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _type = v ?? 'room'),
              ),
              const SizedBox(height: 12),
              _DarkField(
                  controller: _tempCtrl,
                  label: 'Temperature (e.g. -80°C)'),
              const SizedBox(height: 12),
              _DarkField(
                controller: _capCtrl,
                label: 'Capacity',
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v != null && v.isNotEmpty && int.tryParse(v) == null) {
                    return 'Must be a number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _DarkDropdown<int?>(
                label: 'Parent Room',
                value: _parentId,
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text('None',
                        style: GoogleFonts.spaceGrotesk(
                            color: context.appTextMuted, fontSize: 13)),
                  ),
                  ...parentChoices.map((l) => DropdownMenuItem<int?>(
                        value: l.id,
                        child: Text(l.name,
                            style: GoogleFonts.spaceGrotesk(
                                color: context.appTextPrimary, fontSize: 13)),
                      )),
                ],
                onChanged: (v) => setState(() => _parentId = v),
              ),
              const SizedBox(height: 12),
              _DarkField(
                  controller: _notesCtrl, label: 'Notes', maxLines: 2),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text('Cancel',
              style: GoogleFonts.spaceGrotesk(color: context.appTextSecondary)),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(isEdit ? 'Save' : 'Create',
                  style: GoogleFonts.spaceGrotesk()),
        ),
      ],
    );
  }
}

// ─── Shared dark form widgets ────────────────────────────────────────────────────
class _DarkField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _DarkField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style:
          GoogleFonts.spaceGrotesk(color: context.appTextPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.spaceGrotesk(
            color: context.appTextSecondary, fontSize: 12),
        filled: true,
        fillColor: context.appSurface3,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: context.appBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: context.appBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppDS.accent)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppDS.red)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

class _DarkDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;

  const _DarkDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.spaceGrotesk(
            color: context.appTextSecondary, fontSize: 12),
        filled: true,
        fillColor: context.appSurface3,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: context.appBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: context.appBorder)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: context.appSurface,
          style: GoogleFonts.spaceGrotesk(
              color: context.appTextPrimary, fontSize: 13),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
