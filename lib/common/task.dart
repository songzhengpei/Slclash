import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';

Future<T> decodeJSONTask<T>(String data) async {
  return compute<String, T>(_decodeJSON, data);
}

Future<T> _decodeJSON<T>(String content) async {
  return json.decode(content);
}

Future<String> encodeJSONTask<T>(T data) async {
  return compute<T, String>(_encodeJSON, data);
}

Future<String> _encodeJSON<T>(T content) async {
  return json.encode(content);
}

Future<String> encodeYamlTask<T>(T data) async {
  return compute<T, String>(_encodeYaml, data);
}

Future<String> _encodeYaml<T>(T content) async {
  return yaml.encode(content);
}

Future<String> encodeMD5Task(String data) async {
  return compute<String, String>(_encodeMD5, data);
}

Future<String> _encodeMD5<T>(String content) async {
  return content.toMd5();
}

Future<List<Group>> toGroupsTask(ComputeGroupsState data) async {
  return compute<ComputeGroupsState, List<Group>>(_toGroupsTask, data);
}

Future<List<Group>> _toGroupsTask(ComputeGroupsState state) async {
  final proxiesData = state.proxiesData;
  final all = proxiesData.all;
  final sortType = state.sortType;
  final delayMap = state.delayMap;
  final selectedMap = state.selectedMap;
  final defaultTestUrl = state.defaultTestUrl;
  final proxies = proxiesData.proxies;
  if (proxies.isEmpty) return [];
  final groupsRaw = all
      .where((name) {
        final proxy = proxies[name] ?? {};
        return GroupTypeExtension.valueList.contains(proxy['type']);
      })
      .map((groupName) {
        final group = proxies[groupName];
        group['all'] = ((group['all'] ?? []) as List)
            .map((name) => proxies[name])
            .where((proxy) => proxy != null)
            .toList();
        return group;
      })
      .toList();
  final groups = groupsRaw.map((e) => Group.fromJson(e)).toList();
  return computeSort(
    groups: groups,
    sortType: sortType,
    delayMap: delayMap,
    selectedMap: selectedMap,
    defaultTestUrl: defaultTestUrl,
  );
}

Future<VM2<String, String>> makeRealProfileTask(
  MakeRealProfileState data,
) async {
  return compute<MakeRealProfileState, VM2<String, String>>(
    _makeRealProfileTask,
    data,
  );
}

