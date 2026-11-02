import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A role and company handed to the interview setup from another screen, such as an application in the tracker.
/// The setup reads it once and clears it.
class InterviewPrefill extends Notifier<({String role, String company})?> {
  @override
  ({String role, String company})? build() => null;

  void set({required String role, required String company}) => state = (role: role, company: company);
  void clear() => state = null;
}

final interviewPrefillProvider = NotifierProvider<InterviewPrefill, ({String role, String company})?>(InterviewPrefill.new);
