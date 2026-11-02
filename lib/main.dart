import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appBuildName, appBuildNumber;

import 'app/actions.dart';
import 'app/canvas/cad_canvas.dart';
import 'app/examples.dart';
import 'app/i18n.dart';
import 'app/i18n_assets.dart';
import 'app/io/app_keys.dart';
import 'app/io/app_update.dart'; // 1.6.0 SIT
import 'app/io/launch_files.dart'; // 1.6.0 SIT
import 'app/io/links.dart';
import 'app/launch_actions.dart'; // 1.6.0 SIT
import 'app/io/page_lifecycle.dart';
import 'app/io/unload.dart';
import 'app/keys/hotkeys.dart';
import 'app/keys/native_keys.dart';
import 'app/shortcuts.dart';
import 'app/state/app_errors.dart';
import 'app/state/controller.dart';
import 'app/state/workspace.dart';
import 'app/theme.dart';
import 'app/tools/tools.dart';
import 'app/tutorial/tutorial.dart';
import 'app/version.dart';
import 'app/widgets/advice_panel.dart';
import 'app/ai/ai_assistant.dart';
import 'app/widgets/ai/ai_drop.dart';
import 'app/widgets/ai/ai_panel.dart';
import 'app/widgets/dialogs/ai_assistant_dialog.dart';
import 'app/widgets/dialogs/ai_start_dialog.dart';
import 'app/widgets/dialogs/auto_design_dialogs.dart';
import 'app/widgets/dialogs/densogram_dialog.dart';
import 'app/widgets/dialogs/network_ops_dialogs.dart';
import 'app/widgets/dialogs/vegetation_dialog.dart';
import 'app/widgets/dialogs/dialogs.dart';
import 'app/widgets/dialogs/more_dialogs.dart';
import 'app/widgets/dialogs/terrain_dialogs.dart';
import 'app/widgets/dialogs/transient_dialogs.dart';
import 'app/widgets/dialogs/blocks_dialogs.dart';
import 'app/widgets/dialogs/selection_dialogs.dart';
import 'app/widgets/dialogs/welcome_dialog.dart';
// 1.6.0 FMT
import 'app/widgets/dialogs/share_confirm_dialog.dart' show confirmSharedProject;
import 'app/widgets/mobile_shell.dart';
import 'app/widgets/command_entry.dart';
import 'app/widgets/layout_mode.dart';
import 'app/widgets/message_log.dart';
import 'app/widgets/design_progress.dart';
import 'app/widgets/history_panel.dart';
import 'app/widgets/layers_panel.dart';
import 'app/widgets/menu_bar.dart';
import 'app/widgets/project_tab_bar.dart';
import 'app/widgets/properties_panel.dart';
import 'app/widgets/reports_panel.dart';
import 'app/widgets/status_bar.dart';
import 'app/widgets/tool_palette.dart';
import 'app/widgets/update_notice.dart'; // 1.6.0 SIT
import 'core/io/project_export.dart';
import 'core/io/share_link.dart';
import 'core/model/entities.dart';
import 'core/model/geometry.dart';
import 'app/project_name.dart'; // 1.6.0 UI
import 'app/ui_prefs.dart'; // 1.6.0 UI
import 'app/widgets/dialogs/command_palette.dart'; // 1.6.0 UI
import 'app/widgets/dialogs/help_dialog.dart'; // 1.6.0 UI
import 'app/widgets/dialogs/whats_new_dialog.dart'; // 1.6.0 UI
import 'app/widgets/side_dock.dart'; // 1.6.0 UI
import 'app/widgets/fields.dart' show localizeUi; // 1.6.0 UI

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
  // an error nothing else caught: logged, the work copied in the browser,
  // the user told once in a short message (see AppErrors)
  AppErrors.install();
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
  const IrrigationCadApp({super.key, this.autoTutorial = true, this.offerRecovery = true, this.askAi = true, this.startExample});

  /// Whether to offer the tutorial on first run (and, with [askAi], the
  /// start-up question about the AI assistant).
  final bool autoTutorial;

  /// Whether to ask at start-up if the user wants to design with the AI
  /// assistant (only when [autoTutorial] is on as well).
  final bool askAi;

  /// An example to open at start instead of the empty project (the
  /// address's `?example=` still wins); then nothing is asked at start.
  final ExampleId? startExample;

  /// Whether to offer recovery of autosaved projects on start-up.
  final bool offerRecovery;

  @override
  Widget build(BuildContext context) {
    // View → Theme: dark, light or the system's; switched in place (see
    // CadThemeHost), with no theme animation so the material parts and the
    // palette read by the widgets change together
    return CadThemeHost(
      builder: (context, brightness) => MaterialApp(
        title: 'OpenCADIrrigation',
        navigatorKey: appNavigatorKey,
        navigatorObservers: [appRouteObserver],
        debugShowCheckedModeBanner: false,
        theme: buildCadTheme(brightness),
        themeAnimationStyle: AnimationStyle.noAnimation,
        // Arabic and Urdu read right to left: menus, panels and dialogs mirror
        // (the drawing itself keeps its coordinates)
        // (1.6.0 UI: drawn at the interface size of View → Interface)
        builder: (context, child) => UiScaled(
          child: ValueListenableBuilder<String>(
            valueListenable: uiLanguage,
            builder: (context, lang, _) => Directionality(textDirection: rtlLanguages.contains(lang) ? TextDirection.rtl : TextDirection.ltr, child: child ?? const SizedBox()),
          ),
        ),
        home: AppShell(autoTutorial: autoTutorial, offerRecovery: offerRecovery, askAi: askAi, startExample: startExample),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.autoTutorial = true, this.offerRecovery = true, this.askAi = true, this.startExample});
  final bool autoTutorial;

  /// Ask at start-up whether to design with the AI assistant.
  final bool askAi;

  /// An example to open at start instead of the empty project.
  final ExampleId? startExample;

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

  /// Cursor coordinates for the status bar, with the view scale they were
  /// read at: they change on every pointer move, so only the status bar
  /// listens (the rest of the window is not rebuilt for them).
  final _status = ValueNotifier<(String, double)>(('', 0));

  /// Side panel tab: 0 properties, 1 layers, 2 history.
  int _sideTabIndex = 0;
  double _reportsHeight = savedReportsHeight() ?? 220.0;

  /// The arrangement of the last build (phone, narrow or wide).
  ShellLayout _layout = ShellLayout.wide;

  /// Narrow windows: the side panel drawer is open over the drawing.
  bool _sideOpen = false;

  /// Touch screens: the command line for the on-screen keyboard is open.
  bool _commandOpen = false;

  @override
  void initState() {
    super.initState();
    // the AI assistant works on these tabs and opens in the docked panel
    AiAssistant.workspace = ws;
    AiAssistant.dockable = true;
    ws.addListener(_onWorkspace);
    _syncSubscriptions();
    tutorial.addListener(_onTutorial);
    // a finger or a mouse: the touch layout and the ⌨ button follow it (a new
    // shell starts from what the platform suggests)
    lastPointerKind.value = null;
    startPointerKindTracking();
    lastPointerKind.addListener(_onPointerKind);
    // 1.6.0 UI: focus mode, the side panel folded or widened
    for (final n in <Listenable>[uiFocusMode, uiSideFolded, uiSideWidth, uiScale, uiHighContrast]) {
      n.addListener(_onUiPrefs);
    }
    // unsaved projects, and conversations with the assistant that are not kept
    // in this browser as they are now (keeping off, a turn running, a save not done)
    setUnloadGuard(() => ws.tabs.any((t) => t.dirty) || AiAssistant.live.any((a) => a.unsavedConversation));
    // the copies in the browser when the page goes to the background (a phone
    // may discard it there without another word) and, at once, when it goes away
    watchPageLifecycle(
      hidden: () {
        for (final t in ws.tabs) {
          t.autosaveIfChanged();
        }
      },
      closing: () {
        for (final t in ws.tabs) {
          t.rescueNow();
        }
      },
    );
    AppErrors.attach(ws, (message) => _snack(message, long: true));
    // 1.6.0 SIT: a newer build of the web app is installed: offer to reload into it
    watchForAppUpdate(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showUpdateBanner(context, ws, unsaved: () => ws.tabs.any((t) => t.dirty) || AiAssistant.live.any((a) => a.unsavedConversation));
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    });
    // 1.6.0 SIT: the files the installed app is asked to open or is sent (the file handlers and the share target of
    // its manifest) and the launches of its window already open (a shortcut)
    watchLaunches((r) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) handleLaunch(context, ws, r, startTutorial: (step) => startTutorial(startAt: step));
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    });
    _nativeKeys.install();
    // a file dropped on the window never replaces the app: it goes to the AI
    // panel (pasted pictures to its chat box)
    AiFileDrop.instance.install(() => c);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // ?lang=es or an entry page such as /pt/ or /de/ picks the language for this
      // visit; otherwise the saved choice or the machine language applies.
      final urlLang = Uri.base.queryParameters['lang'] ?? languageFromPath(Uri.base.pathSegments);
      if (urlLang != null) c.setLanguage(urlLang, persist: false);
      // the browser store ready (texts of an older version moved, the copies
      // written while the page was closing turned into recoverable copies)
      await c.store.prepare();
      var recovered = 0;
      if (widget.offerRecovery && mounted) recovered = await showRecoveryDialog(context, ws);
      if (!mounted) return;
      // 1.6.0 UI (SIT-07): once after an update of the web app, what changed
      if (kIsWeb && shouldShowWhatsNew(c)) await showWhatsNewDialog(context, c, afterUpdate: true);
      if (!mounted) return;
      // a project shared by link (#p=…) opens in a tab of its own, as a copy
      // (the link carries the uid of whoever sent it); the address loses it
      // first, so a link that cannot be opened is not tried again when the
      // page is reloaded or the tab restored
      final fragment = Uri.base.fragment;
      final linked = fragment.startsWith('p=');
      if (linked) clearAddressFragment();
      final read = linked ? projectJsonFromLink('#$fragment') : null;
      // 1.6.0 FMT: a large project opens only when the user says so (FMT-09)
      var declined = false;
      if (read != null && mounted) declined = !await confirmSharedProject(context, c, read);
      if (!mounted) return;
      final shared = declined ? null : read;
      if (linked && !declined && (shared == null || openJsonInTab(ws, shared, asCopy: true) == null)) c.notify(c.t('share.damaged'));
      final q = Uri.base.queryParameters;
      final example = exampleIdFromName(q['example']) ?? widget.startExample;
      final designLink = q['design'] == '1';
      final tut = int.tryParse(q['tutorial'] ?? '');
      final tutorialLink = tut != null && tut > 0;
      // ?ai=1 (the site's "Open the AI assistant" button, the app shortcut)
      final aiLink = q['ai'] == '1';
      // 1.6.0 SIT: opened with files ("Open with", the share target): they open as they arrive, nothing to ask
      final launched = openedWithFiles();
      // an example only when the address asks for one (the designed sample
      // works on the orchard; the tutorial opens its own); otherwise the app
      // starts empty
      if (example != null || designLink) loadExampleAction(c, example ?? ExampleId.orchard);
      if (designLink) c.runDesign();
      if (tutorialLink && mounted) {
        startTutorial(startAt: tut - 1);
        return;
      }
      // a project the address chose, or recovered work: nothing to ask
      if (example != null || designLink || shared != null || recovered > 0 || launched) {
        if (aiLink && mounted) showAiAssistantDialog(context, c);
        return;
      }
      // a fresh start: the conversation held by a project never changed comes
      // back with its uid; the start-up screen asks where the area is and
      // whether to design with the AI assistant
      AiAssistant.resumePristine(c);
      if (widget.autoTutorial && widget.askAi && AiAssistant.askAtStart && mounted) {
        final choice = await showAiStartDialog(context, c);
        if (mounted) _applyStart(choice);
      } else if (aiLink && mounted) {
        showAiAssistantDialog(context, c);
      }
    });
  }

  /// Puts the new project where the start-up screen said (georeferenced
  /// there, on the satellite map) and opens the assistant when the user
  /// chose to design with it, the place named in the request.
  void _applyStart(StartChoice choice) {
    final p = choice.place;
    if (p != null) {
      c.setGeoreferenceAt(p.$1, p.$2, viewSizeM: 400);
      c.baseMap = BaseMap.satellite;
      c.refresh();
    }
    final prompt = choice.aiPrompt;
    if (prompt == null) return;
    final where = choice.placeName;
    showAiAssistantDialog(context, c, prompt: where == null ? prompt : '${c.t('ai.start.place', {'p': where})}\n\n$prompt');
  }

  @override
  void dispose() {
    AppErrors.detach(ws);
    for (final t in _subscribed) {
      t.removeListener(_onController);
    }
    ws.removeListener(_onWorkspace);
    tutorial.removeListener(_onTutorial);
    lastPointerKind.removeListener(_onPointerKind);
    for (final n in <Listenable>[uiFocusMode, uiSideFolded, uiSideWidth, uiScale, uiHighContrast]) {
      n.removeListener(_onUiPrefs);
    }
    stopPointerKindTracking();
    _nativeKeys.dispose();
    AiFileDrop.instance.uninstall();
    hotkeys.dispose();
    for (final t in ws.tabs) {
      if (t.focusCanvas == _focusCanvas) t.focusCanvas = null;
    }
    canvasFocus.dispose();
    _status.dispose();
    super.dispose();
  }

  void _onTutorial() {
    if (mounted) setState(() {});
  }

  void _onUiPrefs() {
    if (mounted) setState(() {});
  }

  void _onPointerKind() {
    // (the pointer is pressed during a frame's input handling: rebuild after it)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  /// Help → Interactive tutorial (also the welcome's "Start tutorial" and
  /// `?tutorial=N`): the orchard example in a tab of its own — the blank tab
  /// of a fresh start is used, any other project stays as it is in its tab —
  /// so the steps find what they talk about and their "Show me" demos never
  /// change the user's work.
  void startTutorial({int startAt = 0}) {
    setFocusMode(false); // 1.6.0 UI
    final cur = c;
    final target = cur.project.entities.isEmpty && !cur.dirty ? cur : ws.addTab();
    loadExampleAction(target);
    target.select(const []);
    target.setTool(ToolId.select);
    tutorial.start(buildTutorialSteps(target.lang), startAt: startAt);
  }

  /// Help → Welcome and example gallery.
  Future<void> showWelcome() async {
    final choice = await showWelcomeDialog(context, c, ws: ws);
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
    // an assistant whose tab was closed stops (it would work and spend out of sight)
    AiAssistant.stopRemoved(ws.tabs);
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
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tab.t('cancel'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tab.t('ok'))),
          ],
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
      appNavigatorKey.currentState?.maybePop();
      return true;
    }
    return false;
  }

  /// The application keys (Ctrl+S, Ctrl+O, Ctrl+I, Ctrl+P, F5) act on what
  /// the user sees: the field being typed in gives the focus up first (it
  /// commits its value on focus loss, in a microtask) and [action] runs
  /// after that, so the number just typed is saved, exported or designed.
  void _afterFieldCommit(VoidCallback action) {
    if (!editableTextFocused()) {
      action();
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    Future<void>.delayed(Duration.zero, () {
      if (mounted) action();
    });
  }

  @override
  void runDesign() => _afterFieldCommit(() => c.runDesign());

  @override
  void save() => _afterFieldCommit(() => saveProjectAction(context, c));

  @override
  void open() => _afterFieldCommit(() => openProjectInTabAction(context, ws));

  @override
  void import() => _afterFieldCommit(() => importDrawingAction(context, c));

  @override
  void exportPdf() => _afterFieldCommit(() => exportDrawingAction(context, c, DrawingFormat.pdf));

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
  void assistant() => showAiAssistantDialog(context, c);

  @override
  void densogram() => showDensogramDialog(context, c);

  @override
  void autoDesign(CadAction action) => action == CadAction.vegetation ? showVegetationDialog(context, c) : showAutoDesignDialog(context, c, action.name);

  @override
  void networkTool(CadAction action) {
    switch (action) {
      case CadAction.onDemand:
        showOnDemandDialog(context, c);
      case CadAction.tariff:
        showTariffDialog(context, c);
      case CadAction.energyGroups:
        showEnergyGroupingDialog(context, c);
      case CadAction.wireRoutes:
        showWireRoutingDialog(context, c);
      case CadAction.criticality:
        showCriticalityDialog(context, c);
      case CadAction.calibration:
        showCalibrationDialog(context, c);
      case CadAction.fertigation:
        showFertigationDialog(context, c);
      default:
        break;
    }
  }

  @override
  void insertBlock() => insertBlockAction(context, c, c.project.blocks, pickTool: ToolId.insertBlock);

  @override
  void saveBlock() => saveBlockAction(context, c, c.project.blocks);

  @override
  void mainlineAnalysis(CadAction action) {
    switch (action) {
      case CadAction.airValves:
        showAirValveDialog(context, c);
      case CadAction.eps:
        showEpsDialog(context, c);
      default:
        showTransientDialog(context, c);
    }
  }

  // 1.6.0 EDT
  @override
  void quickSelect() => showQuickSelectDialog(context, c);

  // 1.6.0 UI: Ctrl+K, Ctrl+Alt+F and F1
  @override
  void commandPalette() => _afterFieldCommit(() => showCommandPalette(context, c, runAlias: typeCommand));

  @override
  void toggleFocusMode() => setFocusMode(!uiFocusMode.value);

  @override
  void help() => showHelpDialog(context, c);

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
        // every message is kept (Help → Recent messages), also those of the other tabs
        logMessage(projectTitle(tab.t, tab.project.meta.name), tab.lastMessage!);
        if (!identical(tab, c)) continue;
        _snack(tab.lastMessage!);
      }
    }
    if (mounted) setState(() {});
  }

  /// A short message at the bottom of the window ([long]: an error, shown
  /// for longer), long enough to be read and with the list of all of them
  /// (Help → Recent messages) one tap away.
  void _snack(String msg, {bool long = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      // phones: above the tool bar, so it never covers the tools
      final compact = shellLayoutOf(context) == ShellLayout.phone;
      final more = SnackBarAction(key: const Key('snack_messages'), label: c.t('ui.messagesShort'), onPressed: () => showMessageLogDialog(context, c));
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          compact
              ? SnackBar(
                  content: Text(localizeUi(msg), style: const TextStyle(fontSize: 12)), // 1.6.0 UI: numbers in the notation of the language
                  duration: Duration(milliseconds: long ? 6000 : 3500),
                  persist: false,
                  action: more,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.fromLTRB(12, 0, 72, 100),
                )
              : SnackBar(
                  content: Text(localizeUi(msg)),
                  duration: Duration(seconds: long ? 8 : 6),
                  persist: false,
                  action: more,
                  behavior: SnackBarBehavior.floating,
                  width: 480,
                ),
        );
    });
  }

  // ---- ToolHost
  @override
  void setStatus(String text) {
    final next = (text, c.camera.scale);
    if (next == _status.value) return;
    // tools also report while painting: the text changes after the frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _status.value = next;
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
  void showCommentDialog(Pt position) => showCommentDialogFn(context, c, position);

  @override
  void showRevisionDialog(List<Pt> polygon) => showRevisionDialogFn(context, c, polygon);

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
    // 1.6.0 UI: a folded side panel unfolds for it (not kept)
    if (_layout == ShellLayout.wide && uiSideFolded.value) uiSideFolded.value = false;
    // narrow windows: the panel the tutorial (or a menu) asks for comes out of its drawer
    final open = _layout == ShellLayout.narrow && !_sideOpen;
    if (_sideTabIndex == index && !open) return;
    setState(() {
      _sideTabIndex = index;
      if (open) _sideOpen = true;
    });
  }

  @override
  void saveProject() => _afterFieldCommit(() => saveProjectAction(context, c));

  @override
  void typeCommand(String alias) {
    hotkeys.setCommand(alias.toUpperCase());
    hotkeys.runCommand();
  }

  // 1.6.0 UI: the AI chapter of the tutorial watches the assistant and writes in its box (never sends)
  @override
  bool get assistantShown => AiAssistant.panelOpen.value || AiAssistant.peek(c) != null;

  @override
  void showAssistant({String? prompt}) => showAiAssistantDialog(context, c, prompt: prompt);

  @override
  void openPalette() => commandPalette();

  @override
  void openManual() => showHelpDialog(context, c);

  /// A command line typed without a keyboard (the ⌨ field of touch
  /// screens): an alias, a point or a distance, run as Enter would.
  void typeCommandLine(String text) {
    if (text.trim().isEmpty) return;
    typeCommand(text.trim());
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
    // the arrangement follows the width, the height and the pointer: a phone
    // held sideways gets the touch layout, a tablet in portrait the side
    // panel in a drawer
    final layout = _layout = shellLayoutOf(context);
    final canvas = CadCanvas(key: ValueKey('canvas${c.tabId}'), controller: c, host: this, focusNode: canvasFocus, workspace: ws, onArray: () => showArrayDialog(context, c));
    if (layout == ShellLayout.phone) {
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
            onCloseTabAt: _closeTab,
            onCommand: typeCommandLine,
            onDesignCheck: designCheck,
          ),
          if (tutorial.active)
            Positioned.fill(
              child: TutorialOverlay(tutorial: tutorial, controller: c, host: this, lang: c.lang),
            ),
        ],
      );
    }
    final narrow = layout == ShellLayout.narrow;
    // 1.6.0 UI: focus mode leaves the drawing board alone
    final focus = uiFocusMode.value;
    final height = MediaQuery.sizeOf(context).height;
    // the reports never take more than half of what is left for the drawing
    final reportsHeight = _reportsHeight.clamp(120.0, math.max(120.0, (height - 140) * 0.5)).toDouble();
    final sidePanel = Column(
      children: [
        Container(
          key: TutorialTargets.sideTabs,
          height: _barHeight(context, 30),
          color: Cad.panel,
          child: Row(
            children: [
              _sideTab(t('props.title'), _sideTabIndex == 0, () => showSideTab(0)),
              _sideTab(t('view.layers'), _sideTabIndex == 1, () => showSideTab(1)),
              _sideTab(t('hist.title'), _sideTabIndex == 2, () => showSideTab(2), key: const Key('side_tab_history')),
              // 1.6.0 UI: the "?" of the tab shown, and the panel folds away
              HelpButton(c: c, topic: const ['properties', 'layers', 'history'][_sideTabIndex.clamp(0, 2)], panel: true),
              if (!narrow)
                IconButton(
                  key: const Key('side_fold'),
                  tooltip: t('ui.sideClose'),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_right, size: 18),
                  onPressed: () => setSideFolded(true),
                ),
              if (narrow)
                IconButton(
                  key: const Key('side_drawer_close'),
                  tooltip: t('ui.sideClose'),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_right, size: 18),
                  onPressed: () => setState(() => _sideOpen = false),
                ),
            ],
          ),
        ),
        Expanded(
          child: switch (_sideTabIndex) {
            1 => LayersPanel(c: c),
            2 => HistoryPanel(c: c),
            _ => PropertiesPanel(c: c),
          },
        ),
      ],
    );
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              if (!focus) ...[
                SizedBox(
                  height: _barHeight(context, 36),
                  child: AppMenuBar(c: c, ws: ws, onStartTutorial: startTutorial, onShowWelcome: showWelcome, onCloseTab: () => _closeTab(ws.active), onCommand: typeCommand),
                ),
                ProjectTabBar(ws: ws, onClose: _closeTab, onAdd: () => ws.addTab()),
                const Divider(height: 1),
              ],
              Expanded(
                child: Row(
                  children: [
                    if (!focus) ...[ToolPalette(c: c), const VerticalDivider(width: 1)],
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: KeyedSubtree(key: TutorialTargets.canvas, child: canvas),
                                ),
                                // non-blocking progress card: the workspace stays usable while a design runs
                                if (c.busy)
                                  Positioned(
                                    right: narrow ? 56 : 12,
                                    bottom: 12,
                                    child: DesignProgressOverlay(c: c),
                                  ),
                                // touch screens wide enough for this layout (tablets): typed commands without a keyboard
                                if (touchInput && !_commandOpen)
                                  Positioned(
                                    left: 8,
                                    bottom: 8,
                                    child: FloatingActionButton.small(
                                      key: const Key('command_button'),
                                      heroTag: null,
                                      tooltip: t('cmd.open'),
                                      backgroundColor: Cad.overlayStrong,
                                      foregroundColor: Cad.fg,
                                      onPressed: () => setState(() => _commandOpen = true),
                                      child: const Icon(Icons.keyboard_outlined),
                                    ),
                                  ),
                                // 1.6.0 UI: the way out of focus mode
                                if (focus)
                                  PositionedDirectional(
                                    start: 8,
                                    top: 8,
                                    child: FloatingActionButton.small(
                                      key: const Key('focus_exit'),
                                      heroTag: null,
                                      tooltip: t('uiv.focusExit'),
                                      backgroundColor: Cad.overlayStrong,
                                      foregroundColor: Cad.fg,
                                      onPressed: () => setFocusMode(false),
                                      child: const Icon(Icons.fullscreen_exit),
                                    ),
                                  ),
                                // narrow windows: the side panel is a drawer over the drawing
                                if (narrow && !_sideOpen && !focus)
                                  PositionedDirectional(
                                    end: 0,
                                    top: 8,
                                    child: Material(
                                      color: Cad.overlayStrong,
                                      borderRadius: const BorderRadiusDirectional.horizontal(start: Radius.circular(8)),
                                      child: IconButton(key: const Key('side_drawer_open'), tooltip: t('ui.sideOpen'), icon: const Icon(Icons.tune), onPressed: () => setState(() => _sideOpen = true)),
                                    ),
                                  ),
                                if (narrow && _sideOpen)
                                  PositionedDirectional(
                                    end: 0,
                                    top: 0,
                                    bottom: 0,
                                    width: 300,
                                    child: Material(key: TutorialTargets.sidePanel, elevation: 8, color: Cad.panel, child: sidePanel),
                                  ),
                              ],
                            ),
                          ),
                          if (_commandOpen) CommandEntry(c: c, onRun: typeCommandLine, onClose: () => setState(() => _commandOpen = false)),
                          if (c.showReports && !focus) ...[
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onVerticalDragUpdate: (d) => setState(() => _reportsHeight = (reportsHeight - d.delta.dy).clamp(120, 600).toDouble()),
                              onVerticalDragEnd: (_) => saveReportsHeight(_reportsHeight), // 1.6.0 UI
                              child: MouseRegion(
                                cursor: SystemMouseCursors.resizeRow,
                                child: SizedBox(
                                  height: touchInput ? 12 : 5,
                                  child: ColoredBox(color: Cad.divider),
                                ),
                              ),
                            ),
                            SizedBox(
                              key: TutorialTargets.reportsBar,
                              height: reportsHeight,
                              child: ReportsPanel(c: c),
                            ),
                          ] else if (!focus)
                            SizedBox(
                              key: TutorialTargets.reportsBar,
                              height: _barHeight(context, 22),
                              child: InkWell(
                                onTap: () => setState(() => c.showReports = true),
                                child: Container(
                                  color: Cad.panel,
                                  alignment: AlignmentDirectional.centerStart,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text('▲ ${t('menu.reports')}', style: TextStyle(fontSize: 11, color: Cad.fg60)),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // 1.6.0 UI: docked at the width the user gave it, or folded into a strip
                    if (!narrow && !focus) SideDock(c: c, panelKey: TutorialTargets.sidePanel, child: sidePanel),
                    // the AI assistant, docked so the drawing stays in view while it works
                    // (narrow windows open it in a sheet instead: see assistantDocks)
                    if (!narrow)
                      ValueListenableBuilder<bool>(
                        valueListenable: AiAssistant.panelOpen,
                        builder: (_, open, _) => open
                            ? ValueListenableBuilder<int>(
                                valueListenable: AiAssistant.activity,
                                builder: (_, _, _) {
                                  // the panel stays with an assistant that works or waits in another tab
                                  final own = AiAssistant.peek(c);
                                  final away = own != null && (own.busy || own.waiting)
                                      ? null
                                      : AiAssistant.live.where((a) => !identical(a.c, c) && ws.tabs.contains(a.c) && (a.busy || a.waiting)).firstOrNull;
                                  final pc = away?.c ?? c;
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const VerticalDivider(width: 1),
                                      SizedBox(
                                        width: aiPanelWidth,
                                        child: AiAgentPanel(
                                          key: ValueKey('ai_panel_${pc.tabId}'),
                                          c: pc,
                                          onClose: AiAssistant.togglePanel,
                                          onShowTab: away == null ? null : () => ws.select(ws.tabs.indexOf(pc)),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              )
                            : const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
              if (!focus) ...[
                const Divider(height: 1),
                KeyedSubtree(
                  key: TutorialTargets.statusBar,
                  child: StatusBar(c: c, status: _status, hint: t('hint.${_hintFor(c.activeTool)}')),
                ),
              ],
            ],
          ),
          if (tutorial.active)
            Positioned.fill(
              child: TutorialOverlay(tutorial: tutorial, controller: c, host: this, lang: c.lang),
            ),
        ],
      ),
    );
  }

  /// A bar of [base] logical pixels that grows with the text size the user
  /// chose (the system or browser font setting), so its text is never cut.
  static double _barHeight(BuildContext context, double base) => math.max(base, MediaQuery.textScalerOf(context).scale(base * 0.5) + base * 0.5);

  Widget _sideTab(String label, bool on, VoidCallback onTap, {Key? key}) => Expanded(
    child: InkWell(
      key: key,
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: on ? Cad.accent : Colors.transparent, width: 2)),
        ),
        child: Text(label, style: TextStyle(fontSize: 11.5, color: on ? Cad.fg : Cad.fg60)),
      ),
    ),
  );

  String _hintFor(ToolId t) => hintKeyOf(t);
}

// Aliases to avoid name clashes with ToolHost members.
Future<void> showBlockDialogFn(BuildContext context, ProjectController c, List<Pt> polygon) => showBlockDialog(context, c, polygon);
Future<void> showAutoheadDialogFn(BuildContext context, ProjectController c, List<Pt> polygon) => showAutoheadDialog(context, c, polygon);
Future<void> showTextDialogFn(BuildContext context, ProjectController c, Pt position) => showTextDialog(context, c, position);
Future<void> showCommentDialogFn(BuildContext context, ProjectController c, Pt position) => showCommentDialog(context, c, position);
Future<void> showRevisionDialogFn(BuildContext context, ProjectController c, List<Pt> polygon) => showRevisionDialog(context, c, polygon);
Future<void> showLeaderDialogFn(BuildContext context, ProjectController c, List<Pt> points) => showLeaderDialog(context, c, points);
