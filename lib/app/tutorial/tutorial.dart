/// Interactive first-run tutorial: spotlight overlay with step cards, user
/// actions detected automatically, "show me" demos and a skip option.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design/block_generator.dart';
import '../../core/i18n/language_packs.dart';
import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../io/prefs.dart';
import '../state/controller.dart';
import '../widgets/reports_panel.dart';

/// Global anchors for the widgets highlighted by the tutorial.
class TutorialTargets {
  static final menuFile = GlobalKey(debugLabel: 'menuFile');
  static final menuExportDrawing = GlobalKey(debugLabel: 'menuExportDrawing');
  static final menuEdit = GlobalKey(debugLabel: 'menuEdit');
  static final menuView = GlobalKey(debugLabel: 'menuView');
  static final menuDraw = GlobalKey(debugLabel: 'menuDraw');
  static final menuZone = GlobalKey(debugLabel: 'menuZone');
  static final menuMain = GlobalKey(debugLabel: 'menuMain');
  static final menuDesign = GlobalKey(debugLabel: 'menuDesign');
  static final menuTerrain = GlobalKey(debugLabel: 'menuTerrain');
  static final menuReports = GlobalKey(debugLabel: 'menuReports');
  static final menuTools = GlobalKey(debugLabel: 'menuTools');
  static final menuHelp = GlobalKey(debugLabel: 'menuHelp');
  static final runButton = GlobalKey(debugLabel: 'runButton');
  static final saveButton = GlobalKey(debugLabel: 'saveButton');
  static final palette = GlobalKey(debugLabel: 'palette');
  static final paletteNav = GlobalKey(debugLabel: 'paletteNav');
  static final paletteDraw = GlobalKey(debugLabel: 'paletteDraw');
  static final paletteTerrain = GlobalKey(debugLabel: 'paletteTerrain');
  static final paletteZone = GlobalKey(debugLabel: 'paletteZone');
  static final paletteMain = GlobalKey(debugLabel: 'paletteMain');
  static final canvas = GlobalKey(debugLabel: 'canvas');
  static final sidePanel = GlobalKey(debugLabel: 'sidePanel');
  static final sideTabs = GlobalKey(debugLabel: 'sideTabs');
  static final reportsBar = GlobalKey(debugLabel: 'reportsBar');
  static final statusToggles = GlobalKey(debugLabel: 'statusToggles');
  static final statusBar = GlobalKey(debugLabel: 'statusBar');
}

/// What the tutorial can ask the app shell to do.
abstract class TutorialHost {
  void showLayersTab(bool layers);
  bool get layersTabShown;

  /// Side panel tab: 0 properties, 1 layers, 2 history.
  void showSideTab(int index);
  int get sideTab;
  void openReports(bool open, {int? tab});

  /// Saves the project as the user would with Ctrl+S.
  void saveProject();

  /// Runs a typed command alias through the real keyboard path.
  void typeCommand(String alias);
}

class TutorialContext {
  TutorialContext(this.c, this.host, this.memo);
  final ProjectController c;
  final TutorialHost host;
  final Map<String, Object?> memo;
}

class TutorialStep {
  const TutorialStep({
    required this.id,
    required this.title,
    required this.body,
    this.chapter = '',
    this.target,
    this.action,
    this.prepare,
    this.demo,
    this.isDone,
  });
  final String id;
  final String title;
  final String body;

  /// Chapter name shown above the title.
  final String chapter;
  final GlobalKey? target;

  /// Text of the action the user is invited to perform.
  final String? action;
  final void Function(TutorialContext)? prepare;
  final void Function(TutorialContext)? demo;
  final bool Function(TutorialContext)? isDone;

  /// Interactive: waits for the user (or the demo) to do something.
  bool get interactive => action != null && isDone != null;
}

class TutorialController extends ChangeNotifier {
  static const prefKey = 'tutorial_done';

  bool active = false;
  int index = 0;
  List<TutorialStep> steps = const [];
  final Map<String, Object?> memo = {};

  /// Move on by itself shortly after a step is done.
  bool autoAdvance = true;

  static bool get isDone => getPref(prefKey) == '1';
  static void markDone() => setPref(prefKey, '1');
  static void reset() => removePref(prefKey);

  TutorialStep get current => steps[index];
  bool get isLast => index >= steps.length - 1;

  /// Number of interactive steps and how many come before [index].
  int get interactiveCount => steps.where((s) => s.interactive).length;

  void start(List<TutorialStep> s, {int startAt = 0}) {
    steps = s;
    index = startAt.clamp(0, s.length - 1);
    memo.clear();
    active = true;
    notifyListeners();
  }

  void next() {
    if (isLast) {
      finish();
      return;
    }
    index++;
    notifyListeners();
  }

  void prev() {
    if (index > 0) index--;
    notifyListeners();
  }

  void goTo(int i) {
    index = i.clamp(0, steps.length - 1);
    notifyListeners();
  }

  void setAutoAdvance(bool v) {
    autoAdvance = v;
    notifyListeners();
  }

  void finish() {
    active = false;
    markDone();
    notifyListeners();
  }

  void skip() => finish();
}

// ---------------------------------------------------------------- texts

class _T {
  const _T(this.pt, this.en, this.es);
  final String pt;
  final String en;
  final String es;
  String of(String lang) => switch (lang) { 'en' => en, 'es' => es, 'pt' => pt, _ => packTutorialText(lang, en) ?? en };
}

String tutorialText(String key, String lang) => (_texts[key] ?? _T(key, key, key)).of(lang);

const _texts = <String, _T>{
  'start': _T('Iniciar tutorial', 'Start tutorial', 'Iniciar tutorial'),
  'skip': _T('Pular', 'Skip', 'Omitir'),
  'skipAll': _T('Pular tutorial', 'Skip tutorial', 'Omitir tutorial'),
  'next': _T('Próximo', 'Next', 'Siguiente'),
  'prev': _T('Anterior', 'Back', 'Anterior'),
  'finish': _T('Concluir', 'Finish', 'Terminar'),
  'demo': _T('Mostrar', 'Show me', 'Mostrar'),
  'step': _T('Passo {i} de {n}', 'Step {i} of {n}', 'Paso {i} de {n}'),
  'action': _T('Experimente', 'Try it', 'Pruébelo'),
  'done': _T('Feito!', 'Done!', '¡Hecho!'),
  'doneNext': _T('Feito! Avançando…', 'Done! Moving on…', '¡Hecho! Avanzando…'),
  'autoOn': _T('Avança sozinho ao concluir (clique para desligar)', 'Moves on by itself when done (click to turn off)', 'Avanza solo al terminar (clic para desactivar)'),
  'autoOff': _T('Avanço automático desligado (clique para ligar)', 'Auto-advance off (click to turn on)', 'Avance automático desactivado (clic para activar)'),
  'finishedTitle': _T('Tutorial concluído', 'Tutorial finished', 'Tutorial terminado'),
  'finishedBody': _T('Você pode reabrir este tutorial em Ajuda → Tutorial interativo. Bom projeto!', 'You can reopen this tutorial from Help → Interactive tutorial. Happy designing!', 'Puede reabrir este tutorial en Ayuda → Tutorial interactivo. ¡Buen diseño!'),
};

