import 'application_models.dart';

/// Days since you applied before a follow-up is suggested.
const followUpAfterDays = 5;

/// Most urgent first: a live interview matters more than something saved for later.
const _rank = {
  Stage.interview: 0,
  Stage.offer: 1,
  Stage.oa: 2,
  Stage.applied: 3,
  Stage.wishlist: 4,
  Stage.rejected: 5,
};

DateTime _day(DateTime t) {
  final l = t.toLocal();
  return DateTime(l.year, l.month, l.day);
}

/// Whole calendar days from [from] to [to], so 23:59 to 00:01 is one day, not zero.
int daysBetween(DateTime from, DateTime to) {
  final a = _day(from), b = _day(to);
  // Rebuild through UTC so a daylight-saving change cannot make a day 23 or 25 hours long.
  return DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
}

String agoLabel(DateTime t, DateTime now) {
  final d = daysBetween(t, now);
  if (d <= 0) return 'today';
  if (d == 1) return 'yesterday';
  if (d < 14) return '$d days ago';
  return '${(d / 7).round()} weeks ago';
}

String whenLabel(JobApplication a, DateTime now) {
  final verb = switch (a.stage) {
    Stage.wishlist => 'Saved',
    Stage.applied => 'Applied',
    Stage.oa => 'OA',
    Stage.interview => 'Interview',
    Stage.offer => 'Offer',
    Stage.rejected => 'Closed',
  };
  return '$verb ${agoLabel(a.stageChangedAt, now)}';
}

String companyInitial(String company) {
  final t = company.trim();
  return t.isEmpty ? '?' : t.substring(0, 1).toUpperCase();
}

JobApplication moveTo(JobApplication a, Stage stage, DateTime now) =>
    a.stage == stage ? a : a.copyWith(stage: stage, stageChangedAt: now);

Map<Stage, int> stageCounts(List<JobApplication> apps) =>
    {for (final s in Stage.values) s: apps.where((a) => a.stage == s).length};

/// Newest move first within a stage.
List<JobApplication> inStage(List<JobApplication> apps, Stage s) =>
    apps.where((a) => a.stage == s).toList()..sort((a, b) => b.stageChangedAt.compareTo(a.stageChangedAt));

List<JobApplication> byUrgency(List<JobApplication> apps) => [...apps]..sort((a, b) {
      final r = _rank[a.stage]!.compareTo(_rank[b.stage]!);
      return r != 0 ? r : b.stageChangedAt.compareTo(a.stageChangedAt);
    });

/// Applied for five days or more with no change, longest wait first.
List<JobApplication> followUps(List<JobApplication> apps, DateTime now) =>
    apps.where((a) => a.stage == Stage.applied && daysBetween(a.stageChangedAt, now) >= followUpAfterDays).toList()
      ..sort((a, b) => a.stageChangedAt.compareTo(b.stageChangedAt));

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9+#. ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

bool isDuplicate(List<JobApplication> apps, String company, String role) =>
    apps.any((a) => _norm(a.company) == _norm(company) && _norm(a.role) == _norm(role));

const maxSkills = 8;

/// Keeps only what the pasted text really contains: a company or skill the description never mentions is dropped
/// rather than shown as if it were read from it.
Autofill verifyAutofill(String jd, Autofill raw) {
  final text = _norm(jd);
  bool mentions(String s) {
    final n = _norm(s);
    return n.isNotEmpty && text.contains(n);
  }

  final company = mentions(raw.company) ? raw.company.trim() : '';

  final roleWords = _norm(raw.role).split(' ').where((w) => w.isNotEmpty).toList();
  final inText = roleWords.where((w) => text.contains(w)).length;
  final role = roleWords.isNotEmpty && inText / roleWords.length >= 0.6 ? raw.role.trim() : '';

  final seen = <String>{};
  final skills = <String>[];
  for (final s in raw.skills) {
    final t = s.trim();
    if (t.isEmpty || t.length > 30 || !mentions(t) || !seen.add(t.toLowerCase())) continue;
    skills.add(t);
    if (skills.length == maxSkills) break;
  }
  return Autofill(company: company, role: role, skills: skills);
}
