import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:womensafteyhackfair/route_service.dart';

void main() {
  group('RouteService Geocoding Retry Tests', () {
    late RouteService routeService;

    setUp(() {
      routeService = RouteService();
    });

    tearDown(() {
      routeService.client = null;
    });

    test('geocodeDestination retries and eventually succeeds', () async {
      int callCount = 0;

      // Mock client that fails twice, then succeeds
      routeService.client = MockClient((request) async {
        callCount++;
        if (callCount < 3) {
          return http.Response('Internal Server Error', 500);
        }
        return http.Response(
          jsonEncode([
            {'lat': '12.9716', 'lon': '77.5946'}
          ]),
          200,
        );
      });

      final result = await routeService.geocodeDestination('Bangalore');
      expect(result, isNotNull);
      expect(result![0], 12.9716);
      expect(result![1], 77.5946);
      expect(callCount, 3); // Should retry until success (3rd attempt)
    });

    test('geocodeDestination returns null after max retries fail', () async {
      int callCount = 0;

      // Mock client that always fails
      routeService.client = MockClient((request) async {
        callCount++;
        return http.Response('Timeout/Service Unavailable', 503);
      });

      final result = await routeService.geocodeDestination('Bangalore');
      expect(result, isNull);
      expect(callCount, 3); // Retried max (3) times
    });

    test('geocodeDestination returns null immediately on 200 with empty list', () async {
      int callCount = 0;

      // Mock client that returns 200 but empty list (place not found)
      routeService.client = MockClient((request) async {
        callCount++;
        return http.Response(jsonEncode([]), 200);
      });

      final result = await routeService.geocodeDestination('InvalidPlace123456');
      expect(result, isNull);
      expect(callCount, 1); // Returns null immediately, no retry needed
    });
  });
}
