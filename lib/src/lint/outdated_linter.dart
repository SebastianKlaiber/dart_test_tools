import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

import 'common/context_root_extensions.dart';
import 'common/file_result.dart';
import 'common/linter.dart';
import 'common/linter_mixin.dart';
import 'outdated/outdated_info.dart';
import 'outdated/package_info.dart';

Future<void> main() async {
  Logger.root.onRecord.listen(print);
  Logger.root.level = Level.ALL;
  final linter = OutdatedLinter()
    ..contextCollection = AnalysisContextCollection(
      includedPaths: [Directory.current.path],
    );
  linter.call().listen(print);
}

class OutdatedLinter with LinterMixin implements Linter {
  @override
  late AnalysisContextCollection contextCollection;

  @override
  @internal
  final Logger logger;

  @override
  String get name => 'outdated';

  @override
  String get description => 'Checks for outdated dependencies';

  OutdatedLinter([Logger? logger]) : logger = logger ?? Logger('outdated');

  @override
  Stream<FileResult> call() async* {
    for (final context in contextCollection.contexts) {
      final pubspec = context.contextRoot.pubspec;
      final outdatedInfo =
          await _getOutdated(context.contextRoot.workspaceRoot);

      for (final package in outdatedInfo.packages) {
        final resultLocation = ResultLocation(
          relPath: relative(context.contextRoot.pubspecFile.path),
          codeSnippit: package.package,
        );

        final pubDependency = pubspec.dependencies[package.package] ??
            pubspec.devDependencies[package.package];
        yield _checkOutdated(
          package: package,
          pubDependency: pubDependency,
          resultLocation: resultLocation,
        );
      }
    }
  }

  FileResult _checkOutdated({
    required PackageInfo package,
    required Dependency? pubDependency,
    required ResultLocation resultLocation,
  }) {
    if (package.upgradable.version > package.current.version) {
      return FileResult.rejected(
        reason: 'Package ${package.package} should be updated: '
            '${package.current.version} -> ${package.upgradable.version}',
        resultLocation: resultLocation,
      );
    } else if (package.resolvable.version > package.current.version) {
      logWarning(
        resultLocation,
        'Major update for package ${package.package} available: '
        '${package.current.version} -> ${package.resolvable.version}',
      );
      return FileResult.accepted(resultLocation: resultLocation);
    } else if (package.latest.version > package.current.version) {
      return FileResult.skipped(
        reason: 'Skipping incompatible update for package ${package.package}: '
            '${package.current.version} -> ${package.latest.version}',
        resultLocation: resultLocation,
      );
    } else {
      final pullUpResult = _checkPullUp(
        package: package,
        pubDependency: pubDependency,
        resultLocation: resultLocation,
      );

      return pullUpResult ??
          FileResult.accepted(resultLocation: resultLocation);
    }
  }

  FileResult? _checkPullUp({
    required PackageInfo package,
    required Dependency? pubDependency,
    required ResultLocation resultLocation,
  }) {
    if (pubDependency != null && pubDependency is HostedDependency) {
      final constraint = pubDependency.version;
      if (constraint is VersionRange) {
        final minVersion = constraint.min;
        if (minVersion != null && package.current.version > minVersion) {
          return FileResult.rejected(
            reason: 'Package ${package.package} can be pulled up: '
                '$constraint -> ${package.current.version}',
            resultLocation: resultLocation,
          );
        }
      }
    }

    return null;
  }

  Future<OutdatedInfo> _getOutdated(Folder workspaceRoot) async {
    final proc = await Process.start(
      'flutter',
      [
        'pub',
        'outdated',
        '--show-all',
        '--json',
        '--directory',
        workspaceRoot.path,
      ],
      runInShell: true,
    );

    final fStderr = stderr.addStream(proc.stderr);
    final jsonData = await proc.stdout
        .transform(utf8.decoder)
        .transform(json.decoder)
        .cast<Map<String, dynamic>>()
        .map(OutdatedInfo.fromJson)
        .single;
    await fStderr;

    final exitCode = await proc.exitCode;
    if (exitCode != 0) {
      // TODO better exception
      throw Exception('flutter pub outdated failed with exit code $exitCode');
    }

    return jsonData;
  }
}