Future<VM2<String, String>> _makeRealProfileTask(
  MakeRealProfileState data,
) async {
  final rawConfig = Map.from(data.rawConfig);
  final realPatchConfig = data.realPatchConfig;
  final profilesPath = data.profilesPath;
  final profileId = data.profileId;
  final overrideDns = data.overrideDns;
  final addedRules = data.addedRules;
  final appendSystemDns = data.appendSystemDns;
  final defaultUA = data.defaultUA;
  String getProvidersFilePathInner(String type, String url) {
    return join(
      profilesPath,
      'providers',
      profileId.toString(),
      type,
      url.toMd5(),
    );
  }

  rawConfig['external-controller'] = realPatchConfig.externalController.value;
  rawConfig['external-ui'] = '';
  rawConfig['interface-name'] = '';
  rawConfig['external-ui-url'] = '';
  rawConfig['tcp-concurrent'] = realPatchConfig.tcpConcurrent;
  rawConfig['unified-delay'] = realPatchConfig.unifiedDelay;
  rawConfig['ipv6'] = realPatchConfig.ipv6;
  rawConfig['log-level'] = realPatchConfig.logLevel.name;
  rawConfig['port'] = 0;
  rawConfig['socks-port'] = 0;
  rawConfig['keep-alive-interval'] = realPatchConfig.keepAliveInterval;
  rawConfig['mixed-port'] = realPatchConfig.mixedPort;
  rawConfig['port'] = realPatchConfig.port;
  rawConfig['socks-port'] = realPatchConfig.socksPort;
  rawConfig['redir-port'] = realPatchConfig.redirPort;
  rawConfig['tproxy-port'] = realPatchConfig.tproxyPort;
  rawConfig['find-process-mode'] = realPatchConfig.findProcessMode.name;
  rawConfig['allow-lan'] = realPatchConfig.allowLan;
  rawConfig['mode'] = realPatchConfig.mode.name;
  if (rawConfig['tun'] == null) {
    rawConfig['tun'] = {};
  }
  rawConfig['tun']['enable'] = realPatchConfig.tun.enable;
  rawConfig['tun']['device'] = realPatchConfig.tun.device;
  rawConfig['tun']['dns-hijack'] = realPatchConfig.tun.dnsHijack;
  rawConfig['tun']['stack'] = realPatchConfig.tun.stack.name;
  rawConfig['tun']['route-address'] = realPatchConfig.tun.routeAddress;
  rawConfig['tun']['auto-route'] = realPatchConfig.tun.autoRoute;
  rawConfig['geodata-loader'] = realPatchConfig.geodataLoader.name;
  if (rawConfig['sniffer']?['sniff'] != null) {
    for (final value in (rawConfig['sniffer']?['sniff'] as Map).values) {
      if (value['ports'] != null && value['ports'] is List) {
        value['ports'] =
            value['ports']?.map((item) => item.toString()).toList() ?? [];
      }
    }
  }
  if (rawConfig['profile'] == null) {
    rawConfig['profile'] = {};
  }
  if (rawConfig['proxy-providers'] != null) {
    final proxyProviders = rawConfig['proxy-providers'] as Map;
    for (final key in proxyProviders.keys) {
      final proxyProvider = proxyProviders[key];
      if (proxyProvider['type'] != 'http') {
        continue;
      }
      if (proxyProvider['url'] != null) {
        proxyProvider['path'] = getProvidersFilePathInner(
          'proxies',
          proxyProvider['url'],
        );
      }
    }
  }
  if (rawConfig['rule-providers'] != null) {
    final ruleProviders = rawConfig['rule-providers'] as Map;
    for (final key in ruleProviders.keys) {
      final ruleProvider = ruleProviders[key];
      if (ruleProvider['type'] != 'http') {
        continue;
      }
      if (ruleProvider['url'] != null) {
        ruleProvider['path'] = getProvidersFilePathInner(
          'rules',
          ruleProvider['url'],
        );
      }
    }
  }
  rawConfig['profile']['store-selected'] = false;
  rawConfig['geox-url'] = realPatchConfig.geoXUrl.toJson();
  rawConfig['global-ua'] = realPatchConfig.globalUa ?? defaultUA;
  if (rawConfig['hosts'] == null) {
    rawConfig['hosts'] = {};
  }
  for (final host in realPatchConfig.hosts.entries) {
    rawConfig['hosts'][host.key] = host.value.splitByMultipleSeparators;
  }
  if (rawConfig['dns'] == null) {
    rawConfig['dns'] = {};
  }
  final isEnableDns = rawConfig['dns']['enable'] == true;
  const systemDns = 'system://';
  if (overrideDns || !isEnableDns) {
    final dns = switch (!isEnableDns) {
      true => realPatchConfig.dns.copyWith(
        nameserver: [...realPatchConfig.dns.nameserver, systemDns],
      ),
      false => realPatchConfig.dns,
    };
    rawConfig['dns'] = dns.toJson();
    rawConfig['dns']['nameserver-policy'] = {};
    for (final entry in dns.nameserverPolicy.entries) {
      rawConfig['dns']['nameserver-policy'][entry.key] =
          entry.value.splitByMultipleSeparators;
    }
  }
  if (appendSystemDns) {
    final List<String> nameserver = List<String>.from(
      rawConfig['dns']['nameserver'] ?? [],
    );
    if (!nameserver.contains(systemDns)) {
      rawConfig['dns']['nameserver'] = [...nameserver, systemDns];
    }
  }
  List<String> rules = [];
  if (data.rules.isEmpty) {
    if (rawConfig['rules'] != null) {
      rules = List<String>.from(rawConfig['rules']);
    }
    if (addedRules.isNotEmpty) {
      final hasMatchPlaceholder = addedRules.any(
        (item) => item.ruleTarget?.toUpperCase() == 'MATCH',
      );
      String? replacementTarget;

      if (hasMatchPlaceholder) {
        for (int i = rules.length - 1; i >= 0; i--) {
          final parsed = Rule.parse(rules[i]);
          if (parsed.ruleAction == RuleAction.MATCH) {
            final target = parsed.ruleTarget;
            if (target != null && target.isNotEmpty) {
              replacementTarget = target;
              break;
            }
          }
        }
      }
      final List<String> finalAddedRules;

      if (replacementTarget?.isNotEmpty == true) {
        finalAddedRules = [];
        for (int i = 0; i < addedRules.length; i++) {
          final parsed = addedRules[i];
          if (parsed.ruleTarget?.toUpperCase() == 'MATCH') {
            finalAddedRules.add(
              parsed.copyWith(ruleTarget: replacementTarget).rawValue,
            );
          } else {
            finalAddedRules.add(addedRules[i].rawValue);
          }
        }
      } else {
        finalAddedRules = addedRules.map((e) => e.rawValue).toList();
      }
      rules = [...finalAddedRules, ...rules];
    }
  } else {
    rules = data.rules.map((item) => item.rawValue).toList();
  }
  if (data.proxyGroups.isNotEmpty) {
    rawConfig['proxy-groups'] = data.proxyGroups;
  }
  rawConfig['rules'] = rules;
  final yaml = await _encodeYaml(Map<String, dynamic>.from(rawConfig));
  return VM2(yaml, yaml.toMd5());
}

