import 'package:supabase_flutter/supabase_flutter.dart';

import '../profile/user_profile.dart';

/// Loads the active universities from `public.universities`.
/// Readable before sign-in: the table's SELECT policy allows active rows for
/// every role.
typedef UniversityLoader = Future<List<UniversityChoice>> Function();

/// Code of the "Other university" directory row (migration 20261127000030).
const otherUniversityCode = 'other';

/// Orders by name, with "Other university" last.
List<UniversityChoice> sortUniversityChoices(List<UniversityChoice> choices) =>
    [...choices]..sort((a, b) {
      final aOther = a.code == otherUniversityCode;
      final bOther = b.code == otherUniversityCode;
      if (aOther != bOther) return aOther ? 1 : -1;
      return a.name.compareTo(b.name);
    });

Future<List<UniversityChoice>> loadActiveUniversities() async {
  final rows = await Supabase.instance.client
      .from('universities')
      .select('id, code, name')
      .eq('is_active', true)
      .order('name');
  return sortUniversityChoices(
    rows
        .map(
          (row) => UniversityChoice(
            row['id'] as String,
            row['name'] as String,
            row['code'] as String? ?? '',
          ),
        )
        .toList(),
  );
}
