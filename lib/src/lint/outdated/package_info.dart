import 'package:freezed_annotation/freezed_annotation.dart';

import 'version_info.dart';

part 'package_info.freezed.dart';
part 'package_info.g.dart';

/// @nodoc
@freezed
@internal
class PackageInfo with _$PackageInfo {
  /// @nodoc
  const factory PackageInfo({
    required String package,
    required VersionInfo current,
    required VersionInfo upgradable,
    required VersionInfo resolvable,
    required VersionInfo latest,
  }) = _PackageInfo;

  /// @nodoc
  factory PackageInfo.fromJson(Map<String, dynamic> json) =>
      _$PackageInfoFromJson(json);
}
