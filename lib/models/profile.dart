import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/services/profile_source_mutation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:path/path.dart' as p;

part 'generated/profile.freezed.dart';
part 'generated/profile.g.dart';

@freezed
abstract class SubscriptionInfo with _$SubscriptionInfo {
  const factory SubscriptionInfo({
    @Default(0) int upload,
    @Default(0) int download,
    @Default(0) int total,
    @Default(0) int expire,
  }) = _SubscriptionInfo;

  factory SubscriptionInfo.fromJson(Map<String, Object?> json) =>
      _$SubscriptionInfoFromJson(json);

  factory SubscriptionInfo.formHString(String? info) {
    if (info == null) return const SubscriptionInfo();
    final list = info.split(';');
    final Map<String, int?> map = {};
    for (final i in list) {
      final keyValue = i.trim().split('=');
      map[keyValue[0]] = int.tryParse(keyValue[1]);
    }
    return SubscriptionInfo(
      upload: map['upload'] ?? 0,
      download: map['download'] ?? 0,
      total: map['total'] ?? 0,
      expire: map['expire'] ?? 0,
    );
  }
}

@freezed
abstract class Profile with _$Profile {
  const factory Profile({
    required int id,
    @Default('') String label,
    String? currentGroupName,
    @Default('') String url,
    DateTime? lastUpdateDate,
    required Duration autoUpdateDuration,
    SubscriptionInfo? subscriptionInfo,
    @Default(true) bool autoUpdate,
    @Default({}) Map<String, String> selectedMap,
    @Default({}) Map<String, String> computedSelectedMap,
    @Default({}) Set<String> unfoldSet,
    @Default(OverwriteType.standard) OverwriteType overwriteType,
    int? scriptId,
    int? order,
  }) = _Profile;

  factory Profile.fromJson(Map<String, Object?> json) =>
      _$ProfileFromJson(json);

  factory Profile.normal({String? label, String url = ''}) {
    final id = snowflake.id;
    return Profile(
      label: label ?? '',
      url: url,
      id: id,
      autoUpdateDuration: defaultUpdateDuration,
    );
  }
}

@freezed
abstract class ProfileRuleLink with _$ProfileRuleLink {
  const factory ProfileRuleLink({
    int? profileId,
    required int ruleId,
    RuleScene? scene,
    String? order,
  }) = _ProfileRuleLink;
}

extension ProfileRuleLinkExt on ProfileRuleLink {
  String get key {
    final splits = <String?>[
      profileId?.toString(),
      ruleId.toString(),
      scene?.name,
    ];
    return splits.where((item) => item != null).join('_');
  }
}

// @freezed
// abstract class Overwrite with _$Overwrite {
extension ProfilesExt on List<Profile> {
  Profile? getProfile(int? profileId) {
    final index = indexWhere((profile) => profile.id == profileId);
    return index == -1 ? null : this[index];
  }

  String _getLabel(String label, int id) {
    final realLabel = label.takeFirstValid([id.toString()]);
    final hasDup =
        indexWhere(
          (element) => element.label == realLabel && element.id != id,
        ) !=
        -1;
    if (hasDup) {
      return _getLabel(utils.getOverwriteLabel(realLabel), id);
    } else {
      return label;
    }
  }

  Profile optimizeLabel(Profile profile) {
    return profile.copyWith(label: _getLabel(profile.label, profile.id));
  }
}

extension ProfileExtension on Profile {
  ProfileType get type =>
      url.isEmpty == true ? ProfileType.file : ProfileType.url;

  bool get realAutoUpdate => url.isEmpty == true ? false : autoUpdate;

  String get realLabel => label.takeFirstValid([id.toString()]);

  String get fileName => '$id.yaml';

  String get updatingKey => 'profile_$id';

  Future<Profile?> checkAndUpdateAndCopy() async {
    final mFile = await _getFile();
    final isExists = await mFile.exists();
    if (isExists || url.isEmpty) {
      return null;
    }
    return update();
  }

  Future<File> _getFile() async {
    final path = await appPath.getProfilePath(id.toString());
    return File(path);
  }

  Future<File> get file async {
    return _getFile();
  }

  Future<bool> get sourceExists async => (await _getFile()).exists();

