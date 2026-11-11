import 'package:flutter/material.dart';

/// Frontend preview of the status shown after a vendor application is submitted.
class VendorApplicationPendingPage extends StatelessWidget {
  const VendorApplicationPendingPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 432),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: Color(0xFFFFEDAA),
                    child: Icon(
                      Icons.hourglass_top_rounded,
                      size: 48,
                      color: Color(0xFF344B35),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Your application is being processed',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF253729),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Our admin team will review your application and documents.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.5),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE0E4D9)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatusInfo(
                        icon: Icons.mark_email_read_outlined,
                        title: 'If approved',
                        text: 'You’ll receive an email. Complete the verification in that email to activate your account and sign in.',
                      ),
                      SizedBox(height: 22),
                      _StatusInfo(
                        icon: Icons.mail_outline,
                        title: 'If rejected',
                        text: 'You’ll also receive an email informing you of the decision.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD85C),
                    foregroundColor: const Color(0xFF253729),
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  child: const Text(
                    'Back to sign in',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _StatusInfo extends StatelessWidget {
  const _StatusInfo({
    required this.icon,
    required this.title,
    required this.text,
  });
  final IconData icon;
  final String title;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: const Color(0xFF667A43)),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              text,
              style: const TextStyle(height: 1.5, color: Color(0xFF596451)),
            ),
          ],
        ),
      ),
    ],
  );
}
