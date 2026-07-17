void validateUnifiedFiles(
  Map<String, List<int>> files,
  List<Map<String, Object?>> airports,
) {
  final expected = <String>{'config.yaml', 'verge.yaml', 'profiles.yaml'};
  for (final airport in airports) {
    final slug = airport['slug'] as String;
    final uid = airport['profileUid'] as String;
    expected.addAll([
      'profiles/$uid.yaml',
      'providers/$slug/provider.yaml',
      'providers/$slug/profile.yaml',
      'providers/$slug/meta.json',
    ]);
  }
  if (files.keys.toSet().difference(expected).isNotEmpty ||
      expected.difference(files.keys.toSet()).isNotEmpty) {
    throw StateError('Unified V1 file set violates the archive contract');
  }
}
