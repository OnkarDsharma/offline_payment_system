String utcIsoTimestamp(DateTime value) {
  return value.toUtc().toIso8601String().split('.').first + 'Z';
}
