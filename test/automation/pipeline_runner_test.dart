import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/automation/core/automation_block.dart';
import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';
import 'package:penguin_pos_qa_agent/automation/core/pipeline_runner.dart';
import 'package:penguin_pos_qa_agent/automation/login/blocks/ensure_logged_out_block.dart';
import 'package:penguin_pos_qa_agent/automation/login/blocks/perform_login_block.dart';
import 'package:penguin_pos_qa_agent/automation/login/blocks/select_terminal_block.dart';
import 'package:penguin_pos_qa_agent/automation/login/blocks/verify_home_screen_block.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_keys.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_runner.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_scenario.dart';

class FakeDriverEngine implements Driver {
  final List<String> tappedKeys = [];
  final List<String> enteredTexts = [];
  bool isConnected = false;
  bool isClosed = false;
  String currentUiState = PenguinPosLoginKeys.loginId;

  @override
  Future<void> connect(
    Uri vmServiceUri, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    isConnected = true;
  }

  @override
  Future<void> waitFor(
    String key, {
    Duration timeout = const Duration(seconds: 45),
    Duration? delay,
  }) async {}

  @override
  Future<void> waitForAbsent(
    String key, {
    Duration timeout = const Duration(seconds: 45),
    Duration? delay,
  }) async {}

  @override
  Future<String> waitForAnyKey(
    Iterable<String> keys, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    return currentUiState;
  }

  @override
  Future<void> waitForText(
    String text, {
    Duration timeout = const Duration(seconds: 45),
    Duration? delay,
  }) async {}

  @override
  Future<bool> hasKey(
    String key, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    return key == PenguinPosLoginKeys.loginId ||
        key == PenguinPosLoginKeys.logoutButton ||
        key == 'login.qwerty.key.a';
  }

  @override
  Future<bool> hasText(
    String text, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    return false;
  }

  @override
  Future<void> enterText(
    String key,
    String text, {
    Duration? delay,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    enteredTexts.add('$key:$text');
  }

  @override
  Future<void> enterTextViaVirtualKeyboard(
    String targetInputKey,
    String text, {
    String keyPrefix = 'login.qwerty',
    TextInputMode mode = TextInputMode.customQwertyPad,
    Duration? delay,
  }) async {
    tappedKeys.add('focus:$targetInputKey');
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (!RegExp(r'^[a-zA-Z0-9.,_/# ]$').hasMatch(char)) {
        throw UnsupportedKeyboardCharacterException(position: i + 1);
      }
      final isUpper = RegExp(r'^[A-Z]$').hasMatch(char);
      if (isUpper) {
        tappedKeys.add('$keyPrefix.shift');
        tappedKeys.add('$keyPrefix.key.${char.toLowerCase()}');
        tappedKeys.add('$keyPrefix.shift');
      } else {
        tappedKeys.add('$keyPrefix.key.$char');
      }
    }
  }

  @override
  Future<String?> tryGetText(
    String key, {
    Duration timeout = const Duration(seconds: 3),
  }) async => null;

  @override
  Future<String> getText(
    String key, {
    Duration timeout = const Duration(seconds: 45),
  }) async => '';

  @override
  Future<void> tap(String key, {Duration? delay}) async {
    tappedKeys.add(key);
  }

  @override
  Future<void> tapText(String text, {Duration? delay}) async {
    tappedKeys.add('text:$text');
  }

  @override
  Future<bool> tryTapText(
    String text, {
    Duration timeout = const Duration(seconds: 3),
    Duration? delay,
  }) async => true;

  @override
  Future<bool> tryTapKey(
    String key, {
    Duration timeout = const Duration(seconds: 3),
    Duration? delay,
  }) async => true;

  @override
  Future<void> stepPause(Duration delay) async {}

  @override
  Future<void> close() async {
    isClosed = true;
  }
}

class FailingBlock implements AutomationBlock {
  @override
  String get id => 'failing_block';
  @override
  String get name => 'Failing Block';

  @override
  Future<void> execute(ExecutionContext context) async {
    throw Exception('Simulated step failure with secret user_pass_123');
  }
}

void main() {
  group('PipelineRunner & Atomic Blocks Tests', () {
    test(
      'PipelineRunner executes blocks sequentially and handles cleanup',
      () async {
        final fakeDriver = FakeDriverEngine();
        final runner = PipelineRunner();
        final scenario = const LoginScenario(
          id: 'test_1',
          name: 'Test Scenario',
          loginId: 'admin',
          password: 'pass',
        );

        final result = await runner.runPipeline(
          blocks: [
            EnsureLoggedOutBlock(),
            PerformLoginBlock(scenario: scenario),
            SelectTerminalBlock(scenario: scenario),
            VerifyHomeScreenBlock(scenario: scenario),
          ],
          cleanupBlocks: [EnsureLoggedOutBlock()],
          vmServiceUri: Uri.parse('http://127.0.0.1:8080/test'),
          driver: fakeDriver,
        );

        expect(result.passed, isTrue);
        expect(result.cleanupPassed, isTrue);
        expect(fakeDriver.isConnected, isTrue);
        expect(fakeDriver.isClosed, isTrue);
        expect(fakeDriver.tappedKeys, contains(PenguinPosLoginKeys.submit));
      },
    );

    test('PipelineRunner catches errors and redacts secrets', () async {
      final fakeDriver = FakeDriverEngine();
      final runner = PipelineRunner();

      final result = await runner.runPipeline(
        blocks: [FailingBlock()],
        vmServiceUri: Uri.parse('http://127.0.0.1:8080/test'),
        driver: fakeDriver,
        secretsToRedact: ['user_pass_123'],
      );

      expect(result.passed, isFalse);
      expect(result.error, contains('[REDACTED]'));
      expect(result.error, isNot(contains('user_pass_123')));
      expect(fakeDriver.isClosed, isTrue);
    });

    test(
      'UnsupportedKeyboardCharacterException does not leak unmappable character',
      () {
        const exception = UnsupportedKeyboardCharacterException(position: 4);
        expect(exception.toString(), contains('position 4'));
        expect(exception.toString(), isNot(contains('@')));
      },
    );

    test(
      'PenguinPosLoginRunner backward-compatible methods delegate to PipelineRunner',
      () async {
        final fakeDriver = FakeDriverEngine();
        final runner = PenguinPosLoginRunner();
        const scenario = LoginScenario(
          id: 'test_2',
          name: 'Runner Test',
          loginId: 'admin',
          password: 'pass',
        );

        final result = await runner.run(
          scenario,
          vmServiceUri: Uri.parse('http://127.0.0.1:8080/test'),
          driverEngine: fakeDriver,
        );

        expect(result.passed, isTrue);
        expect(result.scenariosExecuted, contains('Submit Credentials'));
      },
    );
  });
}
