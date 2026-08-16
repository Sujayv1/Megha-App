import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../models/farm_location_model.dart';
import '../models/map_search_result.dart';
import '../services/location_service.dart';
import '../services/maptiler_search_service.dart';
import 'fixed_center_pin.dart';
import 'maplibre_satellite_map_view.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';

/// Production-grade full-screen Farm Location Picker.
///
/// Key layout rules:
/// - resizeToAvoidBottomInset: false → map never shrinks when keyboard opens
/// - Search predictions rendered via OverlayEntry → always ABOVE native GL surface
/// - CompositedTransformTarget/Follower for precise search bar → dropdown positioning
/// - FixedCenterPin uses OverflowBox so it never causes layout overflow errors
class FarmLocationPickerModal extends StatefulWidget {
  final FarmLocationModel currentLoc;

  const FarmLocationPickerModal({super.key, required this.currentLoc});

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required FarmLocationModel currentLoc,
  }) {
    return Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FarmLocationPickerModal(currentLoc: currentLoc),
      ),
    );
  }

  @override
  State<FarmLocationPickerModal> createState() =>
      _FarmLocationPickerModalState();
}

class _FarmLocationPickerModalState extends State<FarmLocationPickerModal> {
  late double _lat;
  late double _lon;
  late TextEditingController _nameController;
  late TextEditingController _searchController;
  late TextEditingController _latController;
  late TextEditingController _lonController;

  double _currentZoom = 15.5;
  bool _isSearching = false;
  bool _isFetchingGps = false;
  bool _isManualNameEdited = false;
  bool _initialLocationAttempted = false;

  List<MapSearchResult> _predictions = [];
  Timer? _debounce;
  int _searchRequestId = 0;
  late MapTilerSearchService _searchService;
  MapLibreMapController? _mapController;
  LatLng? _lastIdleCenter;

  // Overlay for search predictions — renders ABOVE the native MapLibre GL surface
  OverlayEntry? _overlayEntry;
  final LayerLink _searchBarLayerLink = LayerLink();