Future<List<String>> shakingProfileTask(
  VM2<Iterable<int>, Iterable<int>> data,
) async {
  return compute<
    VM3<Iterable<int>, Iterable<int>, RootIsolateToken>,
    List<String>
  >(_shakingProfileTask, VM3(data.a, data.b, RootIsolateToken.instance!));
}

Future<List<String>> _shakingProfileTask(
  VM3<Iterable<int>, Iterable<int>, RootIsolateToken> data,
) async {
  final profileIds = data.a;
  final scriptIds = data.b;
  final token = data.c;
  BackgroundIsolateBinaryMessenger.ensureInitialized(token);
  final profilesDir = Directory(await appPath.profilesPath);
  final scriptsDir = Directory(await appPath.scriptsDirPath);
  final providersDir = Directory(await appPath.getProvidersRootPath());
  final List<String> targets = [];
  void scanDirectory(
    Directory dir,
    Iterable<int> baseNames, {
    bool skipProvidersFolder = false,
  }) {
    if (!dir.existsSync()) return;
    final entities = dir.listSync(recursive: false, followLinks: false);

    for (final entity in entities) {
      if (entity is File) {
        final id = basenameWithoutExtension(entity.path);
        if (!baseNames.contains(int.tryParse(id))) {
          targets.add(entity.path);
        }
      } else if (skipProvidersFolder && entity is Directory) {
        if (basename(entity.path) == 'providers') {
          continue;
        }
      }
    }
  }

  scanDirectory(profilesDir, profileIds, skipProvidersFolder: true);
  scanDirectory(providersDir, profileIds);
  scanDirectory(scriptsDir, scriptIds);
  return targets;
}

Future<String> encodeLogsTask(List<Log> data) async {
  return compute<List<Log>, String>(_encodeLogsTask, data);
}

Future<String> _encodeLogsTask(List<Log> data) async {
  final logsRaw = data.map((item) => item.toString());
  final logsRawString = logsRaw.join('\n');
  return logsRawString;
}

Future<MigrationData> oldToNowTask(Map<String, Object?> data) async {
  final homeDir = await appPath.homeDirPath;
  return compute<VM3<Map<String, Object?>, String, String>, MigrationData>(
    _oldToNowTask,
    VM3(data, homeDir, homeDir),
  );
}

