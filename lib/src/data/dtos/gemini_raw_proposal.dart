/// Raw proposal returned by Gemini (Step 1 of the pipeline).
///
/// Contains time slots + a GPS midpoint and place keyword for the
/// subsequent Places API lookup (Step 2).
class GeminiRawProposal {
  final DateTime startTime;
  final DateTime endTime;

  /// Logical midpoint latitude computed by Gemini.
  final double targetLatitude;

  /// Logical midpoint longitude computed by Gemini.
  final double targetLongitude;

  /// Place category keyword (e.g. "cafe", "restaurant", "park").
  final String placeKeyword;

  /// Gemini's reasoning for this slot.
  final String? rationale;

  const GeminiRawProposal({
    required this.startTime,
    required this.endTime,
    required this.targetLatitude,
    required this.targetLongitude,
    required this.placeKeyword,
    this.rationale,
  });
}
