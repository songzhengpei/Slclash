import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/models/models.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

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

    // 构造缓存文件路径
    String? cachePath;
    if (providerUrl != null) {
      cachePath = await appPath.getProvidersFilePath(
        '$profileId',
        'proxies',
        providerUrl,
      );
    } else if (providerPathCfg != null) {
      // file 类型 provider，使用配置中 path
      cachePath = p.isAbsolute(providerPathCfg)
          ? providerPathCfg
          : p.join(profileDir, providerPathCfg);
    }

    if (cachePath == null) {
      commonPrint.log(
        'resolveProfileProxies: provider "$providerName" has no url or path, skip',
      );
      continue;
    }

    // ── 读取 provider 缓存文件 ───────────────────────────────────────────
    final file = File(cachePath);
    if (!await file.exists()) {
      commonPrint.log(
        'resolveProfileProxies: provider "$providerName" cache not found at $cachePath',
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
  const builtInNodes = <String>{
    'DIRECT', 'REJECT', 'GLOBAL', 'PASS', 'COMPATIBLE', 'REJECT-DROP',
  };
  const groupTypes = <String>{
    'select', 'selector', 'url-test', 'urltest',
    'fallback', 'load-balance', 'loadbalance', 'relay',
  };

  final realProxies = <Proxy>[];
  for (final proxy in proxies.values) {
    if (builtInNodes.contains(proxy.name.toUpperCase())) continue;
    if (groupTypes.contains(proxy.type.toLowerCase())) continue;
    realProxies.add(proxy);
  }

  commonPrint.log(
    'resolveProfileProxies: final proxies count=${realProxies.length}',
  );

  return realProxies;
}