  @override
  void initState() {
    super.initState();
    _lat = widget.currentLoc.latitude;
    _lon = widget.currentLoc.longitude;
    _nameController =
        TextEditingController(text: widget.currentLoc.locationName);
    _searchController = TextEditingController();
    _latController = TextEditingController(text: _lat.toStringAsFixed(5));
    _lonController = TextEditingController(text: _lon.toStringAsFixed(5));
    _searchService = MapTilerSearchService(apiKey: AppConstants.mapTilerApiKey);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _nameController.dispose();
    _searchController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  // ── Overlay management ────────────────────────────────────────────────────

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = _buildOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _refreshOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
    }
  }

  OverlayEntry _buildOverlayEntry() {
    return OverlayEntry(
      builder: (ctx) {
        final showDropdown = _predictions.isNotEmpty;
        final showProgress = _isSearching;

        if (!showDropdown && !showProgress) return const SizedBox.shrink();

        return Positioned(
          width: MediaQuery.of(context).size.width - 32,
          child: CompositedTransformFollower(
            link: _searchBarLayerLink,
            showWhenUnlinked: false,
            // Offset below the search bar (search bar height ~52 + 4px gap)
            offset: const Offset(0, 56),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showProgress)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: LinearProgressIndicator(
                        color: AppColors.leafGreen,
                        backgroundColor: Colors.transparent,
                        minHeight: 2,
                      ),
                    ),
                  if (showDropdown)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 240),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2A1A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.leafGreen.withValues(alpha: 0.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          physics: const ClampingScrollPhysics(),
                          itemCount: _predictions.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          itemBuilder: (_, idx) {
                            final pred = _predictions[idx];
                            return InkWell(
                              onTap: () => _selectPrediction(pred),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_on_rounded,
                                        color: AppColors.leafGreen, size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(pred.primaryText,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              )),
                                          if (pred.secondaryText.isNotEmpty)
                                            Text(pred.secondaryText,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  color: Colors.white60,
                                                )),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Map callbacks ─────────────────────────────────────────────────────────

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    if (!_initialLocationAttempted) {
      _initialLocationAttempted = true;
      _requestAndFetchLiveLocation();
    }
  }

  Future<void> _requestAndFetchLiveLocation() async {
    if (!mounted) return;
    setState(() => _isFetchingGps = true);
    try {
      final pos = await LocationService.instance.getCurrentPosition();
      if (pos != null && mounted) {
        _animateCameraToLocation(
          pos.latitude,
          pos.longitude,
          name:
              'Live Location (${pos.latitude.toStringAsFixed(4)}° N, ${pos.longitude.toStringAsFixed(4)}° E)',
        );
      }
    } catch (_) {
      // Fall back silently to stored coordinates
    } finally {
      if (mounted) setState(() => _isFetchingGps = false);
    }
  }

  void _animateCameraToLocation(double lat, double lon,
      {String? name, double? zoom}) {
    final targetZoom = zoom ?? _currentZoom;
    if (mounted) {
      setState(() {
        _lat = lat;
        _lon = lon;
        _currentZoom = targetZoom;
        _latController.text = lat.toStringAsFixed(5);
        _lonController.text = lon.toStringAsFixed(5);
        if (name != null && !_isManualNameEdited) {
          _nameController.text = name;
        }
      });
    }
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(lat, lon), targetZoom),
    );
  }

  // ── Search ────────────────────────────────────────────────────────────────

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    final q = query.trim();
    if (q.length < 3) {
      _searchRequestId++;
      _predictions = [];
      _isSearching = false;
      _removeOverlay();
      return;
    }

    // Show spinner immediately
    _isSearching = true;
    if (_overlayEntry == null) {
      _showOverlay();
    } else {
      _refreshOverlay();
    }

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final currentId = ++_searchRequestId;

      final results = await _searchService.fetchAutocompletePredictions(
        query: q,
        currentLat: _lat,
        currentLon: _lon,
      );

      if (currentId == _searchRequestId &&
          mounted &&
          _searchController.text.trim() == q) {
        _predictions = results;
        _isSearching = false;
        if (_predictions.isEmpty) {
          _removeOverlay();
        } else {
          if (_overlayEntry == null) {
            _showOverlay();
          } else {
            _refreshOverlay();
          }
        }
      }
    });
  }

  Future<void> _selectPrediction(MapSearchResult prediction) async {
    FocusScope.of(context).unfocus();
    _searchRequestId++;
    _predictions = [];
    _isSearching = false;
    _removeOverlay();
    _searchController.clear();
    _animateCameraToLocation(
      prediction.latitude,
      prediction.longitude,
      name: prediction.secondaryText.isNotEmpty
          ? '${prediction.primaryText}, ${prediction.secondaryText}'
          : prediction.primaryText,
      zoom: 16.5,
    );
  }

  void _onCameraMove(CameraPosition position) {
    _lat = position.target.latitude;
    _lon = position.target.longitude;
  }

  void _onCameraIdle() async {
    final pos = _mapController?.cameraPosition;
    if (pos != null) {
      _lat = pos.target.latitude;
      _lon = pos.target.longitude;
      _currentZoom = pos.zoom;
    }

    final newCenter = LatLng(_lat, _lon);
    if (_lastIdleCenter == null ||
        (_lastIdleCenter!.latitude - _lat).abs() > 0.00005 ||
        (_lastIdleCenter!.longitude - _lon).abs() > 0.00005) {
      _lastIdleCenter = newCenter;
      if (mounted) {
        setState(() {
          _latController.text = _lat.toStringAsFixed(5);
          _lonController.text = _lon.toStringAsFixed(5);
        });
        if (!_isManualNameEdited) {
          final placeName = await _searchService.reverseGeocode(
            latitude: _lat,
            longitude: _lon,
          );
          if (mounted && !_isManualNameEdited) {
            setState(() => _nameController.text = placeName);
          }
        }
      }
    }
  }

  void _onLatLonInputsChanged() {
    final parsedLat = double.tryParse(_latController.text);
    final parsedLon = double.tryParse(_lonController.text);
    if (parsedLat != null &&
        parsedLon != null &&
        parsedLat >= -90 &&
        parsedLat <= 90 &&
        parsedLon >= -180 &&
        parsedLon <= 180) {
      _animateCameraToLocation(parsedLat, parsedLon);
    }
  }

  void _onSavePressed() {
    if (_lat < -90 || _lat > 90 || _lon < -180 || _lon > 180) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid coordinates.')),
      );
      return;
    }
    final farmName = _nameController.text.trim().isEmpty
        ? 'Farm Location (${_lat.toStringAsFixed(4)}° N, ${_lon.toStringAsFixed(4)}° E)'
        : _nameController.text.trim();

    Navigator.of(context).pop({'lat': _lat, 'lon': _lon, 'name': farmName});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBottom,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: AppColors.bgBottom,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            const Icon(Icons.satellite_alt_rounded,
                color: AppColors.leafGreen, size: 22),
            const SizedBox(width: 10),
            Text(
              'Select Farm Location',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Search Bar ──────────────────────────────────────────────────
            // CompositedTransformTarget anchors the overlay dropdown to this widget
            CompositedTransformTarget(
              link: _searchBarLayerLink,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  onTap: () {
                    // Re-show overlay if there are already predictions
                    if (_predictions.isNotEmpty && _overlayEntry == null) {
                      _showOverlay();
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Search village, town, or city...',
                    hintStyle: GoogleFonts.poppins(
                        fontSize: 12.5, color: Colors.grey.shade500),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.leafGreen),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchRequestId++;
                              _searchController.clear();
                              _predictions = [];
                              _isSearching = false;
                              _removeOverlay();
                              if (mounted) setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.cardCream,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: AppColors.leafGreen.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: AppColors.leafGreen, width: 1.5),
                    ),
                  ),
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: AppColors.textPrimary),
                ),
              ),
            ),

            // ── Map: Expanded → always gets remaining bounded height ────────
            Expanded(
              child: RepaintBoundary(
                child: Stack(
                  children: [
                    // MapLibre GL native view — must be Positioned.fill
                    Positioned.fill(
                      child: MapLibreSatelliteMapView(
                        initialCenter: LatLng(_lat, _lon),
                        initialZoom: _currentZoom,
                        onMapCreated: _onMapCreated,
                        onCameraMove: _onCameraMove,
                        onCameraIdle: _onCameraIdle,
                      ),
                    ),

                    // Center pin — OverflowBox prevents layout overflow errors
                    Positioned.fill(
                      child: OverflowBox(
                        alignment: Alignment.center,
                        maxHeight: double.infinity,
                        maxWidth: double.infinity,
                        child: FixedCenterPin(
                            latitude: _lat, longitude: _lon),
                      ),
                    ),

                    // Zoom controls
                    Positioned(
                      top: 14,
                      right: 14,
                      child: Column(
                        children: [
                          FloatingActionButton.small(
                            heroTag: 'ml_zoom_in',
                            backgroundColor: Colors.black87,
                            elevation: 4,
                            onPressed: () => _mapController
                                ?.animateCamera(CameraUpdate.zoomIn()),
                            child: const Icon(Icons.add_rounded,
                                color: Colors.white, size: 20),
                          ),
                          const SizedBox(height: 8),
                          FloatingActionButton.small(
                            heroTag: 'ml_zoom_out',
                            backgroundColor: Colors.black87,
                            elevation: 4,
                            onPressed: () => _mapController
                                ?.animateCamera(CameraUpdate.zoomOut()),
                            child: const Icon(Icons.remove_rounded,
                                color: Colors.white, size: 20),
                          ),
                        ],
                      ),
                    ),

                    // GPS my-location button
                    Positioned(
                      bottom: 14,
                      right: 14,
                      child: FloatingActionButton.small(
                        heroTag: 'ml_my_location',
                        backgroundColor: AppColors.leafGreen,
                        elevation: 4,
                        onPressed: _isFetchingGps
                            ? null
                            : _requestAndFetchLiveLocation,
                        child: _isFetchingGps
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.my_location_rounded,
                                color: Colors.white, size: 20),
                      ),
                    ),

                    // Attribution
                    Positioned(
                      bottom: 6,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '© MapTiler © OpenStreetMap contributors',
                          style: GoogleFonts.poppins(
                              fontSize: 9, color: Colors.white70),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Form fields — fixed padding, keyboard overlays ──────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Lat / Lon row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _latController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                          onSubmitted: (_) => _onLatLonInputsChanged(),
                          decoration: InputDecoration(
                            labelText: 'Latitude',
                            labelStyle: GoogleFonts.poppins(
                                fontSize: 12, color: AppColors.textMuted),
                            filled: true,
                            fillColor: AppColors.cardCream,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          style: GoogleFonts.poppins(
                              fontSize: 13, color: AppColors.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _lonController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                          onSubmitted: (_) => _onLatLonInputsChanged(),
                          decoration: InputDecoration(
                            labelText: 'Longitude',
                            labelStyle: GoogleFonts.poppins(
                                fontSize: 12, color: AppColors.textMuted),
                            filled: true,
                            fillColor: AppColors.cardCream,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          style: GoogleFonts.poppins(
                              fontSize: 13, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Farm name
                  TextField(
                    controller: _nameController,
                    onChanged: (val) {
                      if (val.trim().isNotEmpty) _isManualNameEdited = true;
                    },
                    decoration: InputDecoration(
                      labelText: 'Farm / Location Name',
                      labelStyle: GoogleFonts.poppins(
                          fontSize: 12, color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.edit_location_alt_rounded,
                          color: AppColors.leafGreen),
                      filled: true,
                      fillColor: AppColors.cardCream,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 10),

                  // Save button
                  SizedBox(
                    height: 50,
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.leafGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                      ),
                      onPressed: _onSavePressed,
                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                      label: Text(
                        'Save Farm Location',
                        style: GoogleFonts.poppins(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
