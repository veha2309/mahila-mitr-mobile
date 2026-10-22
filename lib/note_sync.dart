import 'package:supabase_flutter/supabase_flutter.dart';

/// Notes are immutable and only their recipient may SELECT them. An upsert
/// with a conflict target also checks SELECT RLS, so the sender must INSERT
/// without RETURNING instead. The outbox keeps the same UUID across retries.
Future<void> insertPendingNote(
    SupabaseClient api, Map<String, dynamic> row) async {
  try {
    await api.from('notes').insert(row).timeout(const Duration(seconds: 15));
  } on PostgrestException catch (error) {
    // A previous attempt may have committed before its response was lost.
    // Only the notes primary-key conflict acknowledges that exact queued UUID.
    if (row['id'] == null ||
        error.code != '23505' ||
        !error.message.contains('"notes_pkey"')) {
      rethrow;
    }
  }
}
