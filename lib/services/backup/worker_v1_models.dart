class WorkerV1FileEntry {
  const WorkerV1FileEntry({
    required this.sha256,
    required this.contentLength,
    required this.required,
  });

  final String sha256;
  final int contentLength;
  final bool required;
}

class WorkerV1Manifest {
  const WorkerV1Manifest({
    required this.raw,
    required this.files,
    required this.airports,
  });

  final Map<String, Object?> raw;
  final Map<String, WorkerV1FileEntry> files;
  final List<Map<String, Object?>> airports;
}

class WorkerV1Package {
  const WorkerV1Package({
    required this.manifest,
    required this.profilesYaml,
    required this.files,
  });

  final WorkerV1Manifest manifest;
  final Map<String, Object?> profilesYaml;
  final Map<String, List<int>> files;
}
