Future<Map<String, double>> getCurrentLocation() async {
  // Return a mock default coordinate for mobile to keep code fully compile-safe
  // and avoid complex native permissions configuration during testing.
  return {
    'latitude': 19.0760,
    'longitude': 72.8777,
  };
}
