import 'package:flutter/foundation.dart';

@immutable
final class RuntimeProfileIdentity {
  const RuntimeProfileIdentity({required this.profileId, required this.epoch});

  final int profileId;
  final int epoch;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RuntimeProfileIdentity &&
          other.profileId == profileId &&
          other.epoch == epoch;

  @override
  int get hashCode => Object.hash(profileId, epoch);
}

bool isRuntimeProfileIdentityCurrent({
  required RuntimeProfileIdentity identity,
  required int? currentProfileId,
  required int currentEpoch,
}) {
  return currentProfileId == identity.profileId &&
      currentEpoch == identity.epoch;
}

bool isRuntimeProfileIdentityActive({
  required RuntimeProfileIdentity identity,
  required RuntimeProfileIdentity? activeIdentity,
  required int? currentProfileId,
  required int currentEpoch,
}) {
  return activeIdentity == identity &&
      isRuntimeProfileIdentityCurrent(
        identity: identity,
        currentProfileId: currentProfileId,
        currentEpoch: currentEpoch,
      );
}

Future<({bool current, T? value})> runRuntimeMutationIfCurrent<T>({
  required RuntimeProfileIdentity identity,
  required bool Function(RuntimeProfileIdentity identity) isCurrent,
  required Future<T> Function() mutation,
}) async {
  if (!isCurrent(identity)) return (current: false, value: null);
  final value = await mutation();
  if (!isCurrent(identity)) return (current: false, value: null);
  return (current: true, value: value);
}
