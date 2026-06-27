import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/models/models.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

const _builtInProxyNames = <String>{
  'DIRECT',
  'REJECT',
  'GLOBAL',
  'PASS',
  'PASS-RULE',
  'COMPATIBLE',
  'REJECT-DROP',
};

const _proxyGroupTypes = <String>{
  'select',
  'selector',
  'urltest',
  'fallback',
  'loadbalance',
  'relay',
  'passrule',
};

String _normalizeProxyType(String type) {
  return type.toLowerCase().replaceAll('-', '');
}

bool _isDirectLikeName(String name) {
  final upper = name.toUpperCase();
  return name.contains('直连') || upper.contains('DIRECT');
}

bool _isRealProxy({required String name, required String type}) {
  if (_builtInProxyNames.contains(name.toUpperCase())) return false;
  if (_isDirectLikeName(name)) return false;
  if (_proxyGroupTypes.contains(_normalizeProxyType(type))) return false;
  return true;
}

/// 从 Go 核心运行时的 flat proxies map 中提取真实代理节点。
///
/// [ProxiesData.proxies] 同时包含直接代理、provider 代理和代理组；这里按
/// 结构化 type 过滤代理组，避免从 Group.all 里用名称猜测叶节点。
List<Proxy> getLeafProxiesFromProxiesData(ProxiesData proxiesData) {
  final seen = <String>{};
  final result = <Proxy>[];
  for (final entry in proxiesData.proxies.entries) {
    final raw = entry.value;
    if (raw is! Map) continue;
    final map = Map<String, dynamic>.from(raw);
    final name = (map['name'] as String?)?.trim().isNotEmpty == true
        ? map['name'] as String
        : entry.key;
    final type = map['type'] as String? ?? '';
    if (name.isEmpty || type.isEmpty) continue;
    if (!_isRealProxy(name: name, type: type)) continue;
    if (seen.add(name)) {
      result.add(Proxy(name: name, type: type, now: map['now'] as String?));
    }
  }
  return result;
}

List<Proxy> getLeafProxiesFromConfigMap(Map<String, dynamic> configMap) {
  final clashConfig = ClashConfig.fromJson(configMap);
  final seen = <String>{};
  final result = <Proxy>[];
  for (final proxy in clashConfig.proxies) {
    if (!_isRealProxy(name: proxy.name, type: proxy.type)) continue;
    if (seen.add(proxy.name)) {
      result.add(proxy);
    }
  }
  return result;
}

/// 从当前激活 profile 的代理组数据中提取所有叶节点（不含分组）。
/// 数据来源与代理组页面一致，来自 Go 核心内存。
List<Proxy> getLeafProxiesFromGroups(List<Group> groups) {
  final groupNames = groups.map((g) => g.name).toSet();
  final seen = <String>{};
  final result = <Proxy>[];
  for (final group in groups) {
    for (final proxy in group.all) {
      // 跳过内置节点
      if (_builtInProxyNames.contains(proxy.name.toUpperCase())) continue;
      // 跳过直连相关节点
      if (_isDirectLikeName(proxy.name)) continue;
      // 跳过已知代理组类型
      if (_proxyGroupTypes.contains(_normalizeProxyType(proxy.type))) continue;
      // 跳过组间引用（如 Google、Apple 等嵌套分组）
      if (groupNames.contains(proxy.name)) continue;
      if (seen.add(proxy.name)) {
        result.add(proxy);
      }
    }
  }
  return result;
}

/// 统一节点解析器：解析 profile 的所有可用节点。
///
/// 解析顺序：
/// 1. 读取 profile 原始配置中的顶层 proxies
/// 2. 读取 proxy-providers 本地缓存文件中的 proxies
/// 3. 按 name 去重（主配置优先）
/// 4. 过滤内置节点（DIRECT/REJECT/GLOBAL 等）和代理组类型节点
Future<List<Proxy>> resolveProfileProxies(int profileId) async {
  final configMap = await coreController.getConfig(profileId);

  // ── 1. 解析主配置 proxies ─────────────────────────────────────────────
  final clashConfig = ClashConfig.fromJson(configMap);
  final proxies = <String, Proxy>{};
  for (final proxy in clashConfig.proxies) {
    proxies[proxy.name] = proxy;
  }

  // ── 2. 解析 proxy-providers ───────────────────────────────────────────
  final proxyProviders = configMap['proxy-providers'] as Map? ?? {};
  final profilePath = await appPath.getProfilePath('$profileId');
  final profileDir = p.dirname(profilePath);

  commonPrint.log(
    'resolveProfileProxies: profileId=$profileId, '
    'top-level proxies=${proxies.length}, '
    'proxy-providers count=${proxyProviders.length}',
  );

  for (final entry in proxyProviders.entries) {
    final providerName = entry.key as String;
    final provider = entry.value as Map;
    final providerUrl = provider['url'] as String?;
    final providerPathCfg = provider['path'] as String?;

    // 构造缓存文件候选路径
    final cachePaths = <String>[];
    if (providerUrl != null) {
      cachePaths.add(
        await appPath.getProvidersFilePath(
          '$profileId',
          'proxies',
          providerUrl,
        ),
      );
    }
    if (providerPathCfg != null) {
      // file 类型或处理后的 path
      cachePaths.add(
        p.isAbsolute(providerPathCfg)
            ? providerPathCfg
            : p.join(profileDir, providerPathCfg),
      );
    }

    if (cachePaths.isEmpty) {
      commonPrint.log(
        'resolveProfileProxies: provider "$providerName" has no url or path, skip',
      );
      continue;
    }

    // ── 读取 provider 缓存文件（尝试所有候选路径）──────────────────────
    String? cachePath;
    File? file;
    for (final path in cachePaths) {
      final f = File(path);
      if (await f.exists()) {
        cachePath = path;
        file = f;
        break;
      }
    }

    if (file == null) {
      commonPrint.log(
        'resolveProfileProxies: provider "$providerName" cache not found, '
        'tried: ${cachePaths.join(", ")}',
      );
      continue;
    }

    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        commonPrint.log(
          'resolveProfileProxies: provider "$providerName" cache is empty',
        );
        continue;
      }

      final doc = loadYaml(content);
      if (doc is! YamlMap) {
        commonPrint.log(
          'resolveProfileProxies: provider "$providerName" invalid yaml format',
        );
        continue;
      }

      final providerProxies = doc['proxies'];
      if (providerProxies is! YamlList) {
        commonPrint.log(
          'resolveProfileProxies: provider "$providerName" has no "proxies" key',
        );
        continue;
      }

      var addedCount = 0;
      for (final item in providerProxies) {
        if (item is! YamlMap) continue;
        final name = item['name'] as String?;
        final type = item['type'] as String?;
        if (name == null || type == null) continue;

        if (!proxies.containsKey(name)) {
          proxies[name] = Proxy(name: name, type: type);
          addedCount++;
        }
      }

      commonPrint.log(
        'resolveProfileProxies: provider "$providerName" '
        'added=$addedCount path=$cachePath',
      );
    } catch (e) {
      commonPrint.log(
        'resolveProfileProxies: failed to read provider "$providerName": $e',
      );
      continue;
    }
  }

  // ── 3. 过滤非真实节点 ─────────────────────────────────────────────────
  final realProxies = <Proxy>[];
  for (final proxy in proxies.values) {
    if (!_isRealProxy(name: proxy.name, type: proxy.type)) continue;
    realProxies.add(proxy);
  }

  commonPrint.log(
    'resolveProfileProxies: final proxies count=${realProxies.length}',
  );

  return realProxies;
}
