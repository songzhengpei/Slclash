part of 'database.dart';

class StringMapConverter extends TypeConverter<Map<String, String>, String> {
  const StringMapConverter();

  @override
  Map<String, String> fromSql(String fromDb) {
    return Map<String, String>.from(json.decode(fromDb));
  }

  @override
  String toSql(Map<String, String> value) {
    return json.encode(value);
  }
}

class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) {
    return List<String>.from(json.decode(fromDb));
  }

  @override
  String toSql(List<String> value) {
    return json.encode(value.toList());
  }
}

class StringSetConverter extends TypeConverter<Set<String>, String> {
  const StringSetConverter();

  @override
  Set<String> fromSql(String fromDb) {
    return Set<String>.from(json.decode(fromDb));
  }

  @override
  String toSql(Set<String> value) {
    return json.encode(value.toList());
  }
}

const int kProxyGroupsSnapshotVersion = 1;

class GroupsConverter extends TypeConverter<List<Group>, String> {
  const GroupsConverter();

  @override
  List<Group> fromSql(String fromDb) {
    final list = json.decode(fromDb) as List;
    return list
        .map((e) => Group.fromJson(e as Map<String, Object?>))
        .toList();
  }

  @override
  String toSql(List<Group> value) {
    return json.encode(value.map((e) => e.toJson()).toList());
  }
}