Future<MigrationData> _oldToNowTask(
  VM3<Map<String, Object?>, String, String> data,
) async {
  final configMap = data.a;
  final sourcePath = data.b;
  final targetPath = data.c;

  final accessControlMap = configMap['accessControl'];
  final isAccessControl = configMap['isAccessControl'];
  if (accessControlMap != null) {
    (accessControlMap as Map)['enable'] = isAccessControl;
    if (configMap['vpnProps'] != null) {
      final vpnPropsRaw = configMap['vpnProps'] as Map;
      vpnPropsRaw['accessControl'] = accessControlMap;
    }
  }
  if (configMap['vpnProps'] != null) {
    final vpnPropsRaw = configMap['vpnProps'] as Map;
    vpnPropsRaw['accessControlProps'] = vpnPropsRaw['accessControl'];
  }
  configMap['davProps'] = configMap['dav'];
  final appSettingProps =
      configMap['appSetting'] as Map<String, dynamic>? ?? {};
  appSettingProps['restoreStrategy'] = appSettingProps['recoveryStrategy'];
  configMap['appSettingProps'] = appSettingProps;
  configMap['proxiesStyleProps'] = configMap['proxiesStyle'];
  configMap['proxiesStyleProps'] = configMap['proxiesStyle'];
  // final overwriteMap = configMap['overwrite'] as Map? ?? {};
  // configMap['overwriteType'] = overwriteMap['type'];
  // configMap['scriptId'] = overwriteMap['scriptOverwrite'];
  List rawScripts = configMap['scripts'] as List<dynamic>? ?? [];
  if (rawScripts.isEmpty) {
    final scriptPropsJson = configMap['scriptProps'] as Map<String, dynamic>?;
    if (scriptPropsJson != null) {
      rawScripts = scriptPropsJson['scripts'] as List<dynamic>? ?? [];
    }
  }
  final Map<String, int> idMap = {};
  final List<Script> scripts = [];
  for (final rawScript in rawScripts) {
    final id = rawScript['id'] as String?;
    final content = rawScript['content'] as String?;
    final label = rawScript['label'] as String?;
    if (id == null || content == null || label == null) {
      continue;
    }
    final newId = idMap.updateCacheValue(rawScript['id'], () => snowflake.id);
    final path = _getScriptPath(targetPath, newId.toString());
    final file = File(path);
    await file.safeWriteAsString(content);
    scripts.add(
      Script(id: newId, label: label, lastUpdateTime: DateTime.now()),
    );
  }
  final List rawRules = configMap['rules'] as List<dynamic>? ?? [];
  final List<Rule> rules = [];
  final List<ProfileRuleLink> links = [];
  for (final rawRule in rawRules) {
    final id = idMap.updateCacheValue(rawRule['id'], () => snowflake.id);
    rawRule['id'] = id;
    final value = rawRule['value'] ?? '';
    rules.add(Rule.parse(value, id: id));
    links.add(ProfileRuleLink(ruleId: id));
  }
  final List rawProfiles = configMap['profiles'] as List<dynamic>? ?? [];
  final List<Profile> profiles = [];
  for (final rawProfile in rawProfiles) {
    final rawId = rawProfile['id'] as String?;
    if (rawId == null) {
      continue;
    }
    final profileId = idMap.updateCacheValue(rawId, () => snowflake.id);
    rawProfile['id'] = profileId;
    final overwrite = rawProfile['overwrite'] as Map?;
    if (overwrite != null) {
      final standardOverwrite = overwrite['standardOverwrite'] as Map?;
      if (standardOverwrite != null) {
        final addedRules = standardOverwrite['addedRules'] as List? ?? [];
        for (final addRule in addedRules) {
          final id = idMap.updateCacheValue(addRule['id'], () => snowflake.id);
          final value = addRule['value'] ?? '';
          rules.add(Rule.parse(value, id: id));
          links.add(
            ProfileRuleLink(
              profileId: profileId,
              ruleId: id,
              scene: RuleScene.added,
            ),
          );
        }
        final disabledRuleIds = standardOverwrite['disabledRuleIds'] as List?;
        if (disabledRuleIds != null) {
          for (final disabledRuleId in disabledRuleIds) {
            final newDisabledRuleId = idMap[disabledRuleId];
            if (newDisabledRuleId != null) {
              links.add(
                ProfileRuleLink(
                  profileId: profileId,
                  ruleId: newDisabledRuleId,
                  scene: RuleScene.disabled,
                ),
              );
            }
          }
        }
      }
      final scriptOverwrite = overwrite['scriptOverwrite'] as Map?;
      if (scriptOverwrite != null) {
        final scriptId = scriptOverwrite['scriptId'] as String?;
        rawProfile['scriptId'] = scriptId != null ? idMap[scriptId] : null;
      }
      rawProfile['overwriteType'] = overwrite['type'];
    }

    final sourceFile = File(_getProfilePath(sourcePath, rawId));
    final targetFilePath = _getProfilePath(targetPath, profileId.toString());
    await sourceFile.safeCopy(targetFilePath);
    profiles.add(Profile.fromJson(rawProfile));
  }
  final currentProfileId = configMap['currentProfileId'];
  configMap['currentProfileId'] = currentProfileId != null
      ? idMap[currentProfileId]
      : null;
  return MigrationData(
    configMap: configMap,
    profiles: profiles,
    rules: rules,
    scripts: scripts,
    links: links,
  );
}

Future<String> backupTask(
  Map<String, dynamic> configMap,
  Iterable<String> fileNames,
) async {
  return compute<
    VM3<Map<String, dynamic>, Iterable<String>, RootIsolateToken>,
    String
  >(_backupTask, VM3(configMap, fileNames, RootIsolateToken.instance!));
}

