import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'profile_repository.dart';

Widget profileTheme(BuildContext context, WidgetBuilder builder) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF344B35),
    brightness: Brightness.light,
  );
  return Theme(
    data: ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFFFFCF5),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        errorMaxLines: 3,
        helperMaxLines: 3,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    ),
    child: Builder(builder: builder),
  );
}

class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    super.key,
    required this.repository,
    this.reference,
    this.preview,
    this.size = 104,
    this.removed = false,
  });
  final ProfileRepository repository;
  final String? reference;
  final Uint8List? preview;
  final double size;
  final bool removed;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  Future<Uint8List?>? _photo;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reference != widget.reference ||
        oldWidget.repository != widget.repository ||
        oldWidget.removed != widget.removed) {
      _load();
    }
  }

  void _load() {
    _photo = widget.removed || widget.reference == null
        ? null
        : widget.repository
              .readAvatar(widget.reference)
              .timeout(const Duration(seconds: 15));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget fallback() => Icon(
      Icons.person_rounded,
      size: widget.size * .55,
      color: colors.primary,
    );
    Widget picture(Uint8List? bytes) => bytes == null
        ? fallback()
        : Image.memory(
            bytes,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
            gaplessPlayback: false,
            errorBuilder: (_, _, _) => fallback(),
          );
    return Semantics(
      label:
          widget.removed || (widget.preview == null && widget.reference == null)
          ? 'Default profile picture'
          : 'Personal profile picture',
      image: true,
      child: Container(
        width: widget.size,
        height: widget.size,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.surface,
          border: Border.all(color: colors.outlineVariant),
        ),
        child: ClipOval(
          child: ColoredBox(
            color: colors.primaryContainer,
            child: widget.removed
                ? fallback()
                : widget.preview != null
                ? picture(widget.preview)
                : FutureBuilder<Uint8List?>(
                    future: _photo,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.primary,
                            ),
                          ),
                        );
                      }
                      return Tooltip(
                        message: snapshot.hasError
                            ? 'Photo unavailable. Refresh to retry.'
                            : 'Personal profile photo',
                        child: picture(snapshot.data),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

class ProfileSection extends StatelessWidget {
  const ProfileSection({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 20),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: Theme.of(context).colorScheme.outlineVariant
            .withValues(alpha: .65),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 20),
        ...children,
      ],
    ),
  );
}
