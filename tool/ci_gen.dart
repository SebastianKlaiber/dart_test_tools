import 'dart:convert';
import 'dart:io';

import 'package:yaml_writer/yaml_writer.dart';

import 'ci_gen/compile/compile_workflow.dart';
import 'ci_gen/dart/dart_workflow.dart';
import 'ci_gen/publish/publish_workflow.dart';
import 'ci_gen/types/workflow.dart';

Future<void> main() async {
  exitCode += await _writeWorkflowToFile('dart', DartWorkflow.buildWorkflow());
  exitCode +=
      await _writeWorkflowToFile('publish', PublishWorkflow.buildWorkflow());
  exitCode +=
      await _writeWorkflowToFile('compile', CompileWorkflow.buildWorkflow());
}

Future<int> _writeWorkflowToFile(String name, Workflow workflow) async {
  final writer = _createYamlWriter();

  final outFile = File('.github/workflows/$name.yml').openWrite();
  final yqProc = await Process.start('yq', const ['e', '-P']);
  final errFuture = yqProc.stderr.listen(stdout.write).asFuture();
  final outFuture = yqProc.stdout.pipe(outFile);

  await Stream.value(writer.write(workflow))
      .transform(utf8.encoder)
      .pipe(yqProc.stdin);

  await Future.wait([outFuture, errFuture]);

  return yqProc.exitCode;
}

YAMLWriter _createYamlWriter() {
  return YAMLWriter()
    ..toEncodable = (dynamic data) {
      // ignore: avoid_dynamic_calls
      final jsonData = data.toJson != null ? data.toJson() : data;
      if (jsonData is Map) {
        jsonData.remove('runtimeType');
      }
      return jsonData;
    };
}
