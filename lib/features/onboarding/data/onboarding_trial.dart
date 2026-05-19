/// Free-trial duration and user-facing copy for onboarding flows.
abstract final class OnboardingTrial {
  OnboardingTrial._();

  /// Calendar months of free access set on tenant `expire_date` at registration.
  static const periodMonths = 1;

  static const registerHeaderTitle = 'Start your 1-month free trial';

  static const loginTrialSemanticLabel =
      "Don't have a store? Start your 1-month free trial. Opens registration.";

  static const loginTrialSubtitle =
      'Start your 1-month free trial — create your shop in minutes.';

  static const landingStartTrialLabel = 'Start 1-Month Free Trial';
}
