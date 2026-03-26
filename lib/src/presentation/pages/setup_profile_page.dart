import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/meeting_location.dart';
import '../providers/user_location_providers.dart';
import '../widgets/location_autocomplete_field.dart';
import 'main_page.dart';

/// Onboarding screen shown once after the first login.
///
/// The user sets their **Home** and **Work / University** locations via
/// Google Places autocomplete, then taps "Save & Continue".
/// Both locations with valid coordinates are required — there is no skip.
class SetupProfilePage extends ConsumerStatefulWidget {
  const SetupProfilePage({super.key});

  @override
  ConsumerState<SetupProfilePage> createState() => _SetupProfilePageState();
}

class _SetupProfilePageState extends ConsumerState<SetupProfilePage> {
  MeetingLocation? _homeLocation;
  MeetingLocation? _workLocation;
  bool _saving = false;

  bool get _canContinue =>
      _homeLocation != null &&
      _homeLocation!.hasCoordinates &&
      _workLocation != null &&
      _workLocation!.hasCoordinates;

  Future<void> _saveAndContinue() async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(userLocationRepoProvider);
      await repo.saveUserLocations(
        home: _homeLocation,
        work: _workLocation,
      );
      await repo.markSetupComplete();

      ref.invalidate(hasCompletedSetupProvider);

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainPage()),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                const Center(
                  child: Icon(Icons.location_on_rounded,
                      color: Colors.blueAccent, size: 64),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    "Set Up Your Locations",
                    style: TextStyle(
                      color: Colors.white, fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    "These help us auto-fill locations for your\nimported schedule and meeting suggestions.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 15),
                  ),
                ),
                const SizedBox(height: 40),

                _buildLabel("Home Location", Icons.home_rounded),
                const SizedBox(height: 8),
                _buildLocationField(
                  hint: "Search for your home address…",
                  selectedLocation: _homeLocation,
                  onLocationSelected: (loc) =>
                      setState(() => _homeLocation = loc),
                ),
                const SizedBox(height: 28),

                _buildLabel("Work / University", Icons.school_rounded),
                const SizedBox(height: 8),
                _buildLocationField(
                  hint: "Search for your campus or office…",
                  selectedLocation: _workLocation,
                  onLocationSelected: (loc) =>
                      setState(() => _workLocation = loc),
                ),
                const SizedBox(height: 48),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (_canContinue && !_saving)
                        ? _saveAndContinue
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      disabledBackgroundColor: Colors.blueAccent.withValues(alpha: 0.3),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text("Save & Continue"),
                  ),
                ),
                const SizedBox(height: 12),

                if (!_canContinue)
                  const Center(
                    child: Text(
                      "Select both locations to continue",
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, IconData icon) {
    return Row(children: [
      Icon(icon, color: Colors.blueAccent, size: 20),
      const SizedBox(width: 8),
      Text(text, style: const TextStyle(
        color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _buildLocationField({
    required String hint,
    required MeetingLocation? selectedLocation,
    required ValueChanged<MeetingLocation?> onLocationSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LocationAutocompleteField(
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
            suffixIcon: selectedLocation != null && selectedLocation.hasCoordinates
                ? const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20)
                : null,
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onLocationSelected: onLocationSelected,
        ),
        if (selectedLocation != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              selectedLocation.hasCoordinates
                  ? selectedLocation.name
                  : "${selectedLocation.name} (no coordinates)",
              style: TextStyle(
                color: selectedLocation.hasCoordinates
                    ? Colors.greenAccent
                    : Colors.orangeAccent,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}