Future<String> _backupTask<T>(
  VM3<Map<String, dynamic>, Iterable<String>, RootIsolateToken> args,
) async {
  final configMap = args.a;
  final fileNames = args.b;
  final token = args.c;
  BackgroundIsolateBinaryMessenger.ensureInitialized(token);
  final dbPath = await appPath.databasePath;
  final configStr = json.encode(configMap);
  final profilesDir = Directory(await appPath.profilesPath);
  final scriptsDir = Directory(await appPath.scriptsDirPath);
  final tempZipFilePath = await appPath.tempFilePath;
  final tempDBFile = File(await appPath.tempFilePath);
  final tempConfigFile = File(await appPath.tempFilePath);
  final dbFile = File(dbPath);
  if (await dbFile.exists()) {
    await dbFile.copy(tempDBFile.path);
  }
  final encoder = ZipFileEncoder();
  encoder.create(tempZipFilePath);
  await tempConfigFile.writeAsString(configStr);
  await encoder.addFile(tempDBFile, backupDatabaseName);
  await encoder.addFile(tempConfigFile, configJsonName);
  if (await profilesDir.exists()) {
    await encoder.addDirectory(
      profilesDir,
      filter: (file, _) {
        if (!fileNames.contains(basename(file.path))) {
          return ZipFileOperation.skip;
        }
        return ZipFileOperation.include;
      },
    );
  }
  if (await scriptsDir.exists()) {
    await encoder.addDirectory(
      scriptsDir,
      filter: (file, _) {
        if (!fileNames.contains(basename(file.path))) {
          return ZipFileOperation.skip;
        }
        return ZipFileOperation.include;
      },
    );
  }
  encoder.close();
  await tempConfigFile.safeDelete();
  await tempDBFile.safeDelete();
  return tempZipFilePath;
}

Future<MigrationData> restoreTask() async {
  return compute<RootIsolateToken, MigrationData>(
    _restoreTask,
    RootIsolateToken.instance!,
  );
}

Future<MigrationData> _restoreTask(RootIsolateToken token) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(token);
  final backupFilePath = await appPath.backupFilePath;
  final restoreDirPath = await appPath.restoreDirPath;
  final homeDirPath = await appPath.homeDirPath;
  final zipDecoder = ZipDecoder();
  final input = InputFileStream(backupFilePath);
  final archive = zipDecoder.decodeStream(input);
  final dir = Directory(restoreDirPath);
  await dir.create(recursive: true);
  for (final file in archive.files) {
    final outPath = join(restoreDirPath, posix.normalize(file.name));
    final outputStream = OutputFileStream(outPath);
    file.writeContent(outputStream);
    await outputStream.close();
  }
  await input.close();
  final restoreConfigFile = File(join(restoreDirPath, configJsonName));
  if (!await restoreConfigFile.exists()) {
    throw currentAppLocalizations.invalidBackupFile;
  }
  final restoreConfigMap =
      json.decode(await restoreConfigFile.readAsString())
          as Map<String, Object?>?;
  final version = restoreConfigMap?['version'] ?? 0;
  MigrationData migrationData = MigrationData(configMap: restoreConfigMap);
  if (version == 0 && restoreConfigMap != null) {
    migrationData = await _oldToNowTask(
      VM3(restoreConfigMap, restoreDirPath, homeDirPath),
    );
    return migrationData;
  }
  final backupDatabaseFile = File(join(restoreDirPath, backupDatabaseName));
  if (!await backupDatabaseFile.exists()) {
    return migrationData;
  }
  final database = Database(
    driftDatabase(
      name: 'database',
      native: DriftNativeOptions(
        databaseDirectory: () async => Directory(restoreDirPath),
      ),
    ),
  );
  final results = await Future.wait([
    database.profilesDao.query().get(),
    database.scriptsDao.query().get(),
    database.rules.all().map((item) => item.toRule()).get(),
    database.profileRuleLinks.all().map((item) => item.toLink()).get(),
    database.proxyGroups.all().map((item) => item.toProxyGroup()).get(),
  ]);
  final profiles = results[0].cast<Profile>();
  final scripts = results[1].cast<Script>();
  final profilesMigration = profiles.map(
    (item) => VM2(
      _getProfilePath(restoreDirPath, item.id.toString()),
      _getProfilePath(homeDirPath, item.id.toString()),
    ),
  );
  final scriptsMigration = scripts.map(
    (item) => VM2(
      _getScriptPath(restoreDirPath, item.id.toString()),
      _getScriptPath(homeDirPath, item.id.toString()),
    ),
  );
  await _copyWithMapList([...profilesMigration, ...scriptsMigration]);
  migrationData = migrationData.copyWith(
    profiles: profiles,
    scripts: scripts,
    rules: results[2].cast<Rule>(),
    links: results[3].cast<ProfileRuleLink>(),
    proxyGroups: results[4].cast<ProxyGroup>(),
  );
  await database.close();
  return migrationData;
}

Future<void> _copyWithMapList(List<VM2<String, String>> copyMapList) async {
  await Future.wait(
    copyMapList.map((item) => File(item.a).safeCopy(item.b)).toList(),
  );
}

String _getScriptPath(String root, String fileName) {
  return join(root, 'scripts', '$fileName.js');
}