  Future<ProfileSourceResponse> downloadSource() async {
    final response = await request.getFileResponseForUrl(url);
    final disposition = response.headers.value('content-disposition');
    final userinfo = response.headers.value('subscription-userinfo');
    return ProfileSourceResponse(
      bytes: response.data ?? Uint8List.fromList([]),
      subscriptionInfo: SubscriptionInfo.formHString(userinfo),
      fallbackLabel: utils.getFileNameForDisposition(disposition),
    );
  }

  Future<Profile> update() async {
    final response = await downloadSource();
    return copyWith(
      label: label.takeFirstValid([response.fallbackLabel, id.toString()]),
      subscriptionInfo: response.subscriptionInfo,
    ).saveFile(response.bytes);
  }

  Future<Profile> saveFile(Uint8List bytes) async {
    final mFile = await _getFile();
    final token = profileSourceMutationOwner.begin(id);
    late final StagedProfileFile staged;
    try {
      staged = await stageProfileFile(
        targetPath: mFile.path,
        bytes: bytes,
        validate: coreController.validateConfig,
      );
    } catch (_) {
      if (!profileSourceMutationOwner.isCurrent(token)) {
        throw const ProfileSourceMutationSuperseded();
      }
      rethrow;
    }
    try {
      final outcome = await profileSourceMutationOwner.commit(
        token,
        staged.commit,
      );
      if (outcome == ProfileSourceMutationOutcome.superseded) {
        throw const ProfileSourceMutationSuperseded();
      }
    } finally {
      await staged.dispose();
    }
    return copyWith(lastUpdateDate: DateTime.now());
  }

  Future<Profile> saveFileWithPath(String path) async {
    return saveFile(await File(path).readAsBytes());
  }
}

final class ProfileSourceResponse {
  const ProfileSourceResponse({
    required this.bytes,
    required this.subscriptionInfo,
    required this.fallbackLabel,
  });

  final Uint8List bytes;
  final SubscriptionInfo subscriptionInfo;
  final String? fallbackLabel;
}

final class ProfileSourceMutationSuperseded implements Exception {
  const ProfileSourceMutationSuperseded();
}

bool isProfileSourceIdentityCurrent(
  Profile? latest, {
  required int profileId,
  required String sourceUrl,
}) => latest != null && latest.id == profileId && latest.url == sourceUrl;

Profile mergeRemoteProfileResponse(
  Profile latest,
  ProfileSourceResponse response, {
  required DateTime updatedAt,
}) {
  return latest.copyWith(
    label: latest.label.takeFirstValid([
      response.fallbackLabel,
      latest.id.toString(),
    ]),
    subscriptionInfo: response.subscriptionInfo,
    lastUpdateDate: updatedAt,
  );
}

final class StagedProfileFile {
  const StagedProfileFile._(this._staging, this._targetPath);

  final File _staging;
  final String _targetPath;

  Future<void> commit() => _staging.rename(_targetPath);

  Future<void> dispose() async {
    if (await _staging.exists()) await _staging.delete();
  }
}

Future<StagedProfileFile> stageProfileFile({
  required String targetPath,
  required List<int> bytes,
  required Future<String> Function(String path) validate,
}) async {
  final target = File(targetPath);
  final dir = target.parent;
  await dir.create(recursive: true);
  final staging = File(
    p.join(
      dir.path,
      '.${p.basename(targetPath)}.'
      '${DateTime.now().microsecondsSinceEpoch}.'
      '${Random().nextInt(1 << 16)}.staging',
    ),
  );
  try {
    await staging.writeAsBytes(bytes, flush: true);
    final message = await validate(staging.path);
    if (message.isNotEmpty) throw message;
    return StagedProfileFile._(staging, target.path);
  } catch (_) {
    if (await staging.exists()) await staging.delete();
    rethrow;
  }
}

/// Atomically replaces [targetPath] with [bytes] via a unique staging file in
/// the same directory: write, flush, Core-validate the staged copy, then
/// rename it over the target (atomic on POSIX/Android). A failed validation
/// or replacement leaves the existing target untouched and never truncates it
/// early; the staging file is always cleaned up.
Future<void> atomicReplaceProfileFile({
  required String targetPath,
  required List<int> bytes,
  required Future<String> Function(String path) validate,
}) async {
  final staged = await stageProfileFile(
    targetPath: targetPath,
    bytes: bytes,
    validate: validate,
  );
  try {
    await staged.commit();
  } finally {
    await staged.dispose();
  }
}
