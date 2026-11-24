import 'package:flutter/material.dart';

const sampleUniversityNames = [
  'Universiti Teknologi Malaysia',
  'Universiti Malaya',
  'Universiti Putra Malaysia',
  'Universiti Kebangsaan Malaysia',
  'Universiti Sains Malaysia',
  'Universiti Teknologi MARA',
];

class AdminUniversitiesPage extends StatefulWidget {
  const AdminUniversitiesPage({super.key, required this.universities});
  final ValueNotifier<List<String>> universities;

  @override
  State<AdminUniversitiesPage> createState() => _AdminUniversitiesPageState();
}

class _AdminUniversitiesPageState extends State<AdminUniversitiesPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) =>
          _AddUniversityDialog(existingNames: widget.universities.value),
    );
    if (!mounted || name == null) return;
    widget.universities.value = [...widget.universities.value, name];
    _search.clear();
    setState(() => _query = '');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$name added to the preview list.')));
  }

  Future<void> _remove(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove university?'),
        scrollable: true,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
            ),
            const SizedBox(height: 12),
            const Text('Remove this university from the preview list?'),
            const SizedBox(height: 12),
            const Text(
              'This is an interface preview. Real university records and existing accounts will not change.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Color(0xFF596451),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm-remove-university'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFA3342D),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    widget.universities.value = widget.universities.value
        .where((item) => item != name)
        .toList();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name removed from the preview list.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (!mounted) return;
            if (!widget.universities.value.contains(name)) {
              widget.universities.value = [...widget.universities.value, name];
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<List<String>>(
    valueListenable: widget.universities,
    builder: (context, universities, _) {
      final visible =
          universities
              .where(
                (name) =>
                    name.toLowerCase().contains(_query.trim().toLowerCase()),
              )
              .toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Universities',
                      style: TextStyle(
                        fontSize: 25,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF253729),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${universities.length} ${universities.length == 1 ? 'university' : 'universities'} in the preview list',
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: Color(0xFF596451),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Tooltip(
                message: 'Add university',
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: FilledButton(
                    key: const ValueKey('add-university'),
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: const Color(0xFFFFD85C),
                      foregroundColor: const Color(0xFF253729),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _add,
                    child: const Icon(
                      Icons.add,
                      size: 28,
                      semanticLabel: 'Add university',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            key: const ValueKey('university-search'),
            controller: _search,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Search universities',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close),
                    ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFCBD2BE)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (visible.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFCBD2BE)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.school_outlined,
                    size: 40,
                    color: Color(0xFF596451),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    universities.isEmpty
                        ? 'No universities added yet'
                        : 'No universities match your search',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 17, height: 1.4),
                  ),
                ],
              ),
            ),
          for (final university in visible)
            Container(
              key: ValueKey('university-$university'),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.fromLTRB(16, 16, 10, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFCBD2BE)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF1E4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.school_outlined,
                      size: 24,
                      color: Color(0xFF344B35),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      university,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF253729),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    key: ValueKey('remove-university-$university'),
                    tooltip: 'Remove $university',
                    onPressed: () => _remove(university),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFA3342D),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            'Interface preview · Changes are kept only while this dashboard is open.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Color(0xFF596451),
            ),
          ),
        ],
      );
    },
  );
}

class _AddUniversityDialog extends StatefulWidget {
  const _AddUniversityDialog({required this.existingNames});
  final List<String> existingNames;
  @override
  State<_AddUniversityDialog> createState() => _AddUniversityDialogState();
}

class _AddUniversityDialogState extends State<_AddUniversityDialog> {
  final _form = GlobalKey<FormState>();
  String _name = '';
  String _normalize(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');
  void _submit() {
    if (_form.currentState!.validate()) {
      Navigator.pop(context, _normalize(_name));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add university'),
    scrollable: true,
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const ValueKey('university-name'),
            autofocus: true,
            maxLength: 120,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            onChanged: (value) => _name = value,
            decoration: const InputDecoration(
              labelText: 'University name',
              hintText: 'Enter the full university name',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              final name = _normalize(value ?? '');
              if (name.length < 3) {
                return 'Enter a university name with at least 3 characters.';
              }
              if (widget.existingNames.any(
                (item) => _normalize(item).toLowerCase() == name.toLowerCase(),
              )) {
                return 'This university is already in the list.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          const Text(
            'Adds to the preview list only.',
            style: TextStyle(fontSize: 13, color: Color(0xFF596451)),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('confirm-add-university'),
        onPressed: _submit,
        child: const Text('Add'),
      ),
    ],
  );
}
