import '../../common/api/step_builder.dart';
import '../../common/steps/platforms_builder_mixin.dart';
import '../../common/steps/project_setup_builder.dart';
import '../../types/expression.dart';
import '../../types/step.dart';

abstract class IDartIntegrationTestMatrix {
  Expression get platform;
  Expression get dartTestArgs;
}

class DartIntegrationTestBuilder
    with PlatformsBuilderMixin
    implements StepBuilder {
  final Expression repository;
  final Expression workingDirectory;
  final Expression buildRunner;
  final Expression integrationTestSetup;
  final Expression integrationTestPaths;
  final Expression integrationTestEnvVars;
  @override
  final Expression platforms;
  final String baseTool;
  final String pubTool;
  final String runTool;
  final IDartIntegrationTestMatrix matrix;

  const DartIntegrationTestBuilder({
    required this.repository,
    required this.workingDirectory,
    required this.buildRunner,
    required this.integrationTestSetup,
    required this.integrationTestPaths,
    required this.integrationTestEnvVars,
    required this.platforms,
    required this.baseTool,
    required this.pubTool,
    required this.runTool,
    required this.matrix,
  });

  @override
  Iterable<Step> build() => [
        ...ProjectSetupBuilder(
          repository: repository,
          workingDirectory: workingDirectory,
          buildRunner: buildRunner,
          pubTool: pubTool,
          runTool: runTool,
          ifExpression: _shouldRun,
        ).build(),
        Step.run(
          name: 'Create .env file from secrets',
          ifExpression: _shouldRun,
          run: "echo '$integrationTestEnvVars' > .env",
          workingDirectory: workingDirectory.toString(),
          shell: 'bash',
        ),
        Step.run(
          name: 'Run platform test setup',
          ifExpression: _platformTestSetup.ne(Expression.empty) & _shouldRun,
          run: _platformTestSetup.toString(),
          workingDirectory: workingDirectory.toString(),
        ),
        Step.run(
          name: 'Run integration tests',
          ifExpression: _shouldRun,
          run: '$baseTool test ${matrix.dartTestArgs} '
              '--reporter expanded $integrationTestPaths',
          workingDirectory: workingDirectory.toString(),
        ),
        Step.run(
          name: 'Shred .env file',
          ifExpression: const Expression('always()') & _shouldRun,
          run: 'shred -fzvu .env',
          workingDirectory: workingDirectory.toString(),
        ),
      ];

  Expression get _platformTestSetup => Expression(
        'fromJSON(${integrationTestSetup.value})[${matrix.platform.value}]',
      );

  Expression get _shouldRun => shouldRunExpression(matrix.platform);
}
