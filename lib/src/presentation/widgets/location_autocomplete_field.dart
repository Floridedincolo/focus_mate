import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/service_locator.dart';
import '../../data/datasources/location_search_service.dart';
import '../../domain/entities/autocomplete_prediction.dart';
import '../../domain/entities/meeting_location.dart';

/// Reusable Google-Places-powered location field with autocomplete dropdown.
///
/// Encapsulates debouncing, session tokens, predictions fetching, and place
/// details resolution. Returns a full [MeetingLocation] (name + lat/lng)
/// through [onLocationSelected] when the user taps a suggestion.
class LocationAutocompleteField extends StatefulWidget {
  final String? initialLocationName;
  final ValueChanged<MeetingLocation?> onLocationSelected;
  final ValueChanged<String>? onTextChanged;
  final InputDecoration? decoration;
  final String countryCode;
  final double? userLat;
  final double? userLng;

  const LocationAutocompleteField({
    super.key,
    this.initialLocationName,
    required this.onLocationSelected,
    this.onTextChanged,
    this.decoration,
    this.countryCode = 'ro',
    this.userLat,
    this.userLng,
  });

  @override
  State<LocationAutocompleteField> createState() =>
      _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState
    extends State<LocationAutocompleteField> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  static const _uuid = Uuid();
  String _sessionToken = _uuid.v4();
  List<AutocompletePrediction> _predictions = [];
  Timer? _debounce;
  bool _suppress = false;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.initialLocationName ?? '');
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    widget.onTextChanged?.call(_controller.text);

    if (_suppress) return;

    _debounce?.cancel();
    final query = _controller.text.trim();
    if (query.length < 2) {
      setState(() => _predictions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _fetchPredictions(query);
    });
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _sessionToken = _uuid.v4();
    } else {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _predictions = []);
      });
    }
  }

  Future<void> _fetchPredictions(String query) async {
    try {
      final service = getIt<LocationSearchService>();
      final results = await service.autocompletePlaces(
        input: query,
        sessionToken: _sessionToken,
        countryCode: widget.countryCode,
        userLat: widget.userLat,
        userLng: widget.userLng,
      );
      if (mounted) setState(() => _predictions = results);
    } catch (_) {}
  }

  Future<void> _selectPrediction(AutocompletePrediction pred) async {
    _suppress = true;
    _controller.text = pred.mainText;
    _suppress = false;
    setState(() => _predictions = []);

    MeetingLocation? location;
    try {
      final service = getIt<LocationSearchService>();
      location = await service.getPlaceDetails(
        placeId: pred.placeId,
        sessionToken: _sessionToken,
      );
    } catch (_) {}

    location ??= MeetingLocation(name: pred.mainText);
    widget.onLocationSelected(location);
    _sessionToken = _uuid.v4();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: _controller,
          focusNode: _focusNode,
          style: const TextStyle(color: Colors.white),
          decoration: widget.decoration ?? _defaultDecoration(),
        ),
        if (_predictions.isNotEmpty) _buildPredictionsList(),
      ],
    );
  }

  InputDecoration _defaultDecoration() {
    return InputDecoration(
      hintText: 'Search for a place…',
      hintStyle: const TextStyle(color: Colors.white38),
      prefixIcon:
          const Icon(Icons.location_on_outlined, color: Colors.white38),
      filled: true,
      fillColor: const Color(0xFF1A1A1A),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: Colors.white.withValues(alpha: 0.06)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Colors.blueAccent, width: 1.5),
      ),
    );
  }

  Widget _buildPredictionsList() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _predictions.map((pred) {
          return InkWell(
            onTap: () => _selectPrediction(pred),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.place_outlined,
                      color: Colors.white38, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pred.mainText,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (pred.secondaryText.isNotEmpty)
                          Text(
                            pred.secondaryText,
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
