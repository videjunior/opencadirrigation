import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appBuildName, appBuildNumber;

import 'app/actions.dart';
import 'app/canvas/cad_canvas.dart';
import 'app/examples.dart';
import 'app/i18n.dart';
import 'app/i18n_assets.dart';
import 'app/io/app_keys.dart';
import 'app/io/unload.dart';
import 'app/keys/hotkeys.dart';
import 'app/keys/native_keys.dart';
import 'app/shortcuts.dart';
import 'app/state/controller.dart';
import 'app/state/workspace.dart';
import 'app/theme.dart';
import 'app/tools/tools.dart';
import 'app/tutorial/tutorial.dart';
import 'app/version.dart';
import 'app/widgets/advice_panel.dart';
import 'app/widgets/dialogs/dialogs.dart';
import 'app/widgets/dialogs/more_dialogs.dart';
import 'app/widgets/dialogs/terrain_dialogs.dart';
import 'app/widgets/dialogs/welcome_dialog.dart';
import 'app/widgets/mobile_shell.dart';
import 'app/widgets/design_progress.dart';
import 'app/widgets/history_panel.dart';
import 'app/widgets/layers_panel.dart';
import 'app/widgets/menu_bar.dart';
import 'app/widgets/project_tab_bar.dart';
import 'app/widgets/properties_panel.dart';
import 'app/widgets/reports_panel.dart';
import 'app/widgets/status_bar.dart';
import 'app/widgets/tool_palette.dart';
import 'core/io/project_export.dart';
import 'core/model/entities.dart';
import 'core/model/geometry.dart';

Future<void> main() async {
  // The exact build goes to the console at start-up (also shown in the
  // welcome dialog, the status bar and Help → About).
  debugPrint('$appName $appVersionLabel');
  // flutter build/run embed the pubspec version; a mismatch means
  // lib/app/version.dart was not regenerated after bumping pubspec.yaml.
  if (appBuildName != null && (appBuildName != appVersion || (appBuildNumber ?? '$appBuild') != '$appBuild')) {
    debugPrint('version.dart is stale: pubspec.yaml says $appBuildName+$appBuildNumber, run dart run tool/gen_version.dart');
  }
  // Languages beyond Portuguese, English and Spanish come from
  // assets/i18n/<code>.json: fetch the start language before the first frame
  // so the interface never flashes English first.
  WidgetsFlutterBinding.ensureInitialized();
  useAssetLanguageLoader();
  await ensureLanguageLoaded(startLanguage());
  await warmUpFonts(startLanguage());
  runApp(const IrrigationCadApp());
}

/// The language the app will start in: the page address (`?lang=`, `/pt/`)
/// wins over the saved choice and the machine language, which is English
/// when the machine asks for no language the app speaks.
String startLanguage() {
  final urlLang = Uri.base.queryParameters['lang'] ?? languageFromPath(Uri.base.pathSegments);
  if (urlLang != null && supportedLanguages.contains(urlLang)) return urlLang;
  return ProjectController.initialLanguage();
}

class IrrigationCadApp extends StatelessWidget {
  const IrrigationCadApp({super.key, this.autoTutorial = true, this.offerRecovery = true});

  /// Whether to offer the tutorial on first run.
  final bool autoTutorial;

