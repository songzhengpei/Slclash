import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class LogsView extends ConsumerStatefulWidget {
  const LogsView({super.key});

  @override
  ConsumerState<LogsView> createState() => _LogsViewState();
}

class _LogsViewState extends ConsumerState<LogsView> {
  static const _surfaceBottomPadding = 8.0;
  static const _fabListEndPadding = 88.0;

  final _logsStateNotifier = ValueNotifier<LogsState>(const LogsState());
  late ScrollController _scrollController;

  List<Log> _logs = [];

  @override
  void initState() {
    super.initState();
    _logs = ref.read(logsProvider).list;
    _scrollController = ScrollController();
    _logsStateNotifier.value = _logsStateNotifier.value.copyWith(logs: _logs);
    ref.listenManual(logsProvider.select((state) => VM(state.list)), (
      prev,
      next,
    ) {
      if (prev != next) {
        final isEquality = logListEquality.equals(prev?.a, next.a);
        if (!isEquality) {
          _logs = next.a;
          updateLogsThrottler();
        }
      }
    });
  }

  List<Widget> _buildActions() {
    return [
      IconButton(
        onPressed: () {
          _handleExport();
        },
        icon: const Icon(SurgeIcons.save),
      ),
    ];
  }

  void _onSearch(String value) {
    _logsStateNotifier.value = _logsStateNotifier.value.copyWith(query: value);
  }

  void _onKeywordsUpdate(List<String> keywords) {
    _logsStateNotifier.value = _logsStateNotifier.value.copyWith(
      keywords: keywords,
    );
  }

  @override
  void dispose() {
    _logsStateNotifier.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleExport() async {
    final appLocalizations = context.appLocalizations;
    final res = await globalState.safeRun<bool>(() async {
      return globalState.container.read(logsProvider.notifier).exportLogs();
    }, title: appLocalizations.exportLogs);
    if (res != true) return;
    globalState.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(text: appLocalizations.exportSuccess),
    );
  }

  void updateLogsThrottler() {
    throttler.call(FunctionTag.logs, () {
      if (!mounted) {
        return;
      }
      final isEquality = logListEquality.equals(
        _logs,
        _logsStateNotifier.value.logs,
      );
      if (isEquality) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _logsStateNotifier.value = _logsStateNotifier.value.copyWith(
            logs: _logs,
          );
        }
      });
    }, duration: commonDuration);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonScaffold(
      actions: _buildActions(),
      onKeywordsUpdate: _onKeywordsUpdate,
      searchState: AppBarSearchState(onSearch: _onSearch),
      title: appLocalizations.logs,
      floatingActionButton: ValueListenableBuilder(
        valueListenable: _logsStateNotifier,
        builder: (_, state, _) {
          final autoScrollToEnd = state.autoScrollToEnd;
          return FadeRotationScaleBox(
            child: FloatingActionButton(
              key: ValueKey(autoScrollToEnd),
              onPressed: () {
                _logsStateNotifier.value = _logsStateNotifier.value.copyWith(
                  autoScrollToEnd: !_logsStateNotifier.value.autoScrollToEnd,
                );
              },
              child: autoScrollToEnd
                  ? const Icon(SurgeIcons.block)
                  : const Icon(SurgeIcons.verticalAlignTop),
            ),
          );
        },
      ),
      body: ValueListenableBuilder<LogsState>(
        valueListenable: _logsStateNotifier,
        builder: (context, state, _) {
          final logs = state.list;
          if (logs.isEmpty) {
            return NullStatus(
              illustration: const LogEmptyIllustration(),
              label: appLocalizations.nullTip(appLocalizations.logs),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: _surfaceBottomPadding,
            ),
            child: _LogsListSurface(
              child: ScrollToEndBox(
                onCancelToEnd: () {
                  _logsStateNotifier.value = _logsStateNotifier.value.copyWith(
                    autoScrollToEnd: false,
                  );
                },
                controller: _scrollController,
                enable: state.autoScrollToEnd,
                dataSource: logs,
                child: CommonScrollBar(
                  controller: _scrollController,
                  child: SuperListView.builder(
                    physics: const NextClampingScrollPhysics(),
                    controller: _scrollController,
                    itemBuilder: (_, index) {
                      if (index == logs.length) {
                        return const SizedBox(height: _fabListEndPadding);
                      }
                      final log = logs[index];
                      return LogItem(
                        key: Key(log.dateTime),
                        log: log,
                        showDivider: index != logs.length - 1,
                        onClick: (value) {
                          context.commonScaffoldState?.addKeyword(value);
                        },
                      );
                    },
                    itemCount: logs.length + 1,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class LogItem extends StatelessWidget {
  final Log log;
  final Function(String)? onClick;
  final bool showDivider;

  const LogItem({
    super.key,
    required this.log,
    this.onClick,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final levelColor = log.logLevel.color(context) ?? surge.textSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SelectableText(
                    log.payload,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: surge.textPrimary.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (onClick == null) return;
                          onClick!(log.logLevel.name);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: levelColor.withValues(alpha: 0.075),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: levelColor.withValues(alpha: 0.14),
                              width: surge.spacing.hairline,
                            ),
                          ),
                          child: Text(
                            log.logLevel.name,
                            style: context.textTheme.labelSmall?.copyWith(
                              color: levelColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              height: 1,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        log.dateTime,
                        style: context.textTheme.labelSmall?.copyWith(
                          color: surge.textSecondary.withValues(alpha: 0.62),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w400,
                          height: 1,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (showDivider)
              const Positioned(
                left: 14,
                right: 14,
                bottom: 0,
                child: _LogsListDivider(),
              ),
          ],
        ),
      ),
    );
  }
}

class _LogsListSurface extends StatelessWidget {
  const _LogsListSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SurgeCard(
      padding: EdgeInsets.zero,
      borderRadius: 18,
      shadow: false,
      child: ClipRRect(borderRadius: BorderRadius.circular(18), child: child),
    );
  }
}

class _LogsListDivider extends StatelessWidget {
  const _LogsListDivider();

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Divider(
      height: 0,
      thickness: surge.spacing.hairline,
      color: surge.separator.withValues(alpha: 0.56),
    );
  }
}