String _getProfilePath(String root, String fileName) {
  return join(root, 'profiles', '$fileName.yaml');
}

// --- Profiles-only backup/restore ---

class ProfilesBackupMetadata {
  final String backupType;
  final String createdAt;
  final String appVersion;
  final int? currentProfileId;
  final List<Map<String, dynamic>> profiles;
  final List<Map<String, dynamic>>? scripts;
  final List<Map<String, dynamic>>? rules;
  final List<Map<String, dynamic>>? links;
  final List<Map<String, dynamic>>? proxyGroups;
  final Map<String, dynamic>? config;

  ProfilesBackupMetadata({
    required this.backupType,
    required this.createdAt,
    required this.appVersion,
    required this.currentProfileId,
    required this.profiles,
    this.scripts,
    this.rules,
    this.links,
    this.proxyGroups,
    this.config,
  });

  Map<String, dynamic> toJson() => {
    'backupType': backupType,
    'createdAt': createdAt,
    'appVersion': appVersion,
    'currentProfileId': currentProfileId,
    'profiles': profiles,
    if (scripts != null) 'scripts': scripts,
    if (rules != null) 'rules': rules,
    if (links != null) 'links': links,
    if (proxyGroups != null) 'proxyGroups': proxyGroups,
    if (config != null) 'config': config,
  };

