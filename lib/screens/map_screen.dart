import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:map_markers/screens/audit_manager.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _controller;
  final AuditManager _auditManager = AuditManager();

  static const CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(37.4219983, -122.084),
    zoom: 14.0,
  );

  CameraPosition _currentPosition = _defaultPosition;
  bool _isLoadingLocation = true;

  Set<Marker> _markers = {};
  Marker? _selectedPlaceMarker;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  List<_PlaceSuggestion> _searchSuggestions = [];
  String? _searchError;
  bool _isSearching = false;
  bool _hasSearched = false;
  int _searchRequestId = 0;

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _loadMarkers();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _loadMarkers() {
    setState(() {
      _markers = _auditManager.pins.map((pin) {
        return Marker(
          markerId: MarkerId(pin.id),
          position: pin.location,
          infoWindow: InfoWindow(title: pin.title, snippet: pin.snippet),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        );
      }).toSet();
    });
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    final requestId = ++_searchRequestId;
    final normalizedQuery = query.trim();

    if (normalizedQuery.length < 2) {
      setState(() {
        _searchSuggestions = [];
        _searchError = null;
        _isSearching = false;
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _searchSuggestions = [];
      _searchError = null;
      _isSearching = true;
    });
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _searchPlaces(normalizedQuery, requestId),
    );
  }

  Future<void> _searchPlaces(String query, int requestId) async {
    try {
      final uri = Uri.https('photon.komoot.io', '/api/', {
        'q': query,
        'limit': '6',
        'lang': 'en',
      });
      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'MapMarkers/1.0 (place search)',
            },
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw http.ClientException(
          'Place search returned HTTP ${response.statusCode}',
          uri,
        );
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final features = payload['features'] as List<dynamic>? ?? [];
      final suggestions = features
          .map(
            (feature) =>
                _PlaceSuggestion.fromFeature(feature as Map<String, dynamic>),
          )
          .whereType<_PlaceSuggestion>()
          .toList();

      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _searchSuggestions = suggestions;
        _searchError = null;
        _isSearching = false;
        _hasSearched = true;
      });
    } catch (error) {
      if (!mounted || requestId != _searchRequestId) return;
      debugPrint('Place search failed: $error');
      setState(() {
        _searchSuggestions = [];
        _searchError = 'Search failed. Check your connection and try again.';
        _isSearching = false;
        _hasSearched = true;
      });
    }
  }

  void _selectPlace(_PlaceSuggestion suggestion) {
    _searchDebounce?.cancel();
    _searchController.text = suggestion.title;
    _searchFocusNode.unfocus();
    setState(() {
      _searchSuggestions = [];
      _searchError = null;
      _hasSearched = false;
      _selectedPlaceMarker = Marker(
        markerId: const MarkerId('search-result'),
        position: suggestion.location,
        infoWindow: InfoWindow(title: suggestion.title),
      );
    });
    _controller?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: suggestion.location, zoom: 16),
      ),
    );
  }

  Future<void> _determinePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (e) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position != null) {
        LatLng userLatLng = LatLng(position.latitude, position.longitude);
        setState(() {
          _currentPosition = CameraPosition(target: userLatLng, zoom: 17.0);
        });
        _controller?.animateCamera(
          CameraUpdate.newCameraPosition(_currentPosition),
        );
      }
    } catch (e) {
      debugPrint("Location error: $e");
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _goToMyCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      LatLng userLatLng = LatLng(position.latitude, position.longitude);

      _controller?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: userLatLng, zoom: 17.0),
        ),
      );
    } catch (e) {
      debugPrint("Error getting location: $e");
    }
  }

  void _onMapTapped(LatLng position) {
    String title = 'Audit Pin ${_auditManager.pins.length + 1}';
    String snippet =
        'Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}';

    // Add to manager service
    _auditManager.addPin(position, title, snippet);

    // Refresh local markers
    _loadMarkers();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pin saved to Favorites!'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _clearMarkers() {
    _auditManager.clearAll();
    _loadMarkers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoadingLocation
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: _currentPosition,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  markers: {..._markers, ?_selectedPlaceMarker},
                  onTap: _onMapTapped,
                  onMapCreated: (GoogleMapController controller) {
                    _controller = controller;
                  },
                  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                    Factory<EagerGestureRecognizer>(
                      () => EagerGestureRecognizer(),
                    ),
                  },
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(8),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: _onSearchChanged,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: 'Search places',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear search',
                                    onPressed: () {
                                      _searchController.clear();
                                      _onSearchChanged('');
                                    },
                                    icon: const Icon(Icons.clear),
                                  ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      if (_isSearching ||
                          _searchError != null ||
                          _searchSuggestions.isNotEmpty ||
                          _hasSearched)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          constraints: const BoxConstraints(maxHeight: 280),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 6),
                            ],
                          ),
                          child: _isSearching
                              ? const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : _searchError != null
                              ? Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(_searchError!),
                                )
                              : _searchSuggestions.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text('No places found.'),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  itemCount: _searchSuggestions.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final suggestion =
                                        _searchSuggestions[index];
                                    return ListTile(
                                      leading: const Icon(
                                        Icons.location_on_outlined,
                                      ),
                                      title: Text(suggestion.title),
                                      subtitle: suggestion.address.isEmpty
                                          ? null
                                          : Text(suggestion.address),
                                      onTap: () => _selectPlace(suggestion),
                                    );
                                  },
                                ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 24,
                  child: Column(
                    children: [
                      FloatingActionButton(
                        heroTag: 'locationBtn',
                        mini: true,
                        backgroundColor: Colors.white,
                        onPressed: _goToMyCurrentLocation,
                        child: const Icon(
                          Icons.my_location,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        heroTag: 'clearBtn',
                        mini: true,
                        backgroundColor: Colors.white,
                        onPressed: _clearMarkers,
                        child: const Icon(
                          Icons.delete_sweep,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _PlaceSuggestion {
  const _PlaceSuggestion({
    required this.title,
    required this.address,
    required this.location,
  });

  final String title;
  final String address;
  final LatLng location;

  static _PlaceSuggestion? fromFeature(Map<String, dynamic> feature) {
    final properties = feature['properties'] as Map<String, dynamic>?;
    final geometry = feature['geometry'] as Map<String, dynamic>?;
    final coordinates = geometry?['coordinates'] as List<dynamic>?;
    if (properties == null || coordinates == null || coordinates.length < 2) {
      return null;
    }

    final longitude = coordinates[0];
    final latitude = coordinates[1];
    if (longitude is! num || latitude is! num) return null;

    final name = properties['name'] as String?;
    final addressParts = [
      properties['housenumber'],
      properties['street'],
      properties['city'],
      properties['state'],
      properties['country'],
    ].whereType<String>().where((part) => part.isNotEmpty).toSet().toList();
    final title = name?.trim().isNotEmpty == true
        ? name!.trim()
        : addressParts.isNotEmpty
        ? addressParts.first
        : 'Unknown place';

    return _PlaceSuggestion(
      title: title,
      address: addressParts.where((part) => part != title).join(', '),
      location: LatLng(latitude.toDouble(), longitude.toDouble()),
    );
  }
}
