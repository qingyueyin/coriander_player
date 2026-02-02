import 'dart:io';

import 'package:coriander_player/component/settings_tile.dart';
import 'package:coriander_player/hotkeys_helper.dart';
import 'package:coriander_player/utils.dart';
import 'package:flutter/material.dart';
import 'package:github/github.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:go_router/go_router.dart';
import 'package:coriander_player/app_paths.dart' as app_paths;

const String cpFeedbackKey = String.fromEnvironment(
  'CPFEEDBACK_KEY',
  defaultValue: '',
);

const bool enableIssueReporting = bool.fromEnvironment(
  'ENABLE_ISSUE_REPORTING',
  defaultValue: false,
);

class CreateIssueTile extends StatelessWidget {
  const CreateIssueTile({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      description: "报告问题",
      action: FilledButton.icon(
        onPressed: enableIssueReporting
            ? () => context.push(app_paths.SETTINGS_ISSUE_PAGE)
            : () => showTextOnSnackBar(
                  "未启用 Issue 上报（需要 ENABLE_ISSUE_REPORTING）",
                ),
        label: const Text("创建问题(至原项目)"),
        icon: const Icon(Symbols.help),
      ),
    );
  }
}

class SettingsIssuePage extends StatefulWidget {
  const SettingsIssuePage({super.key});

  @override
  State<SettingsIssuePage> createState() => _SettingsIssuePageState();
}

class _SettingsIssuePageState extends State<SettingsIssuePage> {
  final titleEditingController = TextEditingController();
  final descEditingController = TextEditingController();
  final logEditingController = TextEditingController();
  final submitBtnController = WidgetStatesController();

  String _buildEnvironmentInfo() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    return [
      "OS: ${Platform.operatingSystem}",
      "OS Version: ${Platform.operatingSystemVersion}",
      "Runtime: ${Platform.version}",
      "Locale: ${locale.toLanguageTag()}",
    ].join("\n");
  }

  String _buildLogSnapshot() {
    final logStrBuf = StringBuffer();
    for (final event in LOGGER_MEMORY.buffer) {
      for (var line in event.lines) {
        logStrBuf.writeln(line);
      }
    }
    var text = logStrBuf.toString();
    text = text.replaceAll(
      RegExp(r'([A-Za-z]:\\Users\\)([^\\]+)\\', caseSensitive: false),
      r'$1***\\',
    );
    text = text.replaceAll(
      RegExp(r'(/Users/)([^/]+)/', caseSensitive: false),
      r'$1***/',
    );
    text = text.replaceAll(
      RegExp(r'(/home/)([^/]+)/', caseSensitive: false),
      r'$1***/',
    );
    return text;
  }

  Future<void> createIssue() async {
    if (!enableIssueReporting) {
      showTextOnSnackBar("未启用 Issue 上报");
      return;
    }
    if (cpFeedbackKey.isEmpty) {
      showTextOnSnackBar("未配置 CPFEEDBACK_KEY，无法创建 Issue");
      return;
    }
    submitBtnController.update(WidgetState.disabled, true);
    final cpfeedback = GitHub(
      auth: const Authentication.withToken(cpFeedbackKey),
    );
    final issueBodyBuilder = StringBuffer();
    issueBodyBuilder
      ..writeln("## 环境信息")
      ..writeln(_buildEnvironmentInfo())
      ..writeln("## 描述")
      ..writeln(descEditingController.text)
      ..writeln("## 日志")
      ..writeln("```")
      ..writeln(logEditingController.text)
      ..writeln("```");

    final issue = IssueRequest(
      title: titleEditingController.text,
      body: issueBodyBuilder.toString(),
    );

    try {
      await cpfeedback.issues.create(
        RepositorySlug("qingyueyin", "coriander_player"),
        issue,
      );

      showTextOnSnackBar("创建成功");
    } catch (err, trace) {
      showTextOnSnackBar(err.toString());
      LOGGER.e(err, stackTrace: trace);
    }

    submitBtnController.update(WidgetState.disabled, false);
    cpfeedback.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Focus(
                    onFocusChange: HotkeysHelper.onFocusChanges,
                    child: TextField(
                      controller: titleEditingController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: "标题",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: FilledButton(
                    statesController: submitBtnController,
                    onPressed: !enableIssueReporting
                        ? () => showTextOnSnackBar("未启用 Issue 上报")
                        : cpFeedbackKey.isEmpty
                            ? () => showTextOnSnackBar(
                                  "未配置 CPFEEDBACK_KEY，无法创建 Issue",
                                )
                            : createIssue,
                    child: const Text("报告问题"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "日志（可选）",
                    style: TextStyle(color: scheme.onSurface.withOpacity(0.75)),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    logEditingController.text = _buildLogSnapshot();
                  },
                  child: const Text("填充日志"),
                ),
                TextButton(
                  onPressed: () => logEditingController.clear(),
                  child: const Text("清空"),
                ),
              ],
            ),
            Expanded(
              child: Focus(
                onFocusChange: HotkeysHelper.onFocusChanges,
                child: TextField(
                  controller: descEditingController,
                  textAlignVertical: const TextAlignVertical(y: -1),
                  expands: true,
                  maxLines: null,
                  decoration: const InputDecoration(
                    hintText: "描述",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Focus(
                onFocusChange: HotkeysHelper.onFocusChanges,
                child: TextField(
                  controller: logEditingController,
                  textAlignVertical: const TextAlignVertical(y: -1),
                  expands: true,
                  maxLines: null,
                  decoration: const InputDecoration(
                    hintText: "日志",
                    helperText: "你可以随意修改日志内容。",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            const Padding(padding: EdgeInsets.only(bottom: 96.0))
          ],
        ),
      ),
    );
  }
}