  factory ProfilesBackupMetadata.fromJson(Map<String, dynamic> json) {
    return ProfilesBackupMetadata(
      backupType: json['backupType'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      appVersion: json['appVersion'] as String? ?? '',
      currentProfileId: json['currentProfileId'] as int?,
      profiles:
          (json['profiles'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      scripts: (json['scripts'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      rules: (json['rules'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      links: (json['links'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      proxyGroups: (json['proxyGroups'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      config: json['config'] is Map
          ? Map<String, dynamic>.from(json['config'] as Map)
          : null,
    );
  }
}

Future<String> backupProfilesOnlyTask(
  Map<String, dynamic> backupPayload,
  int? currentProfileId,
  String appVersion,
) async {
  return compute<
    VM4<Map<String, dynamic>, int?, String, RootIsolateToken>,
    String
  >(
    _backupProfilesOnlyTask,
    VM4(
      backupPayload,
      currentProfileId,
      appVersion,
      RootIsolateToken.instance!,
    ),
  );
}

Future<String> _backupProfilesOnlyTask(
  VM4<Map<String, dynamic>, int?, String, RootIsolateToken> args,
) async {
  final backupPayload = args.a;
  final currentProfileId = args.b;
  final appVersion = args.c;
  final token = args.d;
  BackgroundIsolateBinaryMessenger.ensureInitialized(token);

  final profilesJson = (backupPayload['profiles'] as List)
      .cast<Map<String, dynamic>>();
  final yamlFileNames = (backupPayload['yamlFileNames'] as List).cast<String>();
  final jsFileNames = (backupPayload['jsFileNames'] as List?)?.cast<String>();
  final scripts = (backupPayload['scripts'] as List?)
      ?.cast<Map<String, dynamic>>();
  final rules = (backupPayload['rules'] as List?)?.cast<Map<String, dynamic>>();
  final links = (backupPayload['links'] as List?)?.cast<Map<String, dynamic>>();
  final proxyGroups = (backupPayload['proxyGroups'] as List?)
      ?.cast<Map<String, dynamic>>();
  final config = backupPayload['config'] as Map<String, dynamic>?;

  final profilesDir = Directory(await appPath.profilesPath);
  final scriptsDir = Directory(await appPath.scriptsDirPath);
  final tempZipFilePath = await appPath.tempFilePath;
  final tempMetaFile = File(await appPath.tempFilePath);

  final isV2 =
      scripts != null || rules != null || links != null || proxyGroups != null;
  final metadata = ProfilesBackupMetadata(
    backupType: isV2 ? profilesBackupTypeV2 : profilesBackupType,
    createdAt: DateTime.now().toUtc().toIso8601String(),
    appVersion: appVersion,
    currentProfileId: currentProfileId,
    profiles: profilesJson,
    scripts: isV2 ? scripts : null,
    rules: isV2 ? rules : null,
    links: isV2 ? links : null,
    proxyGroups: isV2 ? proxyGroups : null,
    config: isV2 ? config : null,
  );
  await tempMetaFile.writeAsString(json.encode(metadata.toJson()));

  final encoder = ZipFileEncoder();
  encoder.create(tempZipFilePath);
  await encoder.addFile(tempMetaFile, profilesBackupMetadataName);
  if (await profilesDir.exists()) {
    await encoder.addDirectory(
      profilesDir,
      filter: (file, _) {
        if (yamlFileNames.contains(basename(file.path))) {
          return ZipFileOperation.include;
        }
        return ZipFileOperation.skip;
      },
    );
  }

  // v2: Add provider cache files for all backed-up profile IDs
  if (isV2) {
    final profileIds = profilesJson
        .map((p) => p['id'])
        .whereType<int>()
        .map((id) => id.toString())
        .toSet();
    for (final id in profileIds) {
      final profileProvidersDir = Directory(
        join(profilesDir.path, 'providers', id),
      );
      if (!await profileProvidersDir.exists()) continue;
      await for (final entity in profileProvidersDir.list(recursive: true)) {
        if (entity is File) {
          final relPath = relative(entity.path, from: profilesDir.path);
          await encoder.addFile(entity, join('profiles', relPath));
        }
      }
    }
  }

  // v2: Add script files for IDs in jsFileNames
  if (isV2 && jsFileNames != null && jsFileNames.isNotEmpty) {
    if (await scriptsDir.exists()) {
      await for (final entity in scriptsDir.list()) {
        if (entity is File && entity.path.endsWith('.js')) {
          final base = basename(entity.path);
          if (jsFileNames.contains(base)) {
            await encoder.addFile(entity, join('scripts', base));
          }
        }
      }
    }
  }

  encoder.close();
  await tempMetaFile.safeDelete();
  return tempZipFilePath;
}

class ProfilesRestoreData {
  final int? currentProfileId;
  final List<Map<String, dynamic>> profiles;
  final List<Map<String, dynamic>>? scripts;
  final List<Map<String, dynamic>>? rules;
  final List<Map<String, dynamic>>? links;
  final String backupType;

  bool get isV2 => backupType == profilesBackupTypeV2;

  ProfilesRestoreData({
    required this.currentProfileId,
    required this.profiles,
    required this.backupType,
    this.scripts,
    this.rules,
    this.links,
  });
}

Future<ProfilesRestoreData> restoreProfilesOnlyTask() async {
  return compute<RootIsolateToken, ProfilesRestoreData>(
    _restoreProfilesOnlyTask,
    RootIsolateToken.instance!,
  );
}

Future<ProfilesRestoreData> _restoreProfilesOnlyTask(
  RootIsolateToken token,
) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(token);
  final backupFilePath = await appPath.backupFilePath;
  final restoreDirPath = await appPath.restoreDirPath;
  final homeDirPath = await appPath.homeDirPath;

  final zipDecoder = ZipDecoder();
  final input = InputFileStream(backupFilePath);
  final archive = zipDecoder.decodeStream(input);
  final dir = Directory(restoreDirPath);
  await dir.create(recursive: true);
  for (final file in archive.files) {
    // Zip path safety: prevent path traversal
    final normalizedName = normalize(file.name);
    if (normalizedName.contains('..')) {
      throw FormatException(
        'Security: path traversal detected in backup: ${file.name}',
      );
    }
    final root = absolute(normalize(restoreDirPath));
    final outPath = absolute(normalize(join(root, normalizedName)));
    if (!equals(root, outPath) && !isWithin(root, outPath)) {
      throw FormatException(
        'Security: resolved path outside restore dir: ${file.name}',
      );
    }
    final outputStream = OutputFileStream(outPath);
    file.writeContent(outputStream);
    await outputStream.close();
  }
  await input.close();

  // Try new format first
  final metadataFile = File(join(restoreDirPath, profilesBackupMetadataName));
  if (await metadataFile.exists()) {
    final metadataMap =
        json.decode(await metadataFile.readAsString()) as Map<String, dynamic>;
    final backupType = metadataMap['backupType'] as String? ?? '';
    if (backupType == profilesBackupType ||
        backupType == profilesBackupTypeV2) {
      final metadata = ProfilesBackupMetadata.fromJson(metadataMap);
      final isV2 = backupType == profilesBackupTypeV2;
      // Copy yaml files
      final restoreProfilesDir = join(restoreDirPath, profilesBackupDirName);
      if (await Directory(restoreProfilesDir).exists()) {
        final targetProfilesDir = Directory(await appPath.profilesPath);
        if (!await targetProfilesDir.exists()) {
          await targetProfilesDir.create(recursive: true);
        }
        await for (final file in Directory(restoreProfilesDir).list()) {
          if (file is File && file.path.endsWith('.yaml')) {
            final targetPath = join(
              targetProfilesDir.path,
              basename(file.path),
            );
            await file.safeCopy(targetPath);
          }
        }
      }
      // v2: Restore provider cache files
      if (isV2) {
        final restoreProvidersDir = join(restoreProfilesDir, 'providers');
        if (await Directory(restoreProvidersDir).exists()) {
          final targetProvidersDir = Directory(
            await appPath.getProvidersRootPath(),
          );
          if (!await targetProvidersDir.exists()) {
            await targetProvidersDir.create(recursive: true);
          }
          await for (final f in Directory(
            restoreProvidersDir,
          ).list(recursive: true)) {
            if (f is File) {
              final rel = relative(f.path, from: restoreProvidersDir);
              final t = join(targetProvidersDir.path, rel);
              await Directory(dirname(t)).create(recursive: true);
              await f.copy(t);
            }
          }
        }
      }
      // v2: Restore script files
      if (isV2) {
        final restoreScriptsDir = join(restoreDirPath, scriptsBackupDirName);
        if (await Directory(restoreScriptsDir).exists()) {
          final targetScriptsDir = Directory(await appPath.scriptsDirPath);
          if (!await targetScriptsDir.exists()) {
            await targetScriptsDir.create(recursive: true);
          }
          await for (final f in Directory(restoreScriptsDir).list()) {
            if (f is File && f.path.endsWith('.js')) {
              await f.copy(join(targetScriptsDir.path, basename(f.path)));
            }
          }
        }
      }
      return ProfilesRestoreData(
        currentProfileId: metadata.currentProfileId,
        profiles: metadata.profiles,
        backupType: backupType,
        scripts: isV2 ? metadata.scripts : null,
        rules: isV2 ? metadata.rules : null,
        links: isV2 ? metadata.links : null,
      );
    }
  }

  // Fallback: old format with database.sqlite
  final backupDatabaseFile = File(join(restoreDirPath, backupDatabaseName));
  if (await backupDatabaseFile.exists()) {
    final database = Database(
      driftDatabase(
        name: 'database',
        native: DriftNativeOptions(
          databaseDirectory: () async => Directory(restoreDirPath),
        ),
      ),
    );
    final profiles = await database.profilesDao.query().get();
    // Copy yaml files
    final profilesMigration = profiles.map(
      (item) => VM2(
        _getProfilePath(restoreDirPath, item.id.toString()),
        _getProfilePath(homeDirPath, item.id.toString()),
      ),
    );
    await Future.wait(
      profilesMigration.map((item) => File(item.a).safeCopy(item.b)).toList(),
    );
    // Extract currentProfileId from config.json if present
    int? currentProfileId;
    final configFile = File(join(restoreDirPath, configJsonName));
    if (await configFile.exists()) {
      try {
        final configMap =
            json.decode(await configFile.readAsString())
                as Map<String, dynamic>;
        currentProfileId = configMap['currentProfileId'] as int?;
      } catch (_) {}
    }
    await database.close();
    return ProfilesRestoreData(
      currentProfileId: currentProfileId,
      profiles: profiles.map((p) => p.toJson()).toList(),
      backupType: '',
    );
  }

  // Fallback: oldest format with config.json only
  final configFile = File(join(restoreDirPath, configJsonName));
  if (await configFile.exists()) {
    final configMap =
        json.decode(await configFile.readAsString()) as Map<String, dynamic>;
    final rawProfiles =
        (configMap['profiles'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final currentProfileId = configMap['currentProfileId'] as int?;
    // Copy yaml files from restore dir
    final restoreProfilesDir = Directory(join(restoreDirPath, 'profiles'));
    if (await restoreProfilesDir.exists()) {
      final targetProfilesDir = Directory(await appPath.profilesPath);
      if (!await targetProfilesDir.exists()) {
        await targetProfilesDir.create(recursive: true);
      }
      await for (final file in restoreProfilesDir.list()) {
        if (file is File && file.path.endsWith('.yaml')) {
          final targetPath = join(targetProfilesDir.path, basename(file.path));
          await file.safeCopy(targetPath);
        }
      }
    }
    return ProfilesRestoreData(
      currentProfileId: currentProfileId,
      profiles: rawProfiles,
      backupType: '',
    );
  }

  throw 'Invalid backup file';
}

Future<List<T>> mapListTask<T, S>(List<S> results, T Function(S) mapper) async {
  return compute<VM2<List<S>, T Function(S)>, List<T>>(
    _mapListTask,
    VM2(results, mapper),
  );
}

Future<List<T>> _mapListTask<T, S>(VM2<List<S>, T Function(S)> vm2) async {
  final results = vm2.a;
  final mapper = vm2.b;
  return results.map((item) => mapper(item)).toList();
}