/// Builds the ordered list of steps for the given language.
///
/// Most steps are interactive: they state an action, detect it through the
/// controller (entity counts, event counters, state) and offer a "Show me"
/// demo that performs it.
List<TutorialStep> buildTutorialSteps(String lang) {
  String t(String pt, String en, String es) => switch (lang) { 'en' => en, 'es' => es, 'pt' => pt, _ => packTutorialText(lang, en) ?? en };
  final chNav = t('Navegação', 'Navigation', 'Navegación');
  final chEdit = t('Seleção e edição', 'Selection and editing', 'Selección y edición');
  final chDraw = t('Desenho', 'Drawing', 'Dibujo');
  final chTerrain = t('Terreno', 'Terrain', 'Terreno');
  final chHyd = t('Rede hidráulica', 'Hydraulic network', 'Red hidráulica');
  final chDesign = t('Projeto e resultados', 'Design and results', 'Diseño y resultados');
  final chFiles = t('Arquivos e ajuda', 'Files and help', 'Archivos y ayuda');

  // ---- helpers
  Pt base(TutorialContext x) {
    final b = x.c.project.bounds;
    return b.isEmpty ? const Pt(0, 0) : Pt(b.minX, b.minY - 40);
  }

  String nid(TutorialContext x) => x.c.project.newId();
  int countOf(TutorialContext x, bool Function(Entity) match) => x.c.project.entities.where(match).length;

  /// Done when a controller event counter grew since the step started.
  TutorialStep ev({required String id, required String chapter, required String title, required String body, GlobalKey? target, required String action, required String event, void Function(TutorialContext)? prepare, required void Function(TutorialContext) demo}) => TutorialStep(
    id: id,
    chapter: chapter,
    title: title,
    body: body,
    target: target,
    action: action,
    prepare: (x) {
      prepare?.call(x);
      x.memo['ev:$id'] = x.c.eventCount(event);
    },
    demo: demo,
    isDone: (x) => x.c.eventCount(event) > (x.memo['ev:$id'] as int? ?? 0),
  );

  /// Done when the number of matching entities grew since the step started.
  TutorialStep count({required String id, required String chapter, required String title, required String body, GlobalKey? target, required String action, required bool Function(Entity) match, ToolId? tool, HydraulicScope? scope, required void Function(TutorialContext) demo}) => TutorialStep(
    id: id,
    chapter: chapter,
    title: title,
    body: body,
    target: target,
    action: action,
    prepare: (x) {
      if (scope != null) x.c.toolSettings.pointScope = scope;
      if (tool != null) x.c.setTool(tool);
      x.memo['n:$id'] = countOf(x, match);
    },
    demo: demo,
    isDone: (x) => countOf(x, match) > (x.memo['n:$id'] as int? ?? 0),
  );

  /// Done when a state value differs from the one recorded at the start.
  TutorialStep state<T>({required String id, required String chapter, required String title, required String body, GlobalKey? target, required String action, required T Function(TutorialContext) read, void Function(TutorialContext)? prepare, required void Function(TutorialContext) demo}) => TutorialStep(
    id: id,
    chapter: chapter,
    title: title,
    body: body,
    target: target,
    action: action,
    prepare: (x) {
      prepare?.call(x);
      x.memo['s:$id'] = read(x);
    },
    demo: demo,
    isDone: (x) => read(x) != x.memo['s:$id'],
  );

  final editTools = {ToolId.rotate, ToolId.mirror, ToolId.scale, ToolId.offset, ToolId.trim, ToolId.extend, ToolId.cutPipe};
  final reportTab = reportTabKeys.indexOf;

  return [
    // ------------------------------------------------------------ navigation
    TutorialStep(
      id: 'welcome',
      chapter: chNav,
      title: t('Visão geral', 'Overview', 'Visión general'),
      body: t(
        'Menus no topo, paleta de ferramentas à esquerda, canvas CAD no centro, propriedades e camadas à direita, barra de status embaixo. Um pomar de exemplo com dois blocos já está carregado. Cada passo deste tutorial pede uma ação e reconhece quando você a fez; "Mostrar" faz por você.',
        'Menus at the top, tool palette on the left, CAD canvas in the centre, properties and layers on the right, status bar at the bottom. An example orchard with two blocks is loaded. Each step of this tutorial asks for an action and recognises when you have done it; "Show me" does it for you.',
        'Menús arriba, paleta de herramientas a la izquierda, lienzo CAD en el centro, propiedades y capas a la derecha, barra de estado abajo. Ya está cargado un huerto de ejemplo con dos bloques. Cada paso de este tutorial pide una acción y reconoce cuando la hizo; "Mostrar" la hace por usted.',
      ),
    ),
    state<double>(
      id: 'zoom',
      chapter: chNav,
      title: t('Zoom', 'Zoom', 'Zoom'),
      target: TutorialTargets.canvas,
      body: t('A roda do mouse aproxima e afasta em torno do cursor; + e − também. No celular, pinça.', 'The mouse wheel zooms around the cursor; + and − too. On a phone, pinch.', 'La rueda del ratón acerca y aleja alrededor del cursor; + y − también. En el móvil, pellizque.'),
      action: t('Gire a roda do mouse sobre o desenho', 'Roll the mouse wheel over the drawing', 'Gire la rueda del ratón sobre el dibujo'),
      read: (x) => x.c.camera.scale,
      demo: (x) => x.c.zoomBy(1.4),
    ),
    ev(
      id: 'pan',
      chapter: chNav,
      title: t('Mover a vista', 'Panning', 'Mover la vista'),
      target: TutorialTargets.canvas,
      body: t('Arraste com o botão do meio ou o direito, segure Espaço e arraste, ou use as setas do teclado.', 'Drag with the middle or right button, hold Space and drag, or use the arrow keys.', 'Arrastre con el botón central o el derecho, mantenga Espacio y arrastre, o use las flechas.'),
      action: t('Mova a vista arrastando com o botão direito', 'Pan by dragging with the right button', 'Mueva la vista arrastrando con el botón derecho'),
      event: 'pan',
      demo: (x) {
        x.c.camera.panPixels(const Offset(80, 40));
        x.c.track('pan');
        x.c.refresh();
      },
    ),
    ev(
      id: 'zoomAll',
      chapter: chNav,
      title: t('Enquadrar tudo', 'Zoom all', 'Encuadrar todo'),
      target: TutorialTargets.canvas,
      body: t('Home (ou o alias Z, ou Ver → Enquadrar tudo) mostra o projeto inteiro.', 'Home (or the alias Z, or View → Zoom all) shows the whole design.', 'Inicio (o el alias Z, o Ver → Encuadrar todo) muestra el proyecto completo.'),
      action: t('Pressione Home', 'Press Home', 'Pulse Inicio'),
      event: 'zoomAll',
      demo: (x) => x.c.zoomAll(),
    ),
    // ------------------------------------------------------------ selection and editing
    TutorialStep(
      id: 'select',
      chapter: chEdit,
      title: t('Selecionar', 'Selecting', 'Seleccionar'),
      target: TutorialTargets.paletteNav,
      body: t('Com a ferramenta Selecionar (Esc volta para ela), clique num objeto. Shift adiciona à seleção.', 'With the Select tool (Esc returns to it), click an object. Shift adds to the selection.', 'Con la herramienta Seleccionar (Esc vuelve a ella), haga clic en un objeto. Shift añade a la selección.'),
      action: t('Clique numa válvula (triângulo laranja) ou num tubo', 'Click a valve (orange triangle) or a pipe', 'Clic en una válvula (triángulo naranja) o una tubería'),
      prepare: (x) {
        x.c.setTool(ToolId.select);
        x.c.select(const []);
      },
      demo: (x) {
        final v = x.c.project.entities.whereType<ControlValveEntity>().firstOrNull ?? x.c.project.entities.firstOrNull;
        if (v != null) {
          x.c.select([v.id]);
          x.c.zoomToEntity(v.id);
        }
      },
      isDone: (x) => x.c.selection.isNotEmpty,
    ),
    TutorialStep(
      id: 'window',
      chapter: chEdit,
      title: t('Seleção por janela', 'Window selection', 'Selección por ventana'),
      target: TutorialTargets.canvas,
      body: t('Arraste da esquerda para a direita para pegar o que estiver totalmente dentro; da direita para a esquerda, tudo o que a janela cruzar.', 'Drag left to right for fully enclosed objects; right to left for everything the window crosses.', 'Arrastre de izquierda a derecha para tomar lo totalmente incluido; de derecha a izquierda, todo lo que la ventana cruce.'),
      action: t('Arraste uma janela sobre um bloco (3 objetos ou mais)', 'Drag a window over a block (3 objects or more)', 'Arrastre una ventana sobre un bloque (3 objetos o más)'),
      prepare: (x) {
        x.c.setTool(ToolId.select);
        x.c.select(const []);
      },
      demo: (x) => x.c.select(x.c.project.entities.take(4).map((e) => e.id)),
      isDone: (x) => x.c.selection.length >= 3,
    ),
    ev(
      id: 'move',
      chapter: chEdit,
      title: t('Mover', 'Moving', 'Mover'),
      target: TutorialTargets.canvas,
      body: t('Arraste um objeto selecionado para movê-lo. Com um só objeto selecionado aparecem alças: arraste um vértice, arraste a alça do meio para inserir um vértice, Ctrl + clique remove.', 'Drag a selected object to move it. With a single object selected, grips appear: drag a vertex, drag the midpoint grip to insert a vertex, Ctrl + click removes one.', 'Arrastre un objeto seleccionado para moverlo. Con un solo objeto seleccionado aparecen pinzas: arrastre un vértice, arrastre la pinza del medio para insertar un vértice, Ctrl + clic lo elimina.'),
      action: t('Arraste a seleção para outro lugar', 'Drag the selection somewhere else', 'Arrastre la selección a otro lugar'),
      event: 'edit',
      prepare: (x) {
        x.c.setTool(ToolId.select);
        if (x.c.selection.isEmpty) {
          final e = x.c.project.entities.whereType<ControlValveEntity>().firstOrNull;
          if (e != null) x.c.select([e.id]);
        }
      },
      demo: (x) => x.c.moveSelected(const Pt(3, 0)),
    ),
    ev(
      id: 'undo',
      chapter: chEdit,
      title: t('Desfazer e refazer', 'Undo and redo', 'Deshacer y rehacer'),
      target: TutorialTargets.menuEdit,
      body: t('Ctrl+Z desfaz (ou o alias U), Ctrl+Y refaz. Toda edição, inclusive o dimensionamento, pode ser desfeita.', 'Ctrl+Z undoes (or the alias U), Ctrl+Y redoes. Every edit, including sizing, can be undone.', 'Ctrl+Z deshace (o el alias U), Ctrl+Y rehace. Toda edición, incluido el dimensionamiento, puede deshacerse.'),
      action: t('Pressione Ctrl+Z para desfazer o movimento', 'Press Ctrl+Z to undo the move', 'Pulse Ctrl+Z para deshacer el movimiento'),
      event: 'undo',
      demo: (x) => x.c.undo(),
    ),
    state<int>(
      id: 'history',
      chapter: chEdit,
      title: t('Histórico (voltar no tempo)', 'History (going back in time)', 'Historial (volver en el tiempo)'),
      target: TutorialTargets.sideTabs,
      body: t('A aba Histórico, ao lado de Propriedades e Camadas, lista cada ação desde a abertura do arquivo, como no Photoshop. Clique num passo para voltar (ou avançar) até ele; os passos à frente ficam em cinza e podem ser refeitos, até que uma nova edição os descarte. Ctrl+Z e Ctrl+Y andam um passo por vez.', 'The History tab, next to Properties and Layers, lists every action since the file was opened, Photoshop-style. Click a step to go back (or forward) to it; the steps ahead turn grey and can be redone until a new edit discards them. Ctrl+Z and Ctrl+Y move one step at a time.', 'La pestaña Historial, junto a Propiedades y Capas, lista cada acción desde la apertura del archivo, como en Photoshop. Haga clic en un paso para volver (o avanzar) hasta él; los pasos siguientes quedan en gris y pueden rehacerse, hasta que una nueva edición los descarte. Ctrl+Z y Ctrl+Y avanzan un paso a la vez.'),
      action: t('Abra a aba Histórico', 'Open the History tab', 'Abra la pestaña Historial'),
      read: (x) => x.host.sideTab,
      prepare: (x) => x.host.showSideTab(0),
      demo: (x) => x.host.showSideTab(2),
    ),
    ev(
      id: 'properties',
      chapter: chEdit,
      title: t('Painel de propriedades', 'Properties panel', 'Panel de propiedades'),
      target: TutorialTargets.sidePanel,
      body: t('Tudo o que está selecionado é editado aqui: nome, camada, tubo ("Automático" deixa o programa dimensionar), emissor, pressão, espaçamento, válvula, fonte, bomba… Depois de um projeto, a seção Resultados mostra vazão, velocidade e pressões do item.', 'Whatever is selected is edited here: name, layer, pipe ("Automatic" lets the program size it), outlet, pressure, spacing, valve, supply, pump… After a design, the Results section shows flow, velocity and pressures for the item.', 'Todo lo seleccionado se edita aquí: nombre, capa, tubería ("Automático" deja que el programa la dimensione), emisor, presión, espaciamiento, válvula, fuente, bomba… Tras un diseño, la sección Resultados muestra caudal, velocidad y presiones del elemento.'),
      action: t('Selecione uma válvula e mude o nome dela', 'Select a valve and change its name', 'Seleccione una válvula y cambie su nombre'),
      event: 'edit',
      prepare: (x) {
        x.host.showLayersTab(false);
        x.c.setTool(ToolId.select);
        final v = x.c.project.entities.whereType<ControlValveEntity>().firstOrNull;
        if (v != null && x.c.selection.length != 1) x.c.select([v.id]);
      },
      demo: (x) {
        final v = x.c.project.entities.whereType<ControlValveEntity>().firstOrNull;
        if (v == null) return;
        x.c.select([v.id]);
        x.c.mutate(() => v.name = t('Válvula do pomar', 'Orchard valve', 'Válvula del huerto'), invalidateResults: false);
      },
    ),
    ev(
      id: 'delete',
      chapter: chEdit,
      title: t('Excluir', 'Deleting', 'Eliminar'),
      target: TutorialTargets.canvas,
      body: t('Del apaga a seleção (ou o alias E). Ctrl+Z traz de volta.', 'Del deletes the selection (or the alias E). Ctrl+Z brings it back.', 'Supr elimina la selección (o el alias E). Ctrl+Z la recupera.'),
      action: t('Selecione algo e pressione Del', 'Select something and press Del', 'Seleccione algo y pulse Supr'),
      event: 'delete',
      demo: (x) {
        final id = nid(x);
        x.c.addEntity(CircleEntity(id: id, center: base(x) + const Pt(10, 0), radius: 4));
        x.c.select([id]);
        x.c.deleteSelected();
      },
    ),
    ev(
      id: 'duplicate',
      chapter: chEdit,
      title: t('Duplicar e copiar', 'Duplicate and copy', 'Duplicar y copiar'),
      target: TutorialTargets.menuEdit,
      body: t('Ctrl+D duplica a seleção ao lado. Ctrl+C / Ctrl+X / Ctrl+V copiam, recortam e colam, inclusive entre abas de projeto. Editar → Matriz (ARRAY) repete a seleção em linhas e colunas.', 'Ctrl+D duplicates the selection beside itself. Ctrl+C / Ctrl+X / Ctrl+V copy, cut and paste, also between project tabs. Edit → Array repeats the selection in rows and columns.', 'Ctrl+D duplica la selección al lado. Ctrl+C / Ctrl+X / Ctrl+V copian, cortan y pegan, también entre pestañas de proyecto. Editar → Matriz (ARRAY) repite la selección en filas y columnas.'),
      action: t('Selecione um objeto e pressione Ctrl+D', 'Select an object and press Ctrl+D', 'Seleccione un objeto y pulse Ctrl+D'),
      event: 'duplicate',
      demo: (x) {
        final id = nid(x);
        x.c.addEntity(CircleEntity(id: id, center: base(x) + const Pt(20, 0), radius: 3));
        x.c.select([id]);
        x.c.duplicateSelected();
      },
    ),
    TutorialStep(
      id: 'layers',
      chapter: chEdit,
      title: t('Camadas', 'Layers', 'Capas'),
      target: TutorialTargets.sideTabs,
      body: t('A aba Camadas agrupa os objetos (tubos de zona, linha principal, emissores, raios molhados, curvas de nível, áreas, rótulos…): cada camada tem cor, visibilidade e bloqueio, e mostra quantos objetos contém.', 'The Layers tab groups the objects (zone pipes, mainline, outlets, wetted radii, contours, areas, labels…): each layer has a colour, visibility and a lock, and shows how many objects it holds.', 'La pestaña Capas agrupa los objetos (tuberías de zona, línea principal, emisores, radios mojados, curvas de nivel, áreas, etiquetas…): cada capa tiene color, visibilidad y bloqueo, y muestra cuántos objetos contiene.'),
      action: t('Abra a aba Camadas', 'Open the Layers tab', 'Abra la pestaña Capas'),
      prepare: (x) => x.host.showLayersTab(false),
      demo: (x) => x.host.showLayersTab(true),
      isDone: (x) => x.host.layersTabShown,
    ),
    state<String>(
      id: 'layerToggle',
      chapter: chEdit,
      title: t('Ligar e desligar camadas', 'Showing and hiding layers', 'Mostrar y ocultar capas'),
      target: TutorialTargets.sidePanel,
      body: t('O olho de cada camada esconde seus objetos; o cadeado impede edições. Útil para limpar a tela antes de imprimir.', 'The eye of each layer hides its objects; the padlock prevents edits. Handy to clean the screen before plotting.', 'El ojo de cada capa oculta sus objetos; el candado impide ediciones. Útil para limpiar la pantalla antes de imprimir.'),
      action: t('Desligue a camada Raios molhados', 'Hide the Wetted radii layer', 'Oculte la capa Radios mojados'),
      prepare: (x) => x.host.showLayersTab(true),
      read: (x) => x.c.project.layers.map((l) => '${l.name}:${l.visible}').join(','),
      demo: (x) => x.c.toggleLayer(Layers.wettedRadii),
    ),
    // ------------------------------------------------------------ drawing
    state<bool>(
      id: 'snap',
      chapter: chDraw,
      title: t('Snap (F3)', 'Snap (F3)', 'Snap (F3)'),
      target: TutorialTargets.statusToggles,
      body: t('O snap engancha o cursor em nós, extremidades, pontos médios e sobre tubos: é assim que emissores e válvulas se conectam aos tubos. Grade (F9) engancha em múltiplos da grade; F7 mostra a grade.', 'Snap locks the cursor onto nodes, endpoints, midpoints and onto pipes: this is how outlets and valves connect to pipes. Grid (F9) snaps to grid multiples; F7 shows the grid.', 'El snap engancha el cursor a nudos, extremos, puntos medios y sobre tuberías: así es como emisores y válvulas se conectan a las tuberías. Cuadrícula (F9) engancha a múltiplos de la cuadrícula; F7 muestra la cuadrícula.'),
      action: t('Pressione F3 (ou clique em Snap na barra de status) para alternar', 'Press F3 (or click Snap in the status bar) to toggle', 'Pulse F3 (o clic en Snap en la barra de estado) para alternar'),
      prepare: (x) => x.host.showLayersTab(false),
      read: (x) => x.c.snap.enabled,
      demo: (x) {
        x.c.snap.enabled = !x.c.snap.enabled;
        x.c.refresh();
      },
    ),
    state<bool>(
      id: 'ortho',
      chapter: chDraw,
      title: t('Orto (F8)', 'Ortho (F8)', 'Orto (F8)'),
      target: TutorialTargets.statusToggles,
      body: t('Orto trava todo segmento em horizontal ou vertical, como no AutoCAD. Deixe ligado para desenhar tubos alinhados.', 'Ortho locks every segment to horizontal or vertical, as in AutoCAD. Keep it on to draw aligned pipes.', 'Orto bloquea cada segmento en horizontal o vertical, como en AutoCAD. Déjelo activado para dibujar tuberías alineadas.'),
      action: t('Pressione F8 para alternar o modo orto', 'Press F8 to toggle ortho', 'Pulse F8 para alternar el modo orto'),
      read: (x) => x.c.snap.ortho,
      demo: (x) {
        x.c.snap.ortho = !x.c.snap.ortho;
        x.c.refresh();
      },
    ),
    count(
      id: 'line',
      chapter: chDraw,
      title: t('Linha', 'Line', 'Línea'),
      target: TutorialTargets.paletteDraw,
      body: t('Linha, polilinha, retângulo, círculo, arco, spline, hachura, texto e cotas desenham o fundo do projeto (divisas, estradas, edificações). Escolha na paleta, no menu Desenhar ou digitando o alias.', 'Line, polyline, rectangle, circle, arc, spline, hatch, text and dimensions draw the background of the design (boundaries, roads, buildings). Pick them in the palette, the Draw menu or by typing the alias.', 'Línea, polilínea, rectángulo, círculo, arco, spline, sombreado, texto y cotas dibujan el fondo del proyecto (linderos, caminos, edificios). Elíjalos en la paleta, en el menú Dibujar o escribiendo el alias.'),
      action: t('Escolha Linha (L) e clique em dois pontos', 'Pick Line (L) and click two points', 'Elija Línea (L) y haga clic en dos puntos'),
      match: (e) => e is LineEntity,
      tool: ToolId.line,
      demo: (x) => x.c.addEntity(LineEntity(id: nid(x), a: base(x), b: base(x) + const Pt(30, 12))),
    ),
    ev(
      id: 'shiftLock',
      chapter: chDraw,
      title: t('Shift trava o ângulo', 'Shift locks the angle', 'Shift bloquea el ángulo'),
      target: TutorialTargets.canvas,
      body: t('Como no Photoshop: segure Shift enquanto desenha e o segmento trava em 0°, 45° ou 90° a partir do ponto anterior. A barra de status mostra [45°].', 'As in Photoshop: hold Shift while drawing and the segment locks to 0°, 45° or 90° from the previous point. The status bar shows [45°].', 'Como en Photoshop: mantenga Shift mientras dibuja y el segmento se bloquea en 0°, 45° o 90° desde el punto anterior. La barra de estado muestra [45°].'),
      action: t('Com Linha ativa, clique um ponto e, segurando Shift, clique o segundo', 'With Line active, click a point and, holding Shift, click the second', 'Con Línea activa, haga clic en un punto y, manteniendo Shift, en el segundo'),
      event: 'lock',
      prepare: (x) => x.c.setTool(ToolId.line),
      demo: (x) {
        x.c.addEntity(LineEntity(id: nid(x), a: base(x) + const Pt(0, -8), b: base(x) + const Pt(30, -8)));
        x.c.track('lock');
      },
    ),
    count(
      id: 'polyline',
      chapter: chDraw,
      title: t('Polilinha', 'Polyline', 'Polilínea'),
      target: TutorialTargets.paletteDraw,
      body: t('Clique nos vértices; Enter ou duplo clique termina, Backspace apaga o último ponto, Esc cancela.', 'Click the vertices; Enter or double-click ends, Backspace removes the last point, Esc cancels.', 'Clic en los vértices; Intro o doble clic termina, Retroceso borra el último punto, Esc cancela.'),
      action: t('Digite PL, clique três pontos e pressione Enter', 'Type PL, click three points and press Enter', 'Escriba PL, haga clic en tres puntos y pulse Intro'),
      match: (e) => e is PolylineEntity,
      tool: ToolId.polyline,
      demo: (x) => x.c.addEntity(PolylineEntity(id: nid(x), points: [base(x) + const Pt(40, 0), base(x) + const Pt(55, 10), base(x) + const Pt(70, 0)])),
    ),
    count(
      id: 'circle',
      chapter: chDraw,
      title: t('Círculo e retângulo', 'Circle and rectangle', 'Círculo y rectángulo'),
      target: TutorialTargets.paletteDraw,
      body: t('Círculo (C): centro e um ponto do raio. Retângulo (REC): dois cantos opostos.', 'Circle (C): centre and a point on the radius. Rectangle (REC): two opposite corners.', 'Círculo (C): centro y un punto del radio. Rectángulo (REC): dos esquinas opuestas.'),
      action: t('Digite C e clique o centro e o raio', 'Type C and click the centre and the radius', 'Escriba C y haga clic en el centro y el radio'),
      match: (e) => e is CircleEntity,
      tool: ToolId.circle,
      demo: (x) => x.c.addEntity(CircleEntity(id: nid(x), center: base(x) + const Pt(85, 5), radius: 5)),
    ),
    count(
      id: 'text',
      chapter: chDraw,
      title: t('Texto', 'Text', 'Texto'),
      target: TutorialTargets.paletteDraw,
      body: t('Texto (T): clique o ponto e digite; altura e rotação ficam nas propriedades. Rótulos de vazão e pressão são gerados automaticamente depois do projeto.', 'Text (T): click the point and type; height and rotation are in the properties. Flow and pressure labels are generated automatically after the design.', 'Texto (T): haga clic en el punto y escriba; altura y rotación están en las propiedades. Las etiquetas de caudal y presión se generan automáticamente tras el diseño.'),
      action: t('Digite T, clique no desenho e escreva um texto', 'Type T, click the drawing and write a text', 'Escriba T, haga clic en el dibujo y escriba un texto'),
      match: (e) => e is TextEntity,
      tool: ToolId.text,
      demo: (x) => x.c.addEntity(TextEntity(id: nid(x), position: base(x) + const Pt(0, -20), text: t('Pomar Norte', 'North orchard', 'Huerto Norte'), height: 3)),
    ),
    count(
      id: 'dimension',
      chapter: chDraw,
      title: t('Cotas e medidas', 'Dimensions and measuring', 'Cotas y medidas'),
      target: TutorialTargets.paletteDraw,
      body: t('Cota (D): dois pontos e a posição da linha de cota; há cotas angulares (DAN) e radiais (DRA). Medir (ME) mostra distância e área sem criar nada.', 'Dimension (D): two points and the dimension line position; there are angular (DAN) and radial (DRA) dimensions. Measure (ME) shows distance and area without creating anything.', 'Cota (D): dos puntos y la posición de la línea de cota; hay cotas angulares (DAN) y radiales (DRA). Medir (ME) muestra distancia y área sin crear nada.'),
      action: t('Digite D e clique dois pontos e a posição da cota', 'Type D and click two points and the dimension position', 'Escriba D y haga clic en dos puntos y la posición de la cota'),
      match: (e) => e is DimensionEntity,
      tool: ToolId.dimension,
      demo: (x) => x.c.addEntity(DimensionEntity(id: nid(x), a: base(x) + const Pt(40, -12), b: base(x) + const Pt(70, -12), offset: 4)),
    ),
    ev(
      id: 'commands',
      chapter: chDraw,
      title: t('Comandos digitados', 'Typed commands', 'Comandos escritos'),
      target: TutorialTargets.statusBar,
      body: t('Com o desenho em foco, digite o alias como no AutoCAD (L, PL, C, REC, ZP, MP, SL, V, WS…) e Enter ou Espaço; após uma pausa curta ele executa sozinho. A barra de status mostra o comando e o que ele vai fazer. Ajuda → Atalhos lista todos.', 'With the drawing focused, type the alias as in AutoCAD (L, PL, C, REC, ZP, MP, SL, V, WS…) and Enter or Space; after a short pause it runs by itself. The status bar shows the command and what it will do. Help → Shortcuts lists them all.', 'Con el dibujo activo, escriba el alias como en AutoCAD (L, PL, C, REC, ZP, MP, SL, V, WS…) e Intro o Espacio; tras una pausa corta se ejecuta solo. La barra de estado muestra el comando y lo que hará. Ayuda → Atajos los lista todos.'),
      action: t('Digite REC e pressione Enter', 'Type REC and press Enter', 'Escriba REC y pulse Intro'),
      event: 'command',
      demo: (x) => x.host.typeCommand('REC'),
    ),
    TutorialStep(
      id: 'editing',
      chapter: chDraw,
      title: t('Rotacionar, espelhar, aparar…', 'Rotate, mirror, trim…', 'Rotar, simetría, recortar…'),
      target: TutorialTargets.paletteDraw,
      body: t('O grupo de edição da paleta (ou RO, MI, SC, O, TR, EX, CUT) rotaciona, espelha, escala, desloca (offset), apara, estende e corta tubos da seleção. Inserir válvula, junção, bomba ou acessório sobre um tubo divide o tubo no ponto.', 'The editing group of the palette (or RO, MI, SC, O, TR, EX, CUT) rotates, mirrors, scales, offsets, trims, extends and cuts pipes of the selection. Inserting a valve, junction, pump or device on a pipe splits it at that point.', 'El grupo de edición de la paleta (o RO, MI, SC, O, TR, EX, CUT) rota, refleja, escala, desfasa, recorta, alarga y corta tuberías de la selección. Insertar válvula, nudo, bomba o accesorio sobre una tubería la divide en ese punto.'),
      action: t('Escolha Rotacionar, Espelhar ou Aparar', 'Pick Rotate, Mirror or Trim', 'Elija Rotar, Simetría o Recortar'),
      prepare: (x) => x.c.setTool(ToolId.select),
      demo: (x) => x.c.setTool(ToolId.rotate),
      isDone: (x) => editTools.contains(x.c.activeTool),
    ),
    // ------------------------------------------------------------ terrain
    count(
      id: 'contour',
      chapter: chTerrain,
      title: t('Curvas de nível', 'Contours', 'Curvas de nivel'),
      target: TutorialTargets.paletteTerrain,
      body: t('Curvas de nível e cotas de ponto formam o modelo digital do terreno (triangulação): a elevação de cada tubo e emissor é interpolada delas e entra no cálculo das pressões. Cada curva liga pontos de mesma altitude: ao terminar (Enter), uma janela pede a elevação e já prepara a próxima curva somando o intervalo (ex.: 100, 101, 102 m). Também dá para importar DXF, pontos CSV ou baixar a elevação da internet (Projeto → Terreno).', 'Contours and spot heights form the digital terrain model (triangulation): the elevation of every pipe and outlet is interpolated from them and enters the pressure calculations. Each contour joins points of the same altitude: when you finish (Enter) a window asks for the elevation and prepares the next contour by adding the interval (e.g. 100, 101, 102 m). You can also import DXF, CSV points or download elevation from the internet (Design → Terrain).', 'Las curvas de nivel y las cotas de punto forman el modelo digital del terreno (triangulación): la elevación de cada tubería y emisor se interpola de ellas y entra en el cálculo de presiones. Cada curva une puntos de la misma altitud: al terminar (Intro) una ventana pide la elevación y prepara la siguiente curva sumando el intervalo (p. ej. 100, 101, 102 m). También puede importar DXF, puntos CSV o descargar la elevación de internet (Diseño → Terreno).'),
      action: t('Digite CT, clique os pontos da curva, Enter e confirme a elevação', 'Type CT, click the contour points, Enter and confirm the elevation', 'Escriba CT, haga clic en los puntos de la curva, Intro y confirme la elevación'),
      match: (e) => e is ContourEntity,
      tool: ToolId.contour,
      demo: (x) => x.c.addEntity(ContourEntity(id: nid(x), points: [base(x) + const Pt(-10, -30), base(x) + const Pt(40, -28), base(x) + const Pt(90, -32)], elevation: 101)),
    ),
    count(
      id: 'spot',
      chapter: chTerrain,
      title: t('Cota de ponto', 'Spot height', 'Cota de punto'),
      target: TutorialTargets.paletteTerrain,
      body: t('Uma cota de ponto (SP) fixa a elevação num lugar: poço, casa de bombas, cantos do talhão. A cada clique a elevação é pedida (desligue em Propriedades da ferramenta para usar sempre o mesmo valor). Projeto → Terreno → Vista 3D mostra o modelo resultante e Gerar curvas de nível desenha as curvas do modelo.', 'A spot height (SP) fixes the elevation at one place: well, pump house, field corners. The elevation is asked at each click (turn it off in the tool properties to reuse the same value). Design → Terrain → 3D view shows the resulting model and Generate contours draws the model\'s contours.', 'Una cota de punto (SP) fija la elevación en un lugar: pozo, casa de bombas, esquinas de la parcela. En cada clic se pide la elevación (desactívelo en las propiedades de la herramienta para usar siempre el mismo valor). Diseño → Terreno → Vista 3D muestra el modelo resultante y Generar curvas de nivel dibuja las curvas del modelo.'),
      action: t('Digite SP, clique um ponto e informe a elevação', 'Type SP, click a point and give the elevation', 'Escriba SP, haga clic en un punto e indique la elevación'),
      match: (e) => e is SpotHeightEntity,
      tool: ToolId.spot,
      demo: (x) => x.c.addEntity(SpotHeightEntity(id: nid(x), position: base(x) + const Pt(100, -10), elevation: 103.5)),
    ),
    TutorialStep(
      id: 'terrainOnline',
      chapter: chTerrain,
      title: t('Elevação da internet e curvas do modelo', 'Elevation from the internet and model contours', 'Elevación de internet y curvas del modelo'),
      target: TutorialTargets.menuDesign,
      body: t('Projeto → Terreno reúne as ferramentas de relevo: Baixar elevação da internet cria uma grade de cotas a partir de um modelo digital público (precisa da georreferência em Arquivo → Georreferência); Gerar curvas de nível desenha curvas a partir do modelo; Interpolação escolhe triangulação (MDT) ou inverso da distância; Limpar perfil apaga o caminho roxo do perfil.', 'Design → Terrain gathers the relief tools: Download elevation from the internet creates a grid of spot heights from a public digital elevation model (needs the georeference in File → Georeference); Generate contours draws contours from the model; Interpolation picks triangulation (DTM) or inverse distance; Clear profile removes the purple profile path.', 'Diseño → Terreno reúne las herramientas de relieve: Descargar elevación de internet crea una malla de cotas desde un modelo digital público (necesita la georreferencia en Archivo → Georreferencia); Generar curvas de nivel dibuja curvas desde el modelo; Interpolación elige triangulación (MDT) o inverso de la distancia; Limpiar perfil borra el camino morado del perfil.'),
      prepare: (x) => x.c.setTool(ToolId.select),
    ),
    count(
      id: 'area',
      chapter: chTerrain,
      title: t('Área irrigada', 'Irrigated area', 'Área regada'),
      target: TutorialTargets.paletteTerrain,
      body: t('A ferramenta Área (AR) define polígonos com lâmina líquida e eficiência: o relatório Requisitos hídricos calcula volume e tempo de irrigação de cada área com os emissores que ficam dentro dela.', 'The Area tool (AR) defines polygons with net depth and efficiency: the Water requirements report computes volume and irrigation time for each area from the outlets inside it.', 'La herramienta Área (AR) define polígonos con lámina neta y eficiencia: el informe Requerimientos hídricos calcula volumen y tiempo de riego de cada área con los emisores que quedan dentro.'),
      action: t('Digite AR, clique os cantos de uma área e Enter', 'Type AR, click the corners of an area and Enter', 'Escriba AR, haga clic en las esquinas de un área e Intro'),
      match: (e) => e is AreaEntity,
      tool: ToolId.area,
      demo: (x) => x.c.addEntity(AreaEntity(id: nid(x), points: [base(x) + const Pt(110, -30), base(x) + const Pt(150, -30), base(x) + const Pt(150, 0), base(x) + const Pt(110, 0)])),
    ),
    // ------------------------------------------------------------ hydraulic network
    count(
      id: 'supply',
      chapter: chHyd,
      title: t('Fonte de água', 'Water supply', 'Fuente de agua'),
      target: TutorialTargets.paletteMain,
      body: t('Toda rede começa numa fonte (poço, tanque, rede pública). Informe pressão e vazão disponíveis, ou deixe "Calcular pressão" para o programa dizer o que a fonte precisa fornecer.', 'Every network starts at a supply (well, tank, mains). Enter the available pressure and flow, or leave "Calculate pressure" so the program tells what the supply must deliver.', 'Toda red empieza en una fuente (pozo, tanque, red pública). Indique presión y caudal disponibles, o deje "Calcular presión" para que el programa diga lo que la fuente debe suministrar.'),
      action: t('Digite WS e clique onde fica a fonte', 'Type WS and click where the supply is', 'Escriba WS y haga clic donde está la fuente'),
      match: (e) => e is WaterSupplyEntity,
      tool: ToolId.supply,
      demo: (x) => x.c.addEntity(WaterSupplyEntity(id: nid(x), position: base(x) + const Pt(0, -60), name: t('Poço 2', 'Well 2', 'Pozo 2'))),
    ),
    count(
      id: 'mainPipe',
      chapter: chHyd,
      title: t('Tubo principal', 'Mainline pipe', 'Tubería principal'),
      target: TutorialTargets.paletteMain,
      body: t('Tubo principal (MP): desenhe a partir da fonte até onde ficarão as válvulas. Itens principais só se conectam a itens principais; o diâmetro pode ser fixo ou "Automático".', 'Mainline pipe (MP): draw from the supply to where the valves will be. Mainline items only connect to mainline items; the diameter can be fixed or "Automatic".', 'Tubería principal (MP): dibuje desde la fuente hasta donde estarán las válvulas. Los elementos principales solo se conectan a elementos principales; el diámetro puede ser fijo o "Automático".'),
      action: t('Digite MP e desenhe um tubo a partir da fonte nova', 'Type MP and draw a pipe from the new supply', 'Escriba MP y dibuje una tubería desde la fuente nueva'),
      match: (e) => e is PipeEntity && e.scope == HydraulicScope.mainline,
      tool: ToolId.mainPipe,
      demo: (x) => x.c.addEntity(PipeEntity(id: nid(x), points: [base(x) + const Pt(0, -60), base(x) + const Pt(60, -60)], scope: HydraulicScope.mainline)),
    ),
    count(
      id: 'pump',
      chapter: chHyd,
      title: t('Bomba e acessórios', 'Pump and devices', 'Bomba y accesorios'),
      target: TutorialTargets.paletteMain,
      body: t('Bomba (PU) e acessórios (F: filtro, hidrômetro, PRV, registro, ventosa) são inseridos sobre um tubo principal, que é dividido no ponto. A curva da bomba vem do catálogo; Linha principal → Selecionar bomba classifica as bombas para o ponto de trabalho.', 'Pump (PU) and devices (F: filter, meter, PRV, gate valve, air valve) are inserted on a mainline pipe, which is split at that point. The pump curve comes from the catalog; Mainline → Select pump ranks the pumps for the duty point.', 'Bomba (PU) y accesorios (F: filtro, contador, PRV, válvula de compuerta, ventosa) se insertan sobre una tubería principal, que se divide en ese punto. La curva de la bomba viene del catálogo; Línea principal → Seleccionar bomba clasifica las bombas para el punto de trabajo.'),
      action: t('Digite PU e clique sobre o tubo principal', 'Type PU and click on the mainline pipe', 'Escriba PU y haga clic sobre la tubería principal'),
      match: (e) => e is PumpEntity,
      tool: ToolId.pump,
      scope: HydraulicScope.mainline,
      demo: (x) => x.c.addEntity(PumpEntity(id: nid(x), position: base(x) + const Pt(10, -60))),
    ),
    count(
      id: 'valve',
      chapter: chHyd,
      title: t('Válvula de controle', 'Control valve', 'Válvula de control'),
      target: TutorialTargets.paletteZone,
      body: t('A válvula (V) separa cada zona da linha principal: conecte-a na ponta de um tubo principal. Do lado da zona saem o submain, as laterais e os emissores.', 'The valve (V) separates each zone from the mainline: connect it at the end of a mainline pipe. The submain, laterals and outlets hang on the zone side.', 'La válvula (V) separa cada zona de la línea principal: conéctela en el extremo de una tubería principal. Del lado de la zona salen el submain, las laterales y los emisores.'),
      action: t('Digite V e clique na ponta do tubo principal', 'Type V and click at the end of the mainline pipe', 'Escriba V y haga clic en el extremo de la tubería principal'),
      match: (e) => e is ControlValveEntity,
      tool: ToolId.valve,
      scope: HydraulicScope.zone,
      demo: (x) => x.c.addEntity(ControlValveEntity(id: nid(x), position: base(x) + const Pt(60, -60), valveSpecId: 'ev80', zoneName: t('Zona nova', 'New zone', 'Zona nueva'))),
    ),
    count(
      id: 'zonePipe',
      chapter: chHyd,
      title: t('Tubo de zona (submain)', 'Zone pipe (submain)', 'Tubería de zona (submain)'),
      target: TutorialTargets.paletteZone,
      body: t('Tubo de zona (ZP): do lado de jusante da válvula, desenhe o submain que alimenta as laterais.', 'Zone pipe (ZP): downstream of the valve, draw the submain that feeds the laterals.', 'Tubería de zona (ZP): aguas abajo de la válvula, dibuje el submain que alimenta las laterales.'),
      action: t('Digite ZP e desenhe um tubo a partir da válvula', 'Type ZP and draw a pipe from the valve', 'Escriba ZP y dibuje una tubería desde la válvula'),
      match: (e) => e is PipeEntity && e.scope == HydraulicScope.zone,
      tool: ToolId.zonePipe,
      demo: (x) => x.c.addEntity(PipeEntity(id: nid(x), points: [base(x) + const Pt(60, -60), base(x) + const Pt(60, -90)], scope: HydraulicScope.zone)),
    ),
    count(
      id: 'sprayline',
      chapter: chHyd,
      title: t('Lateral com emissores', 'Lateral with outlets', 'Lateral con emisores'),
      target: TutorialTargets.paletteZone,
      body: t('Lateral (SL) cria um tubo com emissores igualmente espaçados; Fita (DT) cria uma fita gotejadora com os dados do catálogo. Emissor, bocal, pressão nominal e espaçamento ficam nas propriedades; a pressão nominal e a tolerância definem a janela de pressão admissível da zona.', 'Sprayline (SL) creates a pipe with equally spaced outlets; Tape (DT) creates a drip tape with catalog data. Outlet, nozzle, nominal pressure and spacing are in the properties; the nominal pressure and tolerance define the zone\'s allowable pressure window.', 'Lateral (SL) crea una tubería con emisores igualmente espaciados; Cinta (DT) crea una cinta de goteo con los datos del catálogo. Emisor, boquilla, presión nominal y espaciamiento están en las propiedades; la presión nominal y la tolerancia definen la ventana de presión admisible de la zona.'),
      action: t('Digite SL e desenhe uma lateral a partir do submain', 'Type SL and draw a lateral from the submain', 'Escriba SL y dibuje una lateral desde el submain'),
      match: (e) => e is SpraylineEntity || e is TapeEntity,
      tool: ToolId.sprayline,
      demo: (x) => x.c.addEntity(SpraylineEntity(id: nid(x), points: [base(x) + const Pt(60, -75), base(x) + const Pt(110, -75)], outletSpecId: 'micro', nozzleId: 'm50', headM: 15, spacing: 4)),
    ),
    count(
      id: 'outlet',
      chapter: chHyd,
      title: t('Emissor avulso', 'Single outlet', 'Emisor suelto'),
      target: TutorialTargets.paletteZone,
      body: t('Emissor (EM) coloca um aspersor ou gotejador sobre um tubo de zona; o raio molhado aparece na camada Raios molhados. O catálogo traz microaspersores, aspersores de impacto, canhões e gotejadores.', 'Outlet (EM) places a sprinkler or emitter on a zone pipe; the wetted radius shows in the Wetted radii layer. The catalog has micro-sprinklers, impact sprinklers, guns and drippers.', 'Emisor (EM) coloca un aspersor o gotero sobre una tubería de zona; el radio mojado aparece en la capa Radios mojados. El catálogo trae microaspersores, aspersores de impacto, cañones y goteros.'),
      action: t('Digite EM e clique sobre o submain', 'Type EM and click on the submain', 'Escriba EM y haga clic sobre el submain'),
      match: (e) => e is OutletEntity,
      tool: ToolId.outlet,
      scope: HydraulicScope.zone,
      demo: (x) => x.c.addEntity(OutletEntity(id: nid(x), position: base(x) + const Pt(60, -85), outletSpecId: 'micro', nozzleId: 'm50', headM: 15)),
    ),
    ev(
      id: 'block',
      chapter: chHyd,
      title: t('Bloco de laterais', 'Lateral block', 'Bloque de laterales'),
      target: TutorialTargets.paletteZone,
      body: t('Bloco (B): clique os cantos do talhão, Enter, e escolha tipo (microaspersão ou gotejo), emissor, espaçamentos, direção, posição do submain e válvula: o programa gera laterais, submain, trecho e válvula prontos. É a forma mais rápida de montar uma zona.', 'Block (B): click the field corners, Enter, then choose type (micro-sprinkler or drip), outlet, spacings, direction, submain position and valve: the program generates laterals, submain, stub and valve. The fastest way to build a zone.', 'Bloque (B): haga clic en las esquinas de la parcela, Intro, y elija tipo (microaspersión o goteo), emisor, espaciamientos, dirección, posición del submain y válvula: el programa genera laterales, submain, tramo y válvula. La forma más rápida de armar una zona.'),
      action: t('Digite B, clique quatro cantos, Enter e confirme o diálogo', 'Type B, click four corners, Enter and confirm the dialog', 'Escriba B, haga clic en cuatro esquinas, Intro y confirme el diálogo'),
      event: 'block',
      prepare: (x) => x.c.setTool(ToolId.block),
      demo: (x) {
        final o = base(x) + const Pt(130, -110);
        x.c.addBlock(BlockOptions(
          polygon: [o, o + const Pt(60, 0), o + const Pt(60, 36), o + const Pt(0, 36)],
          direction: const Pt(1, 0),
          lateralSpacing: 4,
          isTape: false,
          tapeSpecId: 'drip16_16_50',
          outletSpecId: 'micro',
          nozzleId: 'm50',
          outletSpacing: 3.5,
          headM: 15,
          submainPosition: SubmainPosition.start,
          valveSpecId: 'ev80',
          valvePosition: ValvePosition.centre,
          submainStub: 1.5,
          zoneName: t('Bloco do tutorial', 'Tutorial block', 'Bloque del tutorial'),
        ));
      },
    ),
    ev(
      id: 'grid',
      chapter: chHyd,
      title: t('Grade de aspersores', 'Sprinkler grid', 'Malla de aspersores'),
      target: TutorialTargets.paletteZone,
      body: t('Grade (AH): preenche um polígono com aspersores em malha quadrada ou triangular a partir do espaçamento ou do raio molhado, para depois ligar com tubos de zona.', 'Grid (AH): fills a polygon with sprinklers in a square or triangular pattern from the spacing or the wetted radius, to be connected with zone pipes afterwards.', 'Malla (AH): rellena un polígono con aspersores en malla cuadrada o triangular a partir del espaciamiento o del radio mojado, para conectarlos luego con tuberías de zona.'),
      action: t('Digite AH, clique os cantos de uma área, Enter e confirme', 'Type AH, click the corners of an area, Enter and confirm', 'Escriba AH, haga clic en las esquinas de un área, Intro y confirme'),
      event: 'grid',
      prepare: (x) => x.c.setTool(ToolId.autohead),
      demo: (x) {
        final o = base(x) + const Pt(210, -110);
        x.c.addSprinklerGrid(SprinklerGridOptions(polygon: [o, o + const Pt(40, 0), o + const Pt(40, 30), o + const Pt(0, 30)], outletSpecId: 'micro', nozzleId: 'm50', spacingAlong: 10, spacingBetween: 10, headM: 15));
      },
    ),
    // ------------------------------------------------------------ design and results
    TutorialStep(
      id: 'params',
      chapter: chDesign,
      title: t('Parâmetros e catálogo', 'Parameters and catalog', 'Parámetros y catálogo'),
      target: TutorialTargets.menuDesign,
      body: t('Projeto → Parâmetros: fórmula de perda de carga (Hazen-Williams ou Darcy-Weisbach), temperatura, velocidades máximas, perdas localizadas, juros, prazo, custo da energia e horas/ano para o balanço entre custo de tubo e de bombeamento. Projeto → Catálogo: tubos, emissores, fitas, válvulas e bombas com preços; edite ou desabilite itens.', 'Design → Parameters: head-loss formula (Hazen-Williams or Darcy-Weisbach), temperature, maximum velocities, minor losses, interest, term, energy cost and hours/year for the pipe-cost versus pumping-cost trade-off. Design → Catalog: pipes, outlets, tapes, valves and pumps with prices; edit or disable items.', 'Diseño → Parámetros: fórmula de pérdida de carga (Hazen-Williams o Darcy-Weisbach), temperatura, velocidades máximas, pérdidas localizadas, interés, plazo, costo de la energía y horas/año para el balance entre costo de tubería y de bombeo. Diseño → Catálogo: tuberías, emisores, cintas, válvulas y bombas con precios; edite o desactive elementos.'),
      prepare: (x) => x.c.setTool(ToolId.select),
    ),
    TutorialStep(
      id: 'management',
      chapter: chDesign,
      title: t('Turnos de operação', 'System flows', 'Turnos de operación'),
      target: TutorialTargets.menuDesign,
      body: t('Projeto → Turnos de operação define quais válvulas abrem juntas e por quanto tempo. Cada turno é um caso de carga da linha principal; a fonte é dimensionada para o pior deles. "Todas juntas" e "Uma por vez" preenchem a tabela.', 'Design → System flows defines which valves open together and for how long. Each flow is a load case for the mainline; the supply is sized for the worst one. "All together" and "One at a time" fill the table.', 'Diseño → Turnos de operación define qué válvulas abren juntas y durante cuánto tiempo. Cada turno es un caso de carga de la línea principal; la fuente se dimensiona para el peor. "Todas juntas" y "Una a la vez" rellenan la tabla.'),
    ),
    ev(
      id: 'check',
      chapter: chDesign,
      title: t('Verificação do projeto (Design Check)', 'Design check', 'Verificación del diseño (Design Check)'),
      target: TutorialTargets.menuDesign,
      body: t('Projeto → Verificação do projeto (CHK) varre o desenho em busca de problemas: itens desconectados (em vermelho no desenho), tubos que se cruzam sem junção, pontas soltas, zonas sem emissores, duplicados, modelos de catálogo faltando e redes em anel. Clique num item da lista para localizá-lo e corrija movendo com snap até o tubo.', 'Design → Design check (CHK) sweeps the drawing for problems: disconnected items (red on the drawing), pipes crossing without a junction, dead ends, zones without emitters, duplicates, missing catalogue models and looped networks. Click an item of the list to locate it and fix it by moving it with snap onto the pipe.', 'Diseño → Verificación del diseño (CHK) recorre el dibujo en busca de problemas: elementos desconectados (en rojo en el dibujo), tuberías que se cruzan sin nudo, extremos sueltos, zonas sin emisores, duplicados, modelos de catálogo faltantes y redes en anillo. Haga clic en un ítem de la lista para ubicarlo y corríjalo moviéndolo con snap hasta la tubería.'),
      action: t('Execute a verificação (menu Projeto ou CHK)', 'Run the check (Design menu or CHK)', 'Ejecute la verificación (menú Diseño o CHK)'),
      event: 'check',
      demo: (x) => x.c.runDesignCheckReport(),
    ),
    TutorialStep(
      id: 'design',
      chapter: chDesign,
      title: t('Projetar (F5)', 'Design (F5)', 'Diseñar (F5)'),
      target: TutorialTargets.runButton,
      body: t('▶ ou F5 faz o ciclo completo: dimensiona os tubos automáticos de cada zona pela janela de pressão com balanço econômico, define a pressão nas válvulas, calcula a linha principal para cada turno, o que a fonte precisa fornecer, lavagem, golpe de aríete e a lista de materiais. O cálculo roda em segundo plano com um painel de progresso.', '▶ or F5 runs the full cycle: sizes each zone\'s automatic pipes by the pressure window with the economic trade-off, sets the valve pressures, computes the mainline for each system flow, what the supply must deliver, flushing, water hammer and the bill of materials. The calculation runs in the background with a progress panel.', '▶ o F5 ejecuta el ciclo completo: dimensiona las tuberías automáticas de cada zona por la ventana de presión con balance económico, fija la presión en las válvulas, calcula la línea principal para cada turno, lo que la fuente debe suministrar, lavado, golpe de ariete y la lista de materiales. El cálculo corre en segundo plano con un panel de progreso.'),
      action: t('Clique em ▶ ou pressione F5', 'Click ▶ or press F5', 'Clic en ▶ o pulse F5'),
      demo: (x) => x.c.runDesign(),
      isDone: (x) => x.c.results != null,
    ),
    state<OverlayMode>(
      id: 'overlay',
      chapter: chDesign,
      title: t('Resultados no desenho', 'Results on the drawing', 'Resultados en el dibujo'),
      target: TutorialTargets.menuView,
      body: t('Depois do projeto os tubos ficam coloridos por velocidade (azul → verde → laranja → vermelho acima do limite), válvulas e fonte mostram vazão e pressão, e os tubos mostram vazão/velocidade ao aproximar. Em Ver, troque para colorir por pressão (emissores fora da janela em vermelho/roxo) ou mostrar os diâmetros.', 'After the design, pipes are coloured by velocity (blue → green → orange → red above the limit), valves and supply show flow and pressure, and pipes show flow/velocity when zoomed in. In View, switch to colour by pressure (outlets outside the window in red/purple) or to show the diameters.', 'Tras el diseño las tuberías se colorean por velocidad (azul → verde → naranja → rojo por encima del límite), válvulas y fuente muestran caudal y presión, y las tuberías muestran caudal/velocidad al acercarse. En Ver, cambie a colorear por presión (emisores fuera de la ventana en rojo/morado) o a mostrar los diámetros.'),
      action: t('Em Ver, escolha Colorir por pressão', 'In View, choose Colour by pressure', 'En Ver, elija Colorear por presión'),
      read: (x) => x.c.overlay,
      demo: (x) {
        x.c.overlay = x.c.overlay == OverlayMode.pressure ? OverlayMode.sizes : OverlayMode.pressure;
        x.c.refresh();
      },
    ),
    TutorialStep(
      id: 'reports',
      chapter: chDesign,
      title: t('Relatórios', 'Reports', 'Informes'),
      target: TutorialTargets.reportsBar,
      body: t('O painel inferior (F2) tem abas: Resumo das zonas (vazão, pressões, janela admissível x real, CU/DU/EU), Tubos, Emissores, Linha principal/duty, Lista de materiais com custos, Requisitos hídricos, Linha piezométrica, Mensagens, Perfil, Lavagem, Golpe de aríete, Agronomia e Programação. Arraste a borda para redimensionar.', 'The bottom panel (F2) has tabs: Zone summary (flow, pressures, allowable vs actual window, CU/DU/EU), Pipes, Outlets, Mainline/duty, Bill of materials with costs, Water requirements, Hydraulic grade line, Messages, Profile, Flushing, Water hammer, Agronomy and Schedule. Drag the edge to resize.', 'El panel inferior (F2) tiene pestañas: Resumen de zonas (caudal, presiones, ventana admisible vs. real, CU/DU/EU), Tuberías, Emisores, Línea principal/demanda, Lista de materiales con costos, Requerimientos hídricos, Línea piezométrica, Mensajes, Perfil, Lavado, Golpe de ariete, Agronomía y Programación. Arrastre el borde para cambiar el tamaño.'),
      action: t('Abra os relatórios (barra inferior ou F2)', 'Open the reports (bottom bar or F2)', 'Abra los informes (barra inferior o F2)'),
      prepare: (x) => x.host.openReports(false),
      demo: (x) => x.host.openReports(true, tab: 0),
      isDone: (x) => x.c.showReports,
    ),
    TutorialStep(
      id: 'reportPipes',
      chapter: chDesign,
      title: t('Aba Tubos', 'Pipes tab', 'Pestaña Tuberías'),
      target: TutorialTargets.reportsBar,
      body: t('Cada trecho com diâmetro escolhido, vazão, velocidade, perda de carga e pressões a montante e a jusante. Clique numa linha para localizar o tubo no desenho.', 'Every segment with the chosen diameter, flow, velocity, head loss and upstream/downstream pressures. Click a row to locate the pipe on the drawing.', 'Cada tramo con el diámetro elegido, caudal, velocidad, pérdida de carga y presiones aguas arriba y abajo. Haga clic en una fila para ubicar la tubería en el dibujo.'),
      action: t('Clique na aba Tubos', 'Click the Pipes tab', 'Clic en la pestaña Tuberías'),
      prepare: (x) => x.host.openReports(true, tab: 0),
      demo: (x) => x.host.openReports(true, tab: reportTab('reports.pipes')),
      isDone: (x) => x.c.showReports && x.c.reportTab == reportTab('reports.pipes'),
    ),
    TutorialStep(
      id: 'messages',
      chapter: chDesign,
      title: t('Mensagens', 'Messages', 'Mensajes'),
      target: TutorialTargets.reportsBar,
      body: t('Avisos do projeto: velocidade acima do limite, pressão fora da janela, itens desconectados, déficit na fonte. Clique numa mensagem para selecionar e enquadrar o item.', 'Design warnings: velocity above the limit, pressure outside the window, unconnected items, supply deficit. Click a message to select and frame the item.', 'Avisos del diseño: velocidad por encima del límite, presión fuera de la ventana, elementos desconectados, déficit en la fuente. Haga clic en un mensaje para seleccionar y encuadrar el elemento.'),
      action: t('Clique na aba Mensagens', 'Click the Messages tab', 'Clic en la pestaña Mensajes'),
      demo: (x) => x.host.openReports(true, tab: reportTab('reports.messages')),
      isDone: (x) => x.c.showReports && x.c.reportTab == reportTab('reports.messages'),
    ),
    TutorialStep(
      id: 'hgl',
      chapter: chDesign,
      title: t('Linha piezométrica', 'Hydraulic grade line', 'Línea piezométrica'),
      target: TutorialTargets.reportsBar,
      body: t('Na aba Linha piezométrica, selecione um tubo, uma lateral ou uma válvula: o gráfico mostra o terreno, a linha de energia e a faixa de pressão admissível ao longo do trecho. Ideal para ver onde a pressão cai abaixo do mínimo em terreno ondulado.', 'In the Hydraulic grade line tab, select a pipe, a lateral or a valve: the chart shows the ground, the energy line and the allowable pressure band along the run. Ideal to see where pressure drops below the minimum on undulating ground.', 'En la pestaña Línea piezométrica, seleccione una tubería, una lateral o una válvula: el gráfico muestra el terreno, la línea de energía y la banda de presión admisible a lo largo del tramo. Ideal para ver dónde la presión cae por debajo del mínimo en terreno ondulado.'),
      action: t('Abra a aba Linha piezométrica e selecione uma lateral', 'Open the Hydraulic grade line tab and select a lateral', 'Abra la pestaña Línea piezométrica y seleccione una lateral'),
      prepare: (x) => x.c.setTool(ToolId.select),
      demo: (x) {
        x.host.openReports(true, tab: reportTab('reports.hgl'));
        final s = x.c.project.entities.where((e) => e is SpraylineEntity || e is TapeEntity).firstOrNull;
        if (s != null) x.c.select([s.id]);
      },
      isDone: (x) => x.c.showReports && x.c.reportTab == reportTab('reports.hgl') && x.c.selection.any((id) => x.c.project.byId(id) is SpraylineEntity || x.c.project.byId(id) is TapeEntity),
    ),
    TutorialStep(
      id: 'feed',
      chapter: chDesign,
      title: t('Envelope do submain', 'Submain envelope', 'Envolvente del submain'),
      target: TutorialTargets.menuZone,
      body: t('Zona → Envelope de posição do submain (FE) pinta em verde o trecho de cada lateral selecionada onde o submain pode ficar respeitando a janela de pressão.', 'Zone → Allowable submain position (FE) paints in green the part of each selected lateral where the submain can sit while meeting the pressure window.', 'Zona → Posición admisible del submain (FE) pinta en verde el tramo de cada lateral seleccionada donde el submain puede ubicarse cumpliendo la ventana de presión.'),
      action: t('Selecione uma lateral e digite FE', 'Select a lateral and type FE', 'Seleccione una lateral y escriba FE'),
      prepare: (x) {
        x.c.feedEnvelope.clear();
        x.c.setTool(ToolId.select);
      },
      demo: (x) {
        final s = x.c.project.entities.where((e) => e is SpraylineEntity || e is TapeEntity).firstOrNull;
        if (s != null) {
          x.c.select([s.id]);
          x.c.computeFeedEnvelope();
        }
      },
      isDone: (x) => x.c.feedEnvelope.isNotEmpty,
    ),
    TutorialStep(
      id: 'profile',
      chapter: chDesign,
      title: t('Perfil do terreno', 'Ground profile', 'Perfil del terreno'),
      target: TutorialTargets.paletteTerrain,
      body: t('Perfil (PR): clique os pontos de um caminho e Enter; a aba Perfil mostra o terreno ao longo dele (linha marrom), o ponto mais baixo (azul) e o mais alto (laranja). Selecionando um tubo já projetado aparecem também o tubo (azul, com a profundidade) e a linha piezométrica (verde): a distância vertical entre elas é a pressão. Passe o mouse pelo gráfico para ler estação, cota e pressão. A linha roxa no desenho é o caminho: Limpar (na aba) ou Esc a remove.', 'Profile (PR): click the points of a path and Enter; the Profile tab shows the ground along it (brown line), the lowest (blue) and the highest (orange) point. Selecting a designed pipe also shows the pipe (blue, with its depth) and the hydraulic grade line (green): the vertical gap between them is the pressure. Hover the chart to read station, elevation and pressure. The purple line on the drawing is the path: Clear (in the tab) or Esc removes it.', 'Perfil (PR): haga clic en los puntos de un camino e Intro; la pestaña Perfil muestra el terreno a lo largo (línea marrón), el punto más bajo (azul) y el más alto (naranja). Al seleccionar una tubería diseñada aparecen también la tubería (azul, con su profundidad) y la línea piezométrica (verde): la distancia vertical entre ellas es la presión. Pase el ratón por el gráfico para leer estación, cota y presión. La línea morada en el dibujo es el camino: Limpiar (en la pestaña) o Esc la quita.'),
      action: t('Digite PR, clique dois pontos e pressione Enter', 'Type PR, click two points and press Enter', 'Escriba PR, haga clic en dos puntos y pulse Intro'),
      prepare: (x) {
        x.c.profilePath = null;
        x.c.setTool(ToolId.profile);
      },
      demo: (x) {
        final b = x.c.project.bounds;
        x.c.setProfilePath([Pt(b.minX, b.center.y), Pt(b.maxX, b.center.y)]);
        x.host.openReports(true, tab: reportTab('reports.profile'));
      },
      isDone: (x) => x.c.profilePath != null,
    ),
    count(
      id: 'pivot',
      chapter: chDesign,
      title: t('Pivô central e lateral móvel', 'Centre pivot and linear move', 'Pivote central y lateral de avance'),
      target: TutorialTargets.menuMain,
      body: t('Linha principal → Pivô (PV): clique o ponto do pivô sobre a linha principal e depois o fim da lateral. O pivô vira um ponto de demanda: vazão pela área, lâmina e horas por volta; pressão de entrada pela perda nos vãos (fator 0,543), altura do tubo, desnível pior do círculo e pressão de ponta. Propriedades ajustam vão, tubo, canhão final e setor; a aba Pivôs traz torres, taxa de aplicação e déficit.', 'Mainline → Pivot (PV): click the pivot point on the mainline and then the end of the span. The pivot becomes a demand point: flow from area, depth and hours per revolution; inlet pressure from the span friction (0.543 factor), pipe height, worst ground rise around the circle and end pressure. Properties set span, pipe, end gun and sector; the Pivots tab lists towers, application rate and deficit.', 'Línea principal → Pivote (PV): haga clic en el punto del pivote sobre la línea principal y luego en el fin de la lateral. El pivote se vuelve un punto de demanda: caudal por área, lámina y horas por vuelta; presión de entrada por la pérdida en los vanos (factor 0,543), altura del tubo, peor desnivel del círculo y presión de punta. Propiedades ajustan vano, tubo, cañón final y sector; la pestaña Pivotes lista torres, tasa de aplicación y déficit.'),
      action: t('Digite PV, clique o ponto do pivô e o fim da lateral', 'Type PV, click the pivot point and the end of the span', 'Escriba PV, haga clic en el punto del pivote y el fin de la lateral'),
      match: (e) => e is PivotEntity,
      tool: ToolId.pivot,
      demo: (x) {
        final b = x.c.project.bounds;
        final center = Pt(b.minX - 60, b.center.y);
        x.c.addEntity(PipeEntity(id: nid(x), points: [Pt(b.minX - 5, b.center.y), center], scope: HydraulicScope.mainline));
        x.c.addPivot(center, center + const Pt(-40, 0));
      },
    ),
    TutorialStep(
      id: 'align',
      chapter: chDesign,
      title: t('Alinhar imagem ou desenho por 2 pontos', 'Align an image or drawing by 2 points', 'Alinear imagen o dibujo por 2 puntos'),
      target: TutorialTargets.menuFile,
      body: t('Importou uma foto de satélite ou um DXF fora de escala? Selecione-o e use Arquivo → Alinhar por 2 pontos (AL): clique um ponto conhecido na imagem, onde ele deve ficar, um segundo ponto e o seu destino. A seleção é movida, girada e escalada de uma vez (ou só movida e girada, com "manter escala").', 'Imported a satellite photo or a DXF out of scale? Select it and use File → Align by 2 points (AL): click a known point on the image, where it must go, a second point and its target. The selection is moved, rotated and scaled at once (or only moved and rotated with "keep scale").', '¿Importó una foto satelital o un DXF fuera de escala? Selecciónelo y use Archivo → Alinear por 2 puntos (AL): haga clic en un punto conocido de la imagen, dónde debe quedar, un segundo punto y su destino. La selección se mueve, gira y escala de una vez (o solo se mueve y gira con "mantener escala").'),
      prepare: (x) => x.c.setTool(ToolId.select),
    ),
    TutorialStep(
      id: 'calculators',
      chapter: chDesign,
      title: t('Calculadoras', 'Calculators', 'Calculadoras'),
      target: TutorialTargets.menuTools,
      body: t('Ferramentas → Calculadora de lateral: comprimento máximo, perdas e uniformidade de uma fita ou lateral em declive. Bomba e curva do sistema: ponto de operação, potência e energia anual. Golpe de aríete: sobrepressão de Joukowsky x classe do tubo. Unidades: métrico ou US.', 'Tools → Lateral calculator: maximum length, losses and uniformity of a tape or lateral on a slope. Pump & system curve: operating point, power and annual energy. Water hammer: Joukowsky surge vs pipe class. Units: metric or US.', 'Herramientas → Calculadora de lateral: longitud máxima, pérdidas y uniformidad de una cinta o lateral en pendiente. Bomba y curva del sistema: punto de operación, potencia y energía anual. Golpe de ariete: sobrepresión de Joukowsky vs. clase de tubería. Unidades: métrico o EE. UU.'),
      prepare: (x) => x.c.setTool(ToolId.select),
    ),
    // ------------------------------------------------------------ files and help
    ev(
      id: 'save',
      chapter: chFiles,
      title: t('Salvar e recuperar', 'Saving and recovering', 'Guardar y recuperar'),
      target: TutorialTargets.saveButton,
      body: t('Ctrl+S baixa o projeto como JSON aberto (.oci.json), com os resultados; Ctrl+O abre. O projeto também é salvo automaticamente no navegador: ao reabrir a página você pode recuperá-lo, e cada Salvar guarda uma versão (Arquivo → Histórico de versões).', 'Ctrl+S downloads the project as open JSON (.oci.json), results included; Ctrl+O opens it. The project is also autosaved in the browser: reopening the page offers to recover it, and every Save keeps a version (File → Version history).', 'Ctrl+S descarga el proyecto como JSON abierto (.oci.json), con los resultados; Ctrl+O lo abre. El proyecto también se guarda automáticamente en el navegador: al reabrir la página puede recuperarlo, y cada Guardar conserva una versión (Archivo → Historial de versiones).'),
      action: t('Pressione Ctrl+S', 'Press Ctrl+S', 'Pulse Ctrl+S'),
      event: 'save',
      demo: (x) => x.host.saveProject(),
    ),
    TutorialStep(
      id: 'export',
      chapter: chFiles,
      title: t('Importar e exportar', 'Import and export', 'Importar y exportar'),
      target: TutorialTargets.menuFile,
      body: t('Importar (Ctrl+I) aceita DXF, DWG (AutoCAD 2000–2018), KML/KMZ, SHP, pontos CSV/XYZ e imagens (JPG/PNG/GeoTIFF, com mapa base de satélite em Ver). Exportar desenho gera DXF, DWG, PDF (prancha com carimbo, legenda e escala; Ctrl+P), SVG, KML/KMZ e GeoJSON. Exportar relatório gera CSV, TXT, XLSX ou PDF.', 'Import (Ctrl+I) accepts DXF, DWG (AutoCAD 2000–2018), KML/KMZ, SHP, CSV/XYZ points and images (JPG/PNG/GeoTIFF, with a satellite base map under View). Export drawing writes DXF, DWG, PDF (plot sheet with title block, legend and scale; Ctrl+P), SVG, KML/KMZ and GeoJSON. Export report writes CSV, TXT, XLSX or PDF.', 'Importar (Ctrl+I) acepta DXF, DWG (AutoCAD 2000–2018), KML/KMZ, SHP, puntos CSV/XYZ e imágenes (JPG/PNG/GeoTIFF, con mapa base satelital en Ver). Exportar dibujo genera DXF, DWG, PDF (lámina con cajetín, leyenda y escala; Ctrl+P), SVG, KML/KMZ y GeoJSON. Exportar informe genera CSV, TXT, XLSX o PDF.'),
    ),
    TutorialStep(
      id: 'tabs',
      chapter: chFiles,
      title: t('Abas de projeto', 'Project tabs', 'Pestañas de proyecto'),
      body: t('Vários projetos abertos ao mesmo tempo: Ctrl+Alt+N abre uma aba, Ctrl+Alt+W fecha, Ctrl+Alt+← → alterna. Copiar e colar funciona entre abas, e Arquivo → Detalhes do projeto guarda cliente, obra e projetista.', 'Several projects open at once: Ctrl+Alt+N opens a tab, Ctrl+Alt+W closes it, Ctrl+Alt+← → switches. Copy and paste work between tabs, and File → Project details stores client, site and designer.', 'Varios proyectos abiertos a la vez: Ctrl+Alt+N abre una pestaña, Ctrl+Alt+W la cierra, Ctrl+Alt+← → alterna. Copiar y pegar funcionan entre pestañas, y Archivo → Detalles del proyecto guarda cliente, obra y proyectista.'),
    ),
    TutorialStep(
      id: 'shortcuts',
      chapter: chFiles,
      title: t('Atalhos e ajuda', 'Shortcuts and help', 'Atajos y ayuda'),
      target: TutorialTargets.menuHelp,
      body: t('Ajuda → Atalhos de teclado lista todos os comandos e teclas; Ajuda → Tutorial interativo reabre este tutorial (a URL ?tutorial=N abre num passo). Em Ver você troca o idioma e as unidades. No celular ou tablet a tela muda: menu ☰ no topo, barra de ferramentas por grupos embaixo, botões Concluir/Cancelar no lugar de Enter/Esc, propriedades e relatórios em painéis deslizantes; pinça para zoom, dois dedos para mover. Bom projeto!', 'Help → Keyboard shortcuts lists every command and key; Help → Interactive tutorial reopens this tutorial (the URL ?tutorial=N opens at a step). View switches the language and units. On a phone or tablet the screen changes: ☰ menu at the top, tool bar by groups at the bottom, Done/Cancel buttons instead of Enter/Esc, properties and reports in sliding sheets; pinch to zoom, two fingers to pan. Happy designing!', 'Ayuda → Atajos de teclado lista todos los comandos y teclas; Ayuda → Tutorial interactivo reabre este tutorial (la URL ?tutorial=N abre en un paso). En Ver cambia el idioma y las unidades. En móvil o tableta la pantalla cambia: menú ☰ arriba, barra de herramientas por grupos abajo, botones Terminar/Cancelar en lugar de Intro/Esc, propiedades e informes en paneles deslizantes; pellizco para zoom, dos dedos para mover. ¡Buen diseño!'),
      prepare: (x) => x.c.setTool(ToolId.select),
    ),
  ];
}

