import 'package:flutter/material.dart';

import 'vendor_application_repository.dart';

const _ink = Color(0xFF253729);
const _green = Color(0xFF344B35);
const _cream = Color(0xFFFFFCF5);
const _line = Color(0xFFCBD2BE);

/// Vendor logo from its public URL, with a storefront icon when absent or
/// unreadable.
class ApplicationLogo extends StatelessWidget {
  const ApplicationLogo({super.key, required this.url, this.size = 48});
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFEEF1E4),
        borderRadius: BorderRadius.circular(size * .28),
      ),
      child: Icon(Icons.storefront_outlined, color: _green, size: size * .55),
    );
    if (url == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .28),
      child: Image.network(
        url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class VendorApplicationDetailsPage extends StatelessWidget {
  const VendorApplicationDetailsPage({
    super.key,
    required this.application,
    required this.repository,
  });
  final VendorApplication application;
  final VendorApplicationRepository repository;

  /// Opens the decision dialog. When the decision is saved, closes this page
  /// and returns the confirmation message to the dashboard.
  Future<void> _decide(BuildContext context, bool approve) async {
    final missing = vendorDocumentTypes
        .where((t) => !t.optional && application.documentsOf(t.type).isEmpty)
        .map((t) => t.title)
        .toList();
    final message = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DecisionDialog(
        approve: approve,
        application: application,
        repository: repository,
        missingRequired: missing,
      ),
    );
    if (message != null && context.mounted) {
      Navigator.of(context).pop(message);
    }
  }

  Future<void> _document(
    BuildContext context,
    String title,
    List<VendorApplicationDocument> files,
  ) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < files.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DocumentImage(
                key: ValueKey('document-file-$i'),
                loadUrl: () => repository.documentUrl(files[i].path),
                label: files.length == 1
                    ? title
                    : '$title (${i + 1} of ${files.length})',
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _cream,
    appBar: AppBar(
      title: const Text(
        'Application details',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _ink,
        ),
      ),
      backgroundColor: _cream,
      surfaceTintColor: Colors.transparent,
    ),
    body: SingleChildScrollView(
      key: const ValueKey('application-details-scroll'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Section(
                title: application.businessName,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ApplicationLogo(
                        url: application.logoUrl,
                        size: 88,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      application.reference,
                      style: const TextStyle(fontSize: 14, color: _green),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Submitted ${formatApplicationDate(application.submittedAt)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    if (application.reviewedAt != null &&
                        application.status !=
                            ApplicationReviewStatus.pending) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Reviewed ${formatApplicationDate(application.reviewedAt!)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Status · ${application.statusLabel}',
                      key: const ValueKey('application-status'),
                      style: const TextStyle(
                        fontSize: 14,
                        color: _green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (application.rejectionReason != null)
                _Section(
                  title: 'Reason for rejection',
                  child: Text(
                    application.rejectionReason!,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      color: _ink,
                    ),
                  ),
                ),
              _Section(
                title: 'Applicant information',
                child: Column(
                  children: [
                    _Field('Full name', application.owner),
                    _Field('Username', application.username),
                    _Field('Email address', application.email),
                    _Field('Phone number', application.phone),
                  ],
                ),
              ),
              _Section(
                title: 'Business details',
                child: Column(
                  children: [
                    _Field('Business name', application.businessName),
                    _Field('Description', application.description),
                    _Field(
                      'Business contact number',
                      application.businessPhone,
                    ),
                    _Field('Business address', application.address),
                  ],
                ),
              ),
              _Section(
                title: 'Universities served',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (application.universities.isEmpty)
                      const Text(
                        'No universities selected.',
                        style: TextStyle(fontSize: 16, color: _green),
                      ),
                    for (final campus in application.universities)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          campus,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.4,
                            color: _ink,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _Section(
                title: 'Submitted documents',
                child: Column(
                  children: [
                    for (final type in vendorDocumentTypes)
                      _documentTile(context, type),
                  ],
                ),
              ),
              const Text(
                'The applicant accepted the vendor registration agreement.',
                style: TextStyle(fontSize: 14, height: 1.4, color: _green),
              ),
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: application.status != ApplicationReviewStatus.pending
        ? null
        : Material(
            color: _cream,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            key: const ValueKey('reject-application'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              foregroundColor: const Color(0xFFAC3530),
                              side: const BorderSide(color: Color(0xFFAC3530)),
                            ),
                            onPressed: () => _decide(context, false),
                            child: const Text(
                              'Reject',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            key: const ValueKey('approve-application'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              backgroundColor: const Color(0xFFFFD85C),
                              foregroundColor: _ink,
                            ),
                            onPressed: () => _decide(context, true),
                            child: const Text(
                              'Approve',
                              style: TextStyle(fontSize: 16),
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
  );

  Widget _documentTile(BuildContext context, VendorDocumentType type) {
    final files = application.documentsOf(type.type);
    final requirement = type.optional ? 'Optional' : 'Required';
    return ListTile(
      key: ValueKey('document-${type.type}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        files.isEmpty
            ? (type.optional
                  ? Icons.remove_circle_outline
                  : Icons.error_outline)
            : Icons.description_outlined,
        color: files.isEmpty
            ? (type.optional
                  ? const Color(0xFF92978B)
                  : const Color(0xFFAC3530))
            : _green,
      ),
      title: Text(
        type.title,
        style: const TextStyle(fontSize: 16, height: 1.4),
      ),
      subtitle: Text(
        files.isEmpty
            ? 'Not provided · $requirement'
            : '${files.length} ${files.length == 1 ? 'file' : 'files'} · $requirement',
      ),
      trailing: files.isEmpty ? null : const Icon(Icons.chevron_right),
      onTap: files.isEmpty ? null : () => _document(context, type.title, files),
    );
  }
}

/// Requests a signed URL, then shows the image with loading and error states.
class _DocumentImage extends StatefulWidget {
  const _DocumentImage({super.key, required this.loadUrl, required this.label});
  final Future<String> Function() loadUrl;
  final String label;
  @override
  State<_DocumentImage> createState() => _DocumentImageState();
}

class _DocumentImageState extends State<_DocumentImage> {
  late Future<String> _url = widget.loadUrl();

  Widget _placeholder(Widget child) => Container(
    width: double.infinity,
    height: 220,
    alignment: Alignment.center,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFEEF1E4),
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );

  Widget _failed() => _placeholder(
    Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.broken_image_outlined, size: 40, color: _green),
        const SizedBox(height: 8),
        const Text('Could not load this file.', textAlign: TextAlign.center),
        TextButton(
          onPressed: () => setState(() {
            // FutureBuilder subscribes on the next frame; avoid an
            // unhandled-error report if the request fails first.
            _url = widget.loadUrl()..ignore();
          }),
          child: const Text('Retry'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: _url,
    builder: (context, snapshot) {
      if (snapshot.hasError) return _failed();
      if (!snapshot.hasData) {
        return _placeholder(const CircularProgressIndicator());
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.network(
            snapshot.data!,
            width: double.infinity,
            fit: BoxFit.contain,
            semanticLabel: widget.label,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : _placeholder(const CircularProgressIndicator()),
            errorBuilder: (_, _, _) => _failed(),
          ),
        ),
      );
    },
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              height: 1.35,
              color: _ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: _green)),
        const SizedBox(height: 6),
        SelectableText(
          value.isEmpty ? '—' : value,
          style: const TextStyle(fontSize: 16, height: 1.4, color: _ink),
        ),
      ],
    ),
  );
}

/// Confirms a decision, saves it, then emails the applicant. Pops with the
/// confirmation message once the decision is saved.
class _DecisionDialog extends StatefulWidget {
  const _DecisionDialog({
    required this.approve,
    required this.application,
    required this.repository,
    required this.missingRequired,
  });
  final bool approve;
  final VendorApplication application;
  final VendorApplicationRepository repository;
  final List<String> missingRequired;
  @override
  State<_DecisionDialog> createState() => _DecisionDialogState();
}

class _DecisionDialogState extends State<_DecisionDialog> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    final application = widget.application;
    try {
      await widget.repository.reviewApplication(
        application.id,
        approve: widget.approve,
        rejectionReason: widget.approve ? null : _reason.text,
      );
    } on VendorApplicationFailure catch (failure) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = failure.message;
        });
      }
      return;
    }
    // The decision is saved; a failed email must not undo or hide it.
    final emailed = await widget.repository.sendReviewNotice(application.id);
    if (!mounted) return;
    final decision = widget.approve ? 'approved' : 'rejected';
    Navigator.of(context).pop(
      emailed
          ? '${application.businessName} was $decision. The applicant was emailed.'
          : '${application.businessName} was $decision, but the email could not '
                'be sent. Please let the applicant know at ${application.email}.',
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(
        widget.approve ? 'Approve application?' : 'Reject application?',
      ),
      scrollable: true,
      content: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.application.businessName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              widget.approve
                  ? 'The vendor account will be activated, the business will be visible to students, and the applicant will be emailed.'
                  : 'The applicant will not be able to sign in and will be emailed this reason.',
            ),
            if (widget.approve && widget.missingRequired.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Missing required documents: ${widget.missingRequired.join(', ')}.',
                key: const ValueKey('missing-documents-warning'),
                style: const TextStyle(color: Color(0xFFAC3530)),
              ),
            ],
            if (!widget.approve) ...[
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('rejection-reason'),
                controller: _reason,
                enabled: !_saving,
                minLines: 3,
                maxLines: 5,
                maxLength: 500,
                // Clears the error as soon as a reason is typed.
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: const InputDecoration(
                  labelText: 'Reason for rejection',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                  errorMaxLines: 3,
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Enter a reason for the applicant.'
                    : null,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const ValueKey('decision-error'),
                style: const TextStyle(color: Color(0xFFAC3530)),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('confirm-decision'),
          onPressed: _saving ? null : _submit,
          style: widget.approve
              ? null
              : FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFAC3530),
                ),
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.approve ? 'Approve' : 'Reject'),
        ),
      ],
    ),
  );
}