  /// Whether to offer recovery of autosaved projects on start-up.
  final bool offerRecovery;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenCADIrrigation',
      navigatorKey: appNavigatorKey,
      navigatorObservers: [appRouteObserver],
      debugShowCheckedModeBanner: false,
      theme: buildCadTheme(),
      home: AppShell(autoTutorial: autoTutorial, offerRecovery: offerRecovery),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.autoTutorial = true, this.offerRecovery = true});
  final bool autoTutorial;

  /// Offer to recover autosaved projects on start-up.
  final bool offerRecovery;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> implements ToolHost, TutorialHost, HotkeyActions {
  /// Open project tabs; [c] is the active one.
  final Workspace ws = Workspace();
  ProjectController get c => ws.current;
  final Set<ProjectController> _subscribed = {};
  final Map<int, int> _lastSeqByTab = {};
  final TutorialController tutorial = TutorialController();
  final FocusNode canvasFocus = FocusNode();

  /// Keyboard shortcuts, fed by the platform (native listener on the web).
  late final Hotkeys hotkeys = Hotkeys(this);
  late final NativeHotkeys _nativeKeys = NativeHotkeys(hotkeys.handle);
  String _status = '';
  /// Side panel tab: 0 properties, 1 layers, 2 history.
  int _sideTabIndex = 0;
  double _reportsHeight = 220;

  @override
  void initState() {
    super.initState();
    ws.addListener(_onWorkspace);
    _syncSubscriptions();
    tutorial.addListener(_onTutorial);
    setUnloadGuard(() => ws.tabs.any((t) => t.dirty));
    _nativeKeys.install();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // ?lang=es or the /pt/ and /es/ entry pages pick the language for this
      // visit; otherwise the saved choice or the machine language applies.
      final urlLang = Uri.base.queryParameters['lang'] ?? languageFromPath(Uri.base.pathSegments);
      if (urlLang != null) c.setLanguage(urlLang, persist: false);
      var recovered = 0;
      if (widget.offerRecovery && mounted) recovered = await showRecoveryDialog(context, ws);
      if (!mounted) return;
      final example = exampleIdFromName(Uri.base.queryParameters['example']);
      if (recovered == 0 || example != null) loadExampleAction(c, example ?? ExampleId.orchard);
      if (Uri.base.queryParameters['design'] == '1') c.runDesign();
      final tut = int.tryParse(Uri.base.queryParameters['tutorial'] ?? '');
      if (tut != null && tut > 0 && mounted) {
        startTutorial(startAt: tut - 1);
        return;
      }
      if (widget.autoTutorial && !TutorialController.isDone && mounted && example == null) {
        final choice = await showWelcomeDialog(context, c, firstRun: true);
        if (!mounted) return;
        if (choice == WelcomeChoice.tutorial) {
          startTutorial();
        } else {
          TutorialController.markDone();
        }
      }
    });
  }

  @override
  void dispose() {
    for (final t in _subscribed) {
      t.removeListener(_onController);
    }
    ws.removeListener(_onWorkspace);
    tutorial.removeListener(_onTutorial);
    _nativeKeys.dispose();
    hotkeys.dispose();
    for (final t in ws.tabs) {
      if (t.focusCanvas == _focusCanvas) t.focusCanvas = null;
    }
    canvasFocus.dispose();
    super.dispose();
  }

  void _onTutorial() {
    if (mounted) setState(() {});
  }

  void startTutorial({int startAt = 0}) {
    c.select(const []);
    c.setTool(ToolId.select);
    tutorial.start(buildTutorialSteps(c.lang), startAt: startAt);
  }

  /// Help → Welcome and example gallery.
  Future<void> showWelcome() async {
    final choice = await showWelcomeDialog(context, c);
    if (choice == WelcomeChoice.tutorial && mounted) startTutorial();
  }

  /// Keeps a listener on every open tab (messages, repaint).
  void _syncSubscriptions() {
    for (final t in ws.tabs) {
      t.focusCanvas = _focusCanvas;
      if (_subscribed.add(t)) t.addListener(_onController);
    }
    _subscribed.removeWhere((t) {
      if (ws.tabs.contains(t)) return false;
      t.removeListener(_onController);
      return true;
    });
  }

  void _onWorkspace() {
    _syncSubscriptions();
    if (mounted) setState(() {});
  }

  Future<void> _closeTab(int i) async {
    if (i < 0 || i >= ws.tabs.length) return;
    final tab = ws.tabs[i];
    if (tab.dirty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tab.t('file.closeTab')),
          content: Text(tab.t('msg.unsavedConfirm')),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tab.t('cancel'))), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tab.t('ok')))],
        ),
      );
      if (ok != true) return;
      tab.autosaveNow();
    }
    ws.closeTab(i);
  }

  /// After a tool or menu choice the canvas takes the focus back (next
  /// frame, so an opened dialog keeps its own focus).
  void _focusCanvas() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) canvasFocus.requestFocus();
    });
  }

  // ---- HotkeyActions
  @override
  ProjectController get controller => c;

  @override
  bool get modalOpen => appNavigatorKey.currentState?.canPop() ?? false;

  @override
  bool get menuOpen => AppMenuBar.openMenus.value > 0;

  @override
  bool dismissModal() {
    final r = appRouteObserver.top;
    if (r is PopupRoute && r.barrierDismissible) {
      appNavigatorKey.currentState?.pop();
      return true;
    }
    return false;
  }

  @override
  void runDesign() => c.runDesign();

  @override
  void save() => saveProjectAction(context, c);

  @override
  void open() => openProjectInTabAction(context, ws);

  @override
  void import() => importDrawingAction(context, c);

  @override
  void exportPdf() => exportDrawingAction(context, c, DrawingFormat.pdf);

  @override
  void newTab() => ws.addTab();

  @override
  void closeTab() => _closeTab(ws.active);

  @override
  void nextTab() => ws.next();

  @override
  void prevTab() => ws.previous();

  @override
  void toggleReports() => _toggleReports();

  @override
  void array() => showArrayDialog(context, c);

  @override
  void designCheck() => showDesignCheckDialog(context, c);

  @override
  void autoFix() => showAutoFixDialog(context, c);

  @override
  void optimize() => showOptimizeDialog(context, c);

  @override
  void clipboard(CadAction action) {
    switch (action) {
      case CadAction.copy:
        copySelectionAction(ws);
      case CadAction.cut:
        copySelectionAction(ws, cut: true);
      case CadAction.paste:
        pasteAction(ws);
      default:
        break;
    }
  }

  void _toggleReports() {
    c.showReports = !c.showReports;
    c.refresh();
  }

  void _onController() {
    for (final tab in ws.tabs) {
      final last = _lastSeqByTab[tab.tabId] ?? 0;
      if (tab.messageSeq != last && tab.lastMessage != null) {
        _lastSeqByTab[tab.tabId] = tab.messageSeq;
        if (!identical(tab, c)) continue;
        final msg = tab.lastMessage!;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          // phones: above the tool bar, so it never covers the tools
          final compact = MediaQuery.sizeOf(context).width < mobileBreakpoint;
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(compact
                ? SnackBar(content: Text(msg, style: const TextStyle(fontSize: 12)), duration: const Duration(milliseconds: 2200), behavior: SnackBarBehavior.floating, margin: const EdgeInsets.fromLTRB(12, 0, 72, 100))
                : SnackBar(content: Text(msg), duration: const Duration(seconds: 3), behavior: SnackBarBehavior.floating, width: 420));
        });
      }
    }
    if (mounted) setState(() {});
  }

  // ---- ToolHost
  @override
  void setStatus(String text) {
    if (text == _status) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _status = text);
    });
  }

  @override
  void showBlockDialog(List<Pt> polygon) => showBlockDialogFn(context, c, polygon);

  @override
  void showAutoheadDialog(List<Pt> polygon) => showAutoheadDialogFn(context, c, polygon);

  @override
  void showTextDialog(Pt position) => showTextDialogFn(context, c, position);

  @override
  void showLeaderDialog(List<Pt> points) => showLeaderDialogFn(context, c, points);

  @override
  void promptElevation(Entity e) => showElevationDialog(context, c, e);

  // ---- TutorialHost
  @override
  bool get layersTabShown => _sideTabIndex == 1;

  @override
  void showLayersTab(bool layers) => showSideTab(layers ? 1 : 0);

  @override
  int get sideTab => _sideTabIndex;

  @override
  void showSideTab(int index) {
    if (_sideTabIndex == index) return;
    setState(() => _sideTabIndex = index);
  }

  @override
  void saveProject() => saveProjectAction(context, c);

  @override
  void typeCommand(String alias) {
    hotkeys.setCommand(alias.toUpperCase());
    hotkeys.runCommand();
  }

  @override
  void openReports(bool open, {int? tab}) {
    c.showReports = open;
    if (tab != null) c.reportTab = tab;
    c.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final compact = MediaQuery.sizeOf(context).width < mobileBreakpoint;
    final canvas = CadCanvas(key: ValueKey('canvas${c.tabId}'), controller: c, host: this, focusNode: canvasFocus, workspace: ws, onArray: () => showArrayDialog(context, c));
    if (compact) {
      return Stack(
        children: [
          MobileShell(
            c: c,
            ws: ws,
            // the progress card sits over the canvas (bottom-left, clear of the
            // floating buttons) and blocks nothing
            canvas: Stack(
              children: [
                Positioned.fill(child: canvas),
                if (c.busy) Positioned(left: 8, right: 60, bottom: 8, child: DesignProgressOverlay(c: c, compact: true)),
              ],
            ),
            hint: t('hint.${_hintFor(c.activeTool)}'),
            onStartTutorial: startTutorial,
            onShowWelcome: showWelcome,
            onCloseTab: () => _closeTab(ws.active),
            onDesignCheck: designCheck,
          ),
          if (tutorial.active) Positioned.fill(child: TutorialOverlay(tutorial: tutorial, controller: c, host: this, lang: c.lang)),
        ],
      );
    }
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              SizedBox(height: 36, child: AppMenuBar(c: c, ws: ws, onStartTutorial: startTutorial, onShowWelcome: showWelcome, onCloseTab: () => _closeTab(ws.active))),
              ProjectTabBar(ws: ws, onClose: _closeTab, onAdd: () => ws.addTab()),
              const Divider(height: 1),
              Expanded(
                child: Row(
                  children: [
                    ToolPalette(c: c),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: Stack(
                              children: [
                                Positioned.fill(child: KeyedSubtree(key: TutorialTargets.canvas, child: canvas)),
                                // non-blocking progress card: the workspace stays usable while a design runs
                                if (c.busy) Positioned(right: 12, bottom: 12, child: DesignProgressOverlay(c: c)),
                              ],
                            ),
                          ),
                          if (c.showReports) ...[
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onVerticalDragUpdate: (d) => setState(() => _reportsHeight = (_reportsHeight - d.delta.dy).clamp(120, 600)),
                              child: const MouseRegion(cursor: SystemMouseCursors.resizeRow, child: SizedBox(height: 5, child: ColoredBox(color: Color(0xFF2B3138)))),
                            ),
                            SizedBox(key: TutorialTargets.reportsBar, height: _reportsHeight, child: ReportsPanel(c: c)),
                          ] else
                            SizedBox(
                              key: TutorialTargets.reportsBar,
                              height: 22,
                              child: InkWell(
                                onTap: () => setState(() => c.showReports = true),
                                child: Container(
                                  color: const Color(0xFF1B1F24),
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text('▲ ${t('menu.reports')}', style: const TextStyle(fontSize: 11, color: Colors.white60)),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    SizedBox(
                      key: TutorialTargets.sidePanel,
                      width: 300,
                      child: Column(
                        children: [
                          Container(
                            key: TutorialTargets.sideTabs,
                            height: 30,
                            color: const Color(0xFF1B1F24),
                            child: Row(
                              children: [
                                _sideTab(t('props.title'), _sideTabIndex == 0, () => showSideTab(0)),
                                _sideTab(t('view.layers'), _sideTabIndex == 1, () => showSideTab(1)),
                                _sideTab(t('hist.title'), _sideTabIndex == 2, () => showSideTab(2), key: const Key('side_tab_history')),
                              ],
                            ),
                          ),
                          Expanded(child: switch (_sideTabIndex) { 1 => LayersPanel(c: c), 2 => HistoryPanel(c: c), _ => PropertiesPanel(c: c) }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              KeyedSubtree(key: TutorialTargets.statusBar, child: StatusBar(c: c, status: _status, hint: t('hint.${_hintFor(c.activeTool)}'))),
            ],
          ),
          if (tutorial.active) Positioned.fill(child: TutorialOverlay(tutorial: tutorial, controller: c, host: this, lang: c.lang)),
        ],
      ),
    );
  }

  Widget _sideTab(String label, bool on, VoidCallback onTap, {Key? key}) => Expanded(
    child: InkWell(
      key: key,
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: on ? const Color(0xFF42A5F5) : Colors.transparent, width: 2))),
        child: Text(label, style: TextStyle(fontSize: 11.5, color: on ? Colors.white : Colors.white60)),
      ),
    ),
  );

  String _hintFor(ToolId t) => hintKeyOf(t);
}











// Aliases to avoid name clashes with ToolHost members.
Future<void> showBlockDialogFn(BuildContext context, ProjectController c, List<Pt> polygon) => showBlockDialog(context, c, polygon);
Future<void> showAutoheadDialogFn(BuildContext context, ProjectController c, List<Pt> polygon) => showAutoheadDialog(context, c, polygon);
Future<void> showTextDialogFn(BuildContext context, ProjectController c, Pt position) => showTextDialog(context, c, position);
Future<void> showLeaderDialogFn(BuildContext context, ProjectController c, List<Pt> points) => showLeaderDialog(context, c, points);
