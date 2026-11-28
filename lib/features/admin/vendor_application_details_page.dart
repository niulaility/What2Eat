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

  Future<void> _previewDecision(BuildContext context, bool approve) =>
      showDialog<void>(
        context: context,
        builder: (_) => _DecisionPreview(
          approve: approve,
          business: application.businessName,
        ),
      );

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
                    const Text(
                      'Preview actions · Application stays pending',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: _green,
                      ),
                    ),
                    const SizedBox(height: 10),
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
                            onPressed: () => _previewDecision(context, false),
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
                            onPressed: () => _previewDecision(context, true),
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
                  ? Icons.file_present_outlined
                  : Icons.error_outline)
            : Icons.description_outlined,
        color: files.isEmpty && !type.optional
            ? const Color(0xFFAC3530)
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

class _DecisionPreview extends StatefulWidget {
  const _DecisionPreview({required this.approve, required this.business});
  final bool approve;
  final String business;
  @override
  State<_DecisionPreview> createState() => _DecisionPreviewState();
}

class _DecisionPreviewState extends State<_DecisionPreview> {
  final _form = GlobalKey<FormState>();
  @override
  Widget build(BuildContext context) => AlertDialog(
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
            widget.business,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const Text(
            'This is an interface preview. No status will change, no account will be activated, and no email will be sent.',
          ),
          if (!widget.approve) ...[
            const SizedBox(height: 16),
            TextFormField(
              minLines: 3,
              maxLines: 5,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Reason for rejection',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Enter a reason for the applicant.'
                  : null,
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Preview complete. The application is still pending.',
              ),
            ),
          );
        },
        child: const Text('Confirm preview'),
      ),
    ],
  );
}
