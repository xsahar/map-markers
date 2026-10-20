import 'package:google_maps_flutter/google_maps_flutter.dart';

class AuditPin {
  final String id;
  final LatLng location;
  final String title;
  final String snippet;
  final DateTime timestamp;

AuditPin({
  required this.id,
  required this.location,
  required this.title,
  required this.snippet,
  required this.timestamp,
});

  Map<String, dynamic> toJson() => {
    'id': id,
    'latitude': location.latitude,
    'longitude': location.longitude,
    'title': title,
    'snippet': snippet,
    'timestamp':timestamp.toIso8601String(),
  };

  factory AuditPin.fromJson(Map<String, dynamic> json) => AuditPin(
        id: json['id'],
        location: LatLng(json['latitude'], json['longitude']),
        title: json['title'],
        snippet: json['snippet'],
        timestamp: DateTime.parse(json['timestamp']),
      );
}