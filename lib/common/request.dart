import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

class Request {
  late final Dio dio;
  late final Dio _clashDio;
  String? userAgent;

  Request() {
    dio = Dio(BaseOptions(headers: {'User-Agent': browserUa}));
    _clashDio = Dio();
    _clashDio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.findProxy = (Uri uri) {
          client.userAgent = globalState.ua;
          return FlClashHttpOverrides.handleFindProxy(uri);
        };
        return client;
      },
    );
  }

  Future<Response<Uint8List>> getFileResponseForUrl(String url) async {
    try {
      return await _clashDio.get<Uint8List>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
    } catch (e) {
      if (e is DioException) {
        commonPrint.log(
          'network-download:error type=${e.type.name} '
          'status=${e.response?.statusCode ?? '-'}',
          logLevel: LogLevel.warning,
        );
        if (e.type == DioExceptionType.unknown) {
          throw currentAppLocalizations.unknownNetworkError;
        } else if (e.type == DioExceptionType.badResponse) {
          throw currentAppLocalizations.networkException;
        }
        rethrow;
      }
      commonPrint.log(
        'network-download:error type=${e.runtimeType}',
        logLevel: LogLevel.warning,
      );
      throw currentAppLocalizations.unknownNetworkError;
    }
  }

  Future<Response<Uint8List>> getFileResponseForUrlWithHeaders(
    String url,
    Map<String, String> headers,
  ) async {
    return _clashDio.get<Uint8List>(
      url,
      options: Options(responseType: ResponseType.bytes, headers: headers),
    );
  }

  Future<Response<String>> getTextResponseForUrl(String url) async {
    final response = await _clashDio.get<String>(
      url,
      options: Options(responseType: ResponseType.plain),
    );
    return response;
  }

  Future<MemoryImage?> getImage(String url) async {
    if (url.isEmpty) return null;
    final response = await dio.get<Uint8List>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final data = response.data;
    if (data == null) return null;
    return MemoryImage(data);
  }

  Future<Map<String, dynamic>?> checkForUpdate() async {
    final mirrorUrl = githubProxyUrl(githubUpdateApiUrl);
    final sources = <({Dio client, String url, String route})>[
      (client: _clashDio, url: githubUpdateApiUrl, route: 'official'),
      if (mirrorUrl != null) (client: dio, url: mirrorUrl, route: 'gh-proxy'),
    ];
    for (final source in sources) {
      try {
        final response = await source.client.get<Map<String, dynamic>>(
          source.url,
          options: Options(
            responseType: ResponseType.json,
            sendTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 8),
          ),
        );
        final data = response.data;
        if (response.statusCode != HttpStatus.ok || data == null) {
          continue;
        }
        commonPrint.log(
          'checkForUpdate succeeded route=${source.route}',
          logLevel: LogLevel.info,
        );
        final remoteVersion = data['tag_name']?.toString();
        if (remoteVersion == null || remoteVersion.isEmpty) return null;
        final version = globalState.packageInfo.version;
        final hasUpdate =
            utils.compareVersions(remoteVersion.replaceAll('v', ''), version) >
            0;
        if (!hasUpdate) return null;
        return data;
      } catch (_) {
        commonPrint.log(
          'checkForUpdate failed route=${source.route}',
          logLevel: LogLevel.warning,
        );
      }
    }
    return null;
  }

  Future<void> downloadUpdate({
    required String officialUrl,
    required String savePath,
    required String expectedSha256,
    ProgressCallback? onReceiveProgress,
  }) async {
    final urls = githubReleaseDownloadUrls(officialUrl);
    Object? lastError;
    for (final url in urls) {
      final mirrored = url.startsWith(githubProxyPrefix);
      try {
        final file = File(savePath);
        if (file.existsSync()) file.deleteSync();
        await (mirrored ? dio : _clashDio).download(
          url,
          savePath,
          onReceiveProgress: onReceiveProgress,
          options: Options(
            sendTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 30),
          ),
        );
        if (!await fileMatchesSha256(savePath, expectedSha256)) {
          throw StateError('APK integrity verification failed');
        }
        commonPrint.log(
          'update-download:succeeded route=${mirrored ? 'gh-proxy' : 'official'}',
          logLevel: LogLevel.info,
        );
        return;
      } catch (error) {
        lastError = error;
        final file = File(savePath);
        if (file.existsSync()) file.deleteSync();
        commonPrint.log(
          'update-download:failed route=${mirrored ? 'gh-proxy' : 'official'}',
          logLevel: LogLevel.warning,
        );
      }
    }
    throw lastError ?? StateError('No update download URL is available');
  }

  final Map<String, IpInfo Function(Map<String, dynamic>)> _ipInfoSources = {
    'https://ipwho.is': IpInfo.fromIpWhoIsJson,
    'https://api.myip.com': IpInfo.fromMyIpJson,
    'https://ipapi.co/json': IpInfo.fromIpApiCoJson,
    'https://ident.me/json': IpInfo.fromIdentMeJson,
    'http://ip-api.com/json': IpInfo.fromIpAPIJson,
    'https://api.ip.sb/geoip': IpInfo.fromIpSbJson,
    'https://ipinfo.io/json': IpInfo.fromIpInfoIoJson,
  };

  Future<Result<IpInfo?>> checkIp({CancelToken? cancelToken}) async {
    var failureCount = 0;
    final token = cancelToken ?? CancelToken();
    final futures = _ipInfoSources.entries.map((source) async {
      final Completer<Result<IpInfo?>> completer = Completer();
      void handleFailRes() {
        if (!completer.isCompleted && failureCount == _ipInfoSources.length) {
          completer.complete(Result.success(null));
        }
      }

      final future = dio
          .get<Map<String, dynamic>>(
            source.key,
            cancelToken: token,
            options: Options(responseType: ResponseType.json),
          )
          .timeout(const Duration(seconds: 10));
      future
          .then((res) {
            if (res.statusCode == HttpStatus.ok && res.data != null) {
              completer.complete(Result.success(source.value(res.data!)));
              return;
            }
            commonPrint.log('checkIp data empty', logLevel: LogLevel.info);
            failureCount++;
            handleFailRes();
          })
          .catchError((e) {
            failureCount++;
            if (e is DioException && e.type == DioExceptionType.cancel) {
              completer.complete(Result.error('cancelled'));
              return;
            }
            commonPrint.log('checkIp error $e', logLevel: LogLevel.warning);
            handleFailRes();
          });
      return completer.future;
    });
    final res = await Future.any(futures);
    token.cancel();
    return res;
  }

  Future<bool> pingHelper() async {
    if (kDebugMode) return true;
    try {
      final response = await dio
          .get(
            'http://$localhost:$helperPort/ping',
            options: Options(responseType: ResponseType.plain),
          )
          .timeout(const Duration(milliseconds: 2000));
      if (response.statusCode != HttpStatus.ok) {
        return false;
      }
      return (response.data as String) == globalState.coreSHA256;
    } catch (_) {
      return false;
    }
  }

  Future<bool> startCoreByHelper(String arg) async {
    try {
      final response = await dio
          .post(
            'http://$localhost:$helperPort/start',
            data: json.encode({'path': appPath.corePath, 'arg': arg}),
            options: Options(responseType: ResponseType.plain),
          )
          .timeout(const Duration(milliseconds: 2000));
      if (response.statusCode != HttpStatus.ok) {
        return false;
      }
      final data = response.data as String;
      return data.isEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> stopCoreByHelper() async {
    try {
      final response = await dio
          .post(
            'http://$localhost:$helperPort/stop',
            options: Options(responseType: ResponseType.plain),
          )
          .timeout(const Duration(milliseconds: 2000));
      if (response.statusCode != HttpStatus.ok) {
        return false;
      }
      final data = response.data as String;
      return data.isEmpty;
    } catch (_) {
      return false;
    }
  }
}

final request = Request();
