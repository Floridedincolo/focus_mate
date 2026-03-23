/// A single prediction returned by the Places Autocomplete API.
class AutocompletePrediction {
  /// The Google Place ID — used to fetch full details.
  final String placeId;

  /// Primary text (e.g. "Starbucks Palas").
  final String mainText;

  /// Secondary text (e.g. "Iași, Romania").
  final String secondaryText;

  /// Full description (e.g. "Starbucks Palas, Iași, Romania").
  final String fullText;

  const AutocompletePrediction({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    required this.fullText,
  });

  @override
  String toString() => fullText;
}

