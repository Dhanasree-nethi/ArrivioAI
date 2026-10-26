import 'package:shared_preferences/shared_preferences.dart';

/// The local profile collected during the prototype onboarding flow.
///
/// This deliberately contains no authentication credentials. It provides one
/// place for the UI to store the information that a future account service can
/// later own.
class OnboardingProfile {
  const OnboardingProfile({required this.fullName, required this.contact});

  final String fullName;
  final String contact;
}

abstract class OnboardingRepository {
  Future<bool> hasCompletedOnboarding();
  Future<OnboardingProfile?> getProfile();
  Future<void> markOnboardingComplete(OnboardingProfile profile);
  Future<void> updateProfile(OnboardingProfile profile);
  Future<void> resetOnboarding();
}

class SharedPreferencesOnboardingRepository implements OnboardingRepository {
  static const _key = 'arrivio_onboarding_complete';
  static const _nameKey = 'arrivio_profile_name';
  static const _contactKey = 'arrivio_profile_contact';

  // Keeps setup usable for the current app session if device storage is
  // temporarily unavailable (for example, during an emulator/plugin reset).
  static bool _sessionCompleted = false;

  @override
  Future<bool> hasCompletedOnboarding() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getBool(_key) ?? _sessionCompleted;
    } catch (_) {
      return _sessionCompleted;
    }
  }

  @override
  Future<OnboardingProfile?> getProfile() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final name = preferences.getString(_nameKey)?.trim();
      final contact = preferences.getString(_contactKey)?.trim();
      if (name == null || name.isEmpty || contact == null || contact.isEmpty) {
        return null;
      }
      return OnboardingProfile(fullName: name, contact: contact);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> markOnboardingComplete(OnboardingProfile profile) async {
    // Update the in-memory state first so onboarding always completes in this
    // prototype. SharedPreferences then persists it across app launches when
    // platform storage is available.
    _sessionCompleted = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await Future.wait([
        preferences.setBool(_key, true),
        preferences.setString(_nameKey, profile.fullName),
        preferences.setString(_contactKey, profile.contact),
      ]);
      if (saved.any((value) => !value)) {
        throw StateError('Local preferences rejected the onboarding save.');
      }
    } catch (_) {
      // The in-memory completion state remains active for this session. A
      // future launch will retry the persistent storage read/write path.
    }
  }

  @override
  Future<void> updateProfile(OnboardingProfile profile) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await Future.wait([
        preferences.setString(_nameKey, profile.fullName),
        preferences.setString(_contactKey, profile.contact),
      ]);
      if (saved.any((value) => !value)) {
        throw StateError('Local preferences rejected the profile save.');
      }
    } catch (_) {
      rethrow;
    }
  }

  @override
  Future<void> resetOnboarding() async {
    _sessionCompleted = false;
    try {
      final preferences = await SharedPreferences.getInstance();
      await Future.wait([
        preferences.remove(_key),
        preferences.remove(_nameKey),
        preferences.remove(_contactKey),
      ]);
    } catch (_) {
      // Resetting the session state still makes the flow testable when the
      // platform preferences plugin is temporarily unavailable.
    }
  }
}

class InMemoryOnboardingRepository implements OnboardingRepository {
  InMemoryOnboardingRepository({this.completed = false, this.profile});
  bool completed;
  OnboardingProfile? profile;
  @override
  Future<bool> hasCompletedOnboarding() async => completed;
  @override
  Future<OnboardingProfile?> getProfile() async => profile;
  @override
  Future<void> markOnboardingComplete(OnboardingProfile profile) async {
    completed = true;
    this.profile = profile;
  }

  @override
  Future<void> updateProfile(OnboardingProfile profile) async {
    this.profile = profile;
  }

  @override
  Future<void> resetOnboarding() async {
    completed = false;
    profile = null;
  }
}
