import '../core/models.dart';

enum DashboardSessionFilter { all, unread, active }
enum DashboardSessionSort { recent, title }

List<SessionInfo> buildVisibleDashboardSessions({
  required List<SessionInfo> source,
  required Set<String> unreadKeys,
  required DashboardSessionFilter filter,
  required DashboardSessionSort sort,
  String query = '',
  DateTime? now,
}) {
  final String normalizedQuery = query.trim().toLowerCase();
  final List<SessionInfo> filtered = source.where((SessionInfo session) {
    if (filter == DashboardSessionFilter.unread &&
        !unreadKeys.contains(session.key)) {
      return false;
    }
    if (filter == DashboardSessionFilter.active &&
        !looksLikeActiveSession(session, unreadKeys, now: now)) {
      return false;
    }
    if (normalizedQuery.isEmpty) {
      return true;
    }
    return session.title.toLowerCase().contains(normalizedQuery) ||
        session.key.toLowerCase().contains(normalizedQuery) ||
        session.state.toLowerCase().contains(normalizedQuery);
  }).toList();

  filtered.sort((SessionInfo a, SessionInfo b) {
    if (sort == DashboardSessionSort.title) {
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    }
    final int aRank = sessionRecencyRank(a, now: now);
    final int bRank = sessionRecencyRank(b, now: now);
    if (aRank != bRank) {
      return aRank.compareTo(bRank);
    }
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });

  return filtered;
}

bool looksLikeActiveSession(
  SessionInfo session,
  Set<String> unreadKeys, {
  DateTime? now,
}) {
  final String state = session.state.trim().toLowerCase();
  if (state.contains('running') ||
      state.contains('active') ||
      state.contains('live') ||
      state.contains('stream')) {
    return true;
  }
  if (unreadKeys.contains(session.key)) {
    return true;
  }
  return sessionRecencyRank(session, now: now) <= 60;
}

int sessionRecencyRank(SessionInfo session, {DateTime? now}) {
  final int? updatedAtMs = session.updatedAtMs;
  if (updatedAtMs != null && updatedAtMs > 0) {
    final int nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final int deltaMs = nowMs - updatedAtMs;
    if (deltaMs <= 0) {
      return 0;
    }
    return Duration(milliseconds: deltaMs).inMinutes;
  }
  return updatedAgoRank(session.updatedAgo);
}

int updatedAgoRank(String value) {
  final String normalized = value.trim().toLowerCase();
  final String sanitized = normalized
      .replaceFirst(RegExp(r'^updated\s+'), '')
      .replaceFirst(RegExp(r'^last\s+updated\s+'), '');
  if (sanitized == 'just now') {
    return 0;
  }

  final RegExpMatch? compactMatch =
      RegExp(r'(\d+)\s*([mhd])\s*ago').firstMatch(sanitized);
  if (compactMatch != null) {
    final int amount = int.parse(compactMatch.group(1)!);
    return switch (compactMatch.group(2)) {
      'm' => amount,
      'h' => amount * 60,
      'd' => amount * 60 * 24,
      _ => 1 << 20,
    };
  }

  final RegExpMatch? longMatch = RegExp(
    r'(\d+)\s+(minute|minutes|hour|hours|day|days)\s+ago',
  ).firstMatch(sanitized);
  if (longMatch != null) {
    final int amount = int.parse(longMatch.group(1)!);
    return switch (longMatch.group(2)) {
      'minute' || 'minutes' => amount,
      'hour' || 'hours' => amount * 60,
      'day' || 'days' => amount * 60 * 24,
      _ => 1 << 20,
    };
  }

  return 1 << 20;
}
