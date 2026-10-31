import 'package:supabase_flutter/supabase_flutter.dart';

/// The user-facing message of a failed Edge Function call.
///
/// `functions.invoke` throws [FunctionException] for any non-2xx answer (it
/// never returns one), with the function's JSON body in `details`. Our
/// functions put the Arabic message in `error`; [fallback] covers network
/// failures and bodies without one.
String functionErrorMessage(Object error, {required String fallback}) {
  if (error is FunctionException) {
    final details = error.details;
    if (details is Map && details['error'] is String && (details['error'] as String).trim().isNotEmpty) {
      return details['error'] as String;
    }
  }
  return fallback;
}

/// The `code` field of a failed call (e.g. `ad_limit_reached`), if any.
String? functionErrorCode(Object error) {
  if (error is FunctionException && error.details is Map) {
    final code = (error.details as Map)['code'];
    return code is String ? code : null;
  }
  return null;
}
