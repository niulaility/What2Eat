import 'package:flutter/material.dart';

/// Frontend preview of the status shown after a vendor application is submitted.
class VendorApplicationPendingPage extends StatelessWidget {
  const VendorApplicationPendingPage({super.key, this.receiptEmailSent});

  final bool? receiptEmailSent;

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
                        radius: 52,
                        backgroundColor: Color(0xFFE5F2D9),
                        child: Icon(
                          Icons.check_rounded,
                          size: 56,
                          color: Color(0xFF397447),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Registration submitted successfully!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF253729),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3C4),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.hourglass_top_rounded,
                                size: 18, color: Color(0xFF765D12)),
                            SizedBox(width: 8),
                            Text(
                              'Awaiting admin approval',
                              style: TextStyle(
                                color: Color(0xFF765D12),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Your vendor application and documents have been sent to our admin team for review. We’ll email you when a decision is made. You can sign in after your application is approved.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, height: 1.5),
                    ),
                    if (receiptEmailSent == false) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1E8),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE9B49A)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Color(0xFF984B27)),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Your application is saved, but we could not send the receipt email. Please contact What2Eat support; the email service needs configuration.',
                                style: TextStyle(height: 1.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                            title: 'After approval',
                            text:
                                'We’ll email you to confirm your account is ready. You can then sign in to the vendor dashboard.',
                          ),
                          SizedBox(height: 22),
                          _StatusInfo(
                            icon: Icons.mail_outline,
                            title: 'If rejected',
                            text:
                                'You will not be able to sign in as a vendor. Contact the team if you need to submit a corrected application.',
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
                      onPressed: () => Navigator.of(context)
                          .popUntil((route) => route.isFirst),
                      child: const Text(
                        'Back to sign in',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
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
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15),
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
