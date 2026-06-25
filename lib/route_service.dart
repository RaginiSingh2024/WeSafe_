import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Fetches a driving route polyline between two GPS points using
/// free, no-API-key services:
///   - Nominatim (OpenStreetMap) for geocoding destination text → lat/lng
///   - OSRM demo server for turn-by-turn polyline
class RouteService {
  static final RouteService _instance = RouteService._internal();
  factory RouteService() => _instance;
  RouteService._internal();

  http.Client? client;

  // ───────────────────────────────────────────────────────────────────────────
  // GEOCODE: destination name → (lat, lng)
  // ───────────────────────────────────────────────────────────────────────────
  /// Returns [latitude, longitude] for a place name, or null if not found.
  Future<List<double>?> geocodeDestination(String placeName) async {
    int maxRetries = 3;
    Duration timeoutDuration = const Duration(seconds: 8);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final encoded = Uri.encodeComponent(placeName);
        final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$encoded&format=json&limit=1',
        );
        final headers = {
          'User-Agent': 'WeSafeApp/1.0',
          'Accept': 'application/json',
        };
        final response = await (client != null
            ? client!.get(uri, headers: headers)
            : http.get(uri, headers: headers)).timeout(timeoutDuration);

        if (response.statusCode == 200) {
          final List data = jsonDecode(response.body);
          if (data.isNotEmpty) {
            final double lat = double.parse(data[0]['lat']);
            final double lon = double.parse(data[0]['lon']);
            debugPrint('Geocoded "$placeName" → $lat, $lon (attempt $attempt)');
            return [lat, lon];
          } else {
            debugPrint('Geocoding search returned no results for "$placeName"');
            return null;
          }
        } else {
          debugPrint('Geocoding failed with status code ${response.statusCode} (attempt $attempt)');
        }
      } catch (e) {
        debugPrint('Geocoding attempt $attempt failed with error: $e');
        if (attempt == maxRetries) {
          debugPrint('Geocoding error: $e');
        }
      }

      if (attempt < maxRetries) {
        final delay = Duration(seconds: attempt * 2);
        debugPrint('Waiting ${delay.inSeconds}s before retrying geocoding...');
        await Future.delayed(delay);
      }
    }
    return null;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ROUTE: origin → destination → decoded polyline points
  // ───────────────────────────────────────────────────────────────────────────
  /// Returns a list of [lat, lng] pairs forming the driving route.
  /// Uses OSRM's public demo server (free, no key required).
  Future<List<List<double>>> fetchRoutePolyline({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    try {
      // OSRM uses lon,lat order (not lat,lon)
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '$originLng,$originLat;$destLng,$destLat'
        '?overview=full&geometries=polyline',
      );
      final headers = {
        'User-Agent': 'WeSafeApp/1.0',
      };
      final response = await (client != null
          ? client!.get(uri, headers: headers)
          : http.get(uri, headers: headers)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['code'] == 'Ok' && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final String encoded = data['routes'][0]['geometry'];
          final points = _decodePolyline(encoded);
          debugPrint('Route fetched: ${points.length} waypoints');
          return points;
        }
      }
    } catch (e) {
      debugPrint('Route fetch error: $e');
    }
    return [];
  }

  // ───────────────────────────────────────────────────────────────────────────
  // POLYLINE DECODER (Google Encoded Polyline Algorithm)
  // ───────────────────────────────────────────────────────────────────────────
  List<List<double>> _decodePolyline(String encoded) {
    final List<List<double>> result = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int b;
      int shift = 0;
      int result_ = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result_ |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dLat = ((result_ & 1) != 0) ? ~(result_ >> 1) : (result_ >> 1);
      lat += dLat;

      shift = 0;
      result_ = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result_ |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dLng = ((result_ & 1) != 0) ? ~(result_ >> 1) : (result_ >> 1);
      lng += dLng;

      result.add([lat / 1e5, lng / 1e5]);
    }
    return result;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // DISTANCE: point to nearest polyline segment (in metres)
  // ───────────────────────────────────────────────────────────────────────────
  /// Returns the shortest distance in metres from [lat,lng] to any
  /// segment of [polyline]. Returns double.infinity if polyline is empty.
  double distanceToPolyline({
    required double lat,
    required double lng,
    required List<List<double>> polyline,
  }) {
    if (polyline.isEmpty) return double.infinity;
    if (polyline.length == 1) {
      return _haversine(lat, lng, polyline[0][0], polyline[0][1]);
    }

    double minDist = double.infinity;
    for (int i = 0; i < polyline.length - 1; i++) {
      final double d = _pointToSegmentDistance(
        lat, lng,
        polyline[i][0], polyline[i][1],
        polyline[i + 1][0], polyline[i + 1][1],
      );
      if (d < minDist) minDist = d;
    }
    return minDist;
  }

  /// Perpendicular distance from point P to segment AB (all in degrees → metres).
  double _pointToSegmentDistance(
    double pLat, double pLng,
    double aLat, double aLng,
    double bLat, double bLng,
  ) {
    // Project onto segment using dot product in flat-earth approximation.
    // Good enough for short distances (< 10 km).
    final double ax = aLng - pLng;
    final double ay = aLat - pLat;
    final double bx = bLng - pLng;
    final double by = bLat - pLat;
    final double abx = bLng - aLng;
    final double aby = bLat - aLat;

    final double t = -(ax * abx + ay * aby) / (abx * abx + aby * aby + 1e-10);
    final double clampedT = t.clamp(0.0, 1.0);

    final double closestLat = aLat + clampedT * aby;
    final double closestLng = aLng + clampedT * abx;
    return _haversine(pLat, pLng, closestLat, closestLng);
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371000;
    final double dLat = _toRad(lat2 - lat1);
    final double dLon = _toRad(lon2 - lon1);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _toRad(double deg) => deg * (pi / 180);
}
