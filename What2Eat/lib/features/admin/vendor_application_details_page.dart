import 'package:flutter/material.dart';

import 'vendor_application_preview_data.dart';

const _ink = Color(0xFF253729);
const _green = Color(0xFF344B35);
const _cream = Color(0xFFFFFCF5);
const _line = Color(0xFFCBD2BE);

class VendorApplicationDetailsPage extends StatelessWidget {
  const VendorApplicationDetailsPage({super.key, required this.application});
  final VendorApplicationPreview application;

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
    ApplicationDocumentPreview document,
  ) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(document.title),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < document.files; i++)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF1E4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.description_outlined,
                    size: 44,
                    color: _green,
                  ),
                  const SizedBox(height: 12),
                  Text('Sample document ${i + 1}', textAlign: TextAlign.center),
                ],
              ),
            ),
          const Text('No real document is loaded in this interface preview.'),
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
                      child: Image.asset(
                        application.logoAsset,
                        width: 88,
                        height: 88,
                        excludeFromSemantics: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      application.id,
                      style: const TextStyle(fontSize: 14, color: _green),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Submitted ${application.submitted}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sample application · ${application.statusLabel}',
                      style: const TextStyle(fontSize: 14, color: _green),
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
                    for (final campus in application.campuses)
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
                    for (final document in application.documents)
                      ListTile(
                        key: ValueKey('document-${document.id}'),
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          document.files == 0
                              ? Icons.file_present_outlined
                              : Icons.description_outlined,
                          color: _green,
                        ),
                        title: Text(
                          document.title,
                          style: const TextStyle(fontSize: 16, height: 1.4),
                        ),
                        subtitle: Text(
                          document.files == 0
                              ? 'Not provided · Optional'
                              : '${document.files} sample ${document.files == 1 ? 'file' : 'files'} · ${document.optional ? 'Optional' : 'Required'}',
                        ),
                        trailing: document.files == 0
                            ? null
                            : const Icon(Icons.chevron_right),
                        onTap: document.files == 0
                            ? null
                            : () => _document(context, document),
                      ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'The applicant accepted the vendor registration agreement.',
                  style: TextStyle(fontSize: 14, height: 1.4, color: _green),
                ),
              ),
              const Text(
                'Interface preview only. No real application or document is loaded.',
                style: TextStyle(fontSize: 12, height: 1.4, color: _green),
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
          value,
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
