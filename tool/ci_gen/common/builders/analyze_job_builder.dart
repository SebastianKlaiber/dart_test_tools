import 'package:freezed_annotation/freezed_annotation.dart';

import '../../types/expression.dart';
import '../../types/id.dart';
import '../../types/job.dart';
import '../../types/step.dart';
import '../steps/analyze_builder.dart';
import 'sdk_job_builder.dart';

abstract class AnalyzeJobBuilder extends SdkJobBuilder {
  final Expression repository;
  final Expression workingDirectory;
  final Expression buildRunner;
  final Expression analyzeImage;
  final Expression publishExclude;

  const AnalyzeJobBuilder({
    required this.repository,
    required this.workingDirectory,
    required this.buildRunner,
    required this.analyzeImage,
    required this.publishExclude,
  });

  @override
  JobId get id => const JobId('analyze');

  @override
  Job build() => Job(
        name: 'Analyze',
        runsOn: analyzeImage.toString(),
        steps: [
          ...buildSetupSdkSteps(),
          ...AnalyzeBuilder(
            repository: repository,
            workingDirectory: workingDirectory,
            buildRunner: buildRunner,
            analyzeImage: analyzeImage,
            publishExclude: publishExclude,
            baseTool: baseTool,
            pubTool: pubTool,
            runTool: runTool,
            buildAnalyzeStep: buildAnalyzeSteps,
          ).build(),
        ],
      );

  @protected
  Iterable<Step> buildAnalyzeSteps();
}
