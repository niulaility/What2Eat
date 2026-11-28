import 'dart:math' as math;

import 'package:flutter/material.dart';

class RegistrationSuccessPage extends StatelessWidget {
  const RegistrationSuccessPage({
    super.key,
    this.emailConfirmationRequired = false,
    this.email,
  });

  final bool emailConfirmationRequired;
  final String? email;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF5CC), Color(0xFFFFFCF5), Color(0xFFEEF4E6)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 432),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: reducedMotion ? 1 : 0, end: 1),
                  duration: Duration(milliseconds: reducedMotion ? 0 : 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, progress, child) => Opacity(
                    opacity: progress,
                    child: Transform.translate(
                      offset: Offset(0, 24 * (1 - progress)),
                      child: child,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 244,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Positioned.fill(
                              child: ExcludeSemantics(
                                child: CustomPaint(
                                  painter: _CelebrationPainter(),
                                ),
                              ),
                            ),
                            TweenAnimationBuilder<double>(
                              tween: Tween(
                                begin: reducedMotion ? 1 : .65,
                                end: 1,
                              ),
                              duration: Duration(
                                milliseconds: reducedMotion ? 0 : 1100,
                              ),
                              curve: Curves.elasticOut,
                              builder: (context, scale, child) =>
                                  Transform.scale(scale: scale, child: child),
                              child: Container(
                                width: 156,
                                height: 156,
                                padding: const EdgeInsets.all(13),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFFFE99A),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 5,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x22788B45),
                                      blurRadius: 36,
                                      offset: Offset(0, 14),
                                    ),
                                  ],
                                ),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF668A4C),
                                        Color(0xFF344F36),
                                      ],
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    size: 78,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        emailConfirmationRequired
                            ? 'Check your email'
                            : 'Registration is successful',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          height: 1.2,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.8,
                          color: Color(0xFF253729),
                        ),
                      ),
                      if (emailConfirmationRequired) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Tap the confirmation link sent to ${email ?? 'your email address'}, then sign in to continue.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF74796C),
                            height: 1.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 40),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33E5B628),
                              blurRadius: 20,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD85C),
                            foregroundColor: const Color(0xFF253729),
                            minimumSize: const Size.fromHeight(60),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: () => Navigator.of(context)
                              .popUntil((route) => route.isFirst),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Proceed',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(width: 12),
                              Icon(Icons.arrow_forward_rounded, size: 21),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CelebrationPainter extends CustomPainter {
  const _CelebrationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const colors = [
      Color(0xFFE8B735),
      Color(0xFF7E9C61),
      Color(0xFFED997C),
      Color(0xFFC7D8A8),
    ];
    for (var i = 0; i < 18; i++) {
      final angle = i * math.pi * 2 / 18;
      final radius = 100.0 + (i % 3) * 10;
      final position = center +
          Offset(math.cos(angle) * radius, math.sin(angle) * radius * .88);
      final paint = Paint()..color = colors[i % colors.length];
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(angle + .4);
      if (i % 3 == 0) {
        canvas.drawCircle(Offset.zero, 3.5, paint);
      } else if (i % 3 == 1) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-3, -6, 6, 12),
            const Radius.circular(2),
          ),
          paint,
        );
      } else {
        final star = Path()
          ..moveTo(0, -7)
          ..lineTo(2, -2)
          ..lineTo(7, 0)
          ..lineTo(2, 2)
          ..lineTo(0, 7)
          ..lineTo(-2, 2)
          ..lineTo(-7, 0)
          ..lineTo(-2, -2)
          ..close();
        canvas.drawPath(star, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CelebrationPainter oldDelegate) => false;
}
