import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/service_locator.dart';
import '../../data/datasources/location_history_service.dart';
import '../../data/datasources/location_search_service.dart';
import '../../domain/entities/autocomplete_prediction.dart';
import '../../domain/entities/meeting_location.dart';

/// Reusable Google-Places-powered location field with autocomplete dropdown.
///
/// Shows saved location history when focused (before typing), then switches
/// to Google Places autocomplete as the user types. Saves selected locations
/// to local history for future quick access.
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
  final LocationHistoryService _historyService = LocationHistoryService();

  static const _uuid = Uuid();
  String _sessionToken = _uuid.v4();
  List<AutocompletePrediction> _predictions = [];
  List<MeetingLocation> _savedLocations = [];
  Timer? _debounce;
  bool _suppress = false;
  bool _showHistory = false;

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

    if (query.isEmpty) {
      // Show history when field is empty
      setState(() {
        _predictions = [];
        _showHistory = true;
      });
      return;
    }

    if (query.length < 2) {
      setState(() {
        _predictions = [];
        _showHistory = false;
      });
      return;
    }

    // Filter saved locations that match the query
    setState(() => _showHistory = false);

    _debounce = Timer(const Duration(milliseconds: 400), () {
      _fetchPredictions(query);
    });
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _sessionToken = _uuid.v4();
      _loadHistory();
    } else {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            _predictions = [];
            _showHistory = false;
          });
        }
      });
    }
  }

  Future<void> _loadHistory() async {
    final locations = await _historyService.getSavedLocations();
    if (mounted) {
      setState(() {
        _savedLocations = locations;
        if (_controller.text.trim().isEmpty) {
          _showHistory = true;
        }
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
    setState(() {
      _predictions = [];
      _showHistory = false;
    });

    MeetingLocation? location;
    try {
      final service = getIt<LocationSearchService>();
      location = await service.getPlaceDetails(
        placeId: pred.placeId,
        sessionToken: _sessionToken,
      );
    } catch (_) {}

    location ??= MeetingLocation(name: pred.mainText);

    // Save to history if it has coordinates
    if (location.hasCoordinates) {
      _historyService.saveLocation(location);
    }

    widget.onLocationSelected(location);
    _sessionToken = _uuid.v4();
  }

  void _selectSavedLocation(MeetingLocation location) {
    _suppress = true;
    _controller.text = location.name;
    _suppress = false;
    setState(() {
      _showHistory = false;
      _predictions = [];
    });

    // Move to top of history
    _historyService.saveLocation(location);

    widget.onLocationSelected(location);
  }

  Future<void> _removeSavedLocation(MeetingLocation location) async {
    await _historyService.removeLocation(location.name);
    await _loadHistory();
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
        if (_showHistory && _savedLocations.isNotEmpty) _buildHistoryList(),
        if (!_showHistory && _predictions.isNotEmpty) _buildPredictionsList(),
      ],
    );
  }

  InputDecoration _defaultDecoration() {
    return InputDecoration(
      hintText: 'Search for a place...',
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

  Widget _buildHistoryList() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Text(
              'Recent locations',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ..._savedLocations.map((loc) {
            return Dismissible(
              key: ValueKey(loc.name),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => _removeSavedLocation(loc),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                color: Colors.red.withValues(alpha: 0.2),
                child: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 20),
              ),
              child: InkWell(
                onTap: () => _selectSavedLocation(loc),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.history,
                          color: Colors.white38, size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          loc.name,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (loc.hasCoordinates)
                        Icon(Icons.gps_fixed,
                            color: Colors.greenAccent.withValues(alpha: 0.5),
                            size: 14),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
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