// ---------------------------------------------------------------- overlay

class TutorialOverlay extends StatefulWidget {
  const TutorialOverlay({super.key, required this.tutorial, required this.controller, required this.host, required this.lang});
  final TutorialController tutorial;
  final ProjectController controller;
  final TutorialHost host;
  final String lang;

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  /// Pause between a step being detected as done and moving on.
  static const autoAdvanceDelay = Duration(milliseconds: 1500);

  Rect? _target;
  Rect _lastTarget = Rect.zero;
  int _preparedIndex = -1;
  late TutorialContext _ctx;
  Timer? _advance;
  int _advanceFor = -1;

  @override
  void initState() {
    super.initState();
    _ctx = TutorialContext(widget.controller, widget.host, widget.tutorial.memo);
    widget.tutorial.addListener(_onChange);
    widget.controller.addListener(_onChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _advance?.cancel();
    widget.tutorial.removeListener(_onChange);
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    setState(() {});
  }

  void _refresh() {
    if (!mounted || !widget.tutorial.active) return;
    final t = widget.tutorial;
    if (_preparedIndex != t.index) {
      _preparedIndex = t.index;
      _advance?.cancel();
      _advanceFor = -1;
      t.current.prepare?.call(_ctx);
      // measure after prepare took effect
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _measure();
        _checkDone();
      });
      return;
    }
    _measure();
    _checkDone();
  }

  /// Moves on by itself a moment after an interactive step is detected as
  /// done (unless auto-advance is off or this is the last step).
  void _checkDone() {
    if (!mounted) return;
    final t = widget.tutorial;
    if (!t.active) return;
    final step = t.current;
    final done = step.interactive && (step.isDone?.call(_ctx) ?? false);
    if (!done || !t.autoAdvance || t.isLast) {
      if (!done && _advanceFor == t.index) {
        _advance?.cancel();
        _advanceFor = -1;
      }
      return;
    }
    if (_advanceFor == t.index) return;
    _advanceFor = t.index;
    _advance?.cancel();
    final at = t.index;
    _advance = Timer(autoAdvanceDelay, () {
      if (!mounted || !t.active || t.index != at || !t.autoAdvance) return;
      if (step.isDone?.call(_ctx) ?? false) t.next();
    });
  }

  void _measure() {
    if (!mounted || !widget.tutorial.active) return;
    final key = widget.tutorial.current.target;
    Rect? r;
    final ctx = key?.currentContext;
    if (ctx != null) {
      final box = ctx.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize && box.attached) {
        final origin = box.localToGlobal(Offset.zero);
        r = origin & box.size;
      }
    }
    if (r != _target) {
      setState(() {
        _target = r;
        if (r != null) _lastTarget = r;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tutorial;
    if (!t.active) return const SizedBox.shrink();
    final step = t.current;
    final lang = widget.lang;
    final done = step.isDone?.call(_ctx) ?? false;
    final size = MediaQuery.sizeOf(context);
    final target = step.target != null ? _target : null;
    // Re-measure after this frame so window resizes and layout changes are
    // tracked, and re-check completion for steps that watch shell state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measure();
      _checkDone();
    });
    return Stack(
      children: [
        // spotlight backdrop: purely visual, never blocks interaction
        Positioned.fill(
          child: IgnorePointer(
            child: TweenAnimationBuilder<Rect?>(
              tween: RectTween(begin: target ?? _lastTarget, end: target ?? _lastTarget),
              duration: const Duration(milliseconds: 250),
              builder: (context, rect, _) => CustomPaint(painter: _SpotlightPainter(target == null ? null : rect)),
            ),
          ),
        ),
        _card(context, step, done, size, target, lang),
      ],
    );
  }

  Widget _card(BuildContext context, TutorialStep step, bool done, Size size, Rect? target, String lang) {
    final t = widget.tutorial;
    final compact = size.width < 700;
    final cardW = compact ? size.width - 24 : 400.0;
    final cardH = math.min(compact ? 300.0 : 440.0, size.height - 24);
    final card = Material(
      elevation: 12,
      color: const Color(0xFF232A31),
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: cardW, maxHeight: cardH),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text('${step.chapter.isEmpty ? '' : '${step.chapter} · '}${tutorialText('step', lang).replaceAll('{i}', '${t.index + 1}').replaceAll('{n}', '${t.steps.length}')}', style: const TextStyle(fontSize: 10.5, color: Colors.white54, letterSpacing: 1), overflow: TextOverflow.ellipsis)),
                Tooltip(
                  message: tutorialText(t.autoAdvance ? 'autoOn' : 'autoOff', lang),
                  child: InkWell(key: const Key('tut_auto'), onTap: () => t.setAutoAdvance(!t.autoAdvance), borderRadius: BorderRadius.circular(12), child: Padding(padding: const EdgeInsets.all(4), child: Icon(t.autoAdvance ? Icons.fast_forward : Icons.pause_circle_outline, size: 16, color: t.autoAdvance ? const Color(0xFF66BB6A) : Colors.white54))),
                ),
                Tooltip(
                  message: tutorialText('skipAll', lang),
                  child: InkWell(key: const Key('tut_close'), onTap: t.skip, borderRadius: BorderRadius.circular(12), child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close, size: 16))),
                ),
              ]),
              const SizedBox(height: 2),
              Text(step.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Flexible(child: SingleChildScrollView(child: Text(step.body, style: const TextStyle(fontSize: 12.5, height: 1.45, color: Color(0xFFDDE3E8))))),
              if (step.action != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: (done ? const Color(0xFF66BB6A) : const Color(0xFF42A5F5)).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: (done ? const Color(0xFF66BB6A) : const Color(0xFF42A5F5)).withValues(alpha: 0.5))),
                  child: Row(children: [
                    Icon(done ? Icons.check_circle : Icons.touch_app_outlined, size: 16, color: done ? const Color(0xFF66BB6A) : const Color(0xFF42A5F5)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(done ? tutorialText(t.autoAdvance && !t.isLast ? 'doneNext' : 'done', lang) : '${tutorialText('action', lang)}: ${step.action}', style: const TextStyle(fontSize: 12))),
                  ]),
                ),
              ],
              const SizedBox(height: 8),
              LinearProgressIndicator(value: (t.index + 1) / t.steps.length, minHeight: 3, backgroundColor: Colors.white12),
              const SizedBox(height: 8),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                overflowAlignment: OverflowBarAlignment.end,
                spacing: 2,
                overflowSpacing: 4,
                children: [
                  TextButton(key: const Key('tut_skip_all'), onPressed: t.skip, style: TextButton.styleFrom(foregroundColor: Colors.white60, visualDensity: VisualDensity.compact), child: Text(tutorialText('skipAll', lang), style: const TextStyle(fontSize: 12))),
                  if (step.demo != null)
                    TextButton.icon(key: const Key('tut_demo'), onPressed: () => step.demo!(_ctx), style: TextButton.styleFrom(visualDensity: VisualDensity.compact), icon: const Icon(Icons.play_circle_outline, size: 16), label: Text(tutorialText('demo', lang), style: const TextStyle(fontSize: 12))),
                  TextButton(key: const Key('tut_prev'), onPressed: t.index > 0 ? t.prev : null, style: TextButton.styleFrom(visualDensity: VisualDensity.compact), child: Text(tutorialText('prev', lang), style: const TextStyle(fontSize: 12))),
                  FilledButton(key: const Key('tut_next'), onPressed: t.next, style: FilledButton.styleFrom(visualDensity: VisualDensity.compact), child: Text(t.isLast ? tutorialText('finish', lang) : tutorialText('next', lang), style: const TextStyle(fontSize: 12))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    // position: below target, else above, else beside; centred when no target
    const margin = 12.0;
    double left, top;
    if (compact) {
      // phones: pinned to the bottom, above the tool bar
      return Positioned(left: margin, right: margin, bottom: 100, child: Align(alignment: Alignment.bottomLeft, child: card));
    }
    if (target == null) {
      left = (size.width - cardW) / 2;
      top = (size.height - cardH) / 2;
    } else {
      left = (target.center.dx - cardW / 2).clamp(margin, math.max(margin, size.width - cardW - margin));
      if (target.bottom + margin + cardH < size.height) {
        top = target.bottom + margin;
      } else if (target.top - margin - cardH > 0) {
        top = target.top - margin - cardH;
      } else {
        top = (size.height - cardH) / 2;
        left = target.right + margin + cardW < size.width ? target.right + margin : math.max(margin, target.left - margin - cardW);
      }
    }
    top = top.clamp(margin, math.max(margin, size.height - cardH - margin));
    left = left.clamp(margin, math.max(margin, size.width - cardW - margin));
    return AnimatedPositioned(duration: const Duration(milliseconds: 250), curve: Curves.easeOut, left: left, top: top, width: cardW, child: Align(alignment: Alignment.topLeft, child: card));
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter(this.target);
  final Rect? target;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final backdrop = Paint()..color = Colors.black.withValues(alpha: 0.5);
    if (target == null) {
      canvas.drawPath(full, backdrop);
      return;
    }
    final hole = RRect.fromRectAndRadius(target!.inflate(6), const Radius.circular(8));
    final holePath = Path()..addRRect(hole);
    canvas.drawPath(Path.combine(PathOperation.difference, full, holePath), backdrop);
    canvas.drawRRect(hole, Paint()
      ..color = const Color(0xFF42A5F5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    canvas.drawRRect(hole.inflate(4), Paint()
      ..color = const Color(0xFF42A5F5).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) => old.target != target;
}
