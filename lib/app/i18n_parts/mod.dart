part of '../i18n.dart';

/// Strings added in 1.6.0 for model, catalogues, API and CLI: (pt, en, es), merged into the table after
/// the base strings (a key repeated in another part is a compile-time error).
const _mod = <String, (String, String, String)>{
  // ---- reading a project file item by item (MOD-02, MOD-08)
  'read.newer': (
    'O arquivo vem de uma versão mais nova do app (formato {v}): o que esta versão não conhece fica guardado e é gravado de novo, mas não aparece.',
    'The file comes from a newer version of the app (format {v}): what this version does not know is kept and saved again, but not shown.',
    'El archivo viene de una versión más nueva de la app (formato {v}): lo que esta versión no conoce se guarda y se vuelve a grabar, pero no aparece.',
  ),
  'read.skipped': (
    '{n} item(ns) não puderam ser lidos e ficaram de lado; continuam no arquivo ao salvar.',
    '{n} item(s) could not be read and were set aside; they stay in the file when you save.',
    '{n} elemento(s) no se pudieron leer y quedaron aparte; siguen en el archivo al guardar.',
  ),
  'read.renumbered': (
    '{n} item(ns) com identificador repetido ou ausente receberam um novo.',
    '{n} item(s) with a repeated or missing id got a new one.',
    '{n} elemento(s) con identificador repetido o ausente recibieron uno nuevo.',
  ),
  'read.vertices': ('{n} vértice(s) sem coordenadas foram descartados.', '{n} vertex(es) without coordinates were dropped.', '{n} vértice(s) sin coordenadas se descartaron.'),
  'read.values': (
    '{n} opção(ões) desconhecida(s) passaram ao valor padrão ({v}).',
    '{n} unknown option(s) took the default value ({v}).',
    '{n} opción(es) desconocida(s) pasaron al valor predeterminado ({v}).',
  ),
  'imp.err.project_format': ('O arquivo não é um projeto do OpenCADIrrigation.', 'The file is not an OpenCADIrrigation project.', 'El archivo no es un proyecto de OpenCADIrrigation.'),
  'imp.err.project_json': (
    'O arquivo do projeto está danificado ou incompleto (não é um JSON válido).',
    'The project file is damaged or cut short (it is not valid JSON).',
    'El archivo del proyecto está dañado o incompleto (no es un JSON válido).',
  ),
  // ---- design check: terrain coverage and area outlines (MOD-01, MOD-21)
  'check.outside_terrain': (
    'Itens fora da área dos dados de terreno: a cota é extrapolada',
    'Items outside the area of the terrain data: their elevation is extrapolated',
    'Elementos fuera del área de los datos de terreno: su cota se extrapola',
  ),
  'adv.outside_terrain.why': (
    'A cota de um ponto fora do contorno dos dados (curvas, pontos cotados, MDE) é estimada pelos pontos mais próximos, como se o terreno ficasse plano além deles. Poço, bomba e adutora costumam ficar fora da área levantada, e alguns metros de erro na cota mudam a altura que a bomba precisa vencer.',
    'The elevation of a point beyond the outline of the data (contours, spot heights, elevation model) is estimated from the nearest points, as if the ground stayed level past them. Wells, pumps and supply mains often lie outside the surveyed area, and a few metres of error in elevation change the head the pump must overcome.',
    'La cota de un punto fuera del contorno de los datos (curvas, puntos acotados, MDE) se estima con los puntos más cercanos, como si el terreno siguiera plano más allá de ellos. Pozo, bomba y aductora suelen quedar fuera del área relevada, y unos metros de error en la cota cambian la altura que la bomba debe vencer.',
  ),
  'adv.outside_terrain.how': (
    'Acrescente pontos cotados ou curvas que cubram esses itens (Terreno → Ponto cotado, ou baixe o modelo de elevação da área), ou fixe a cota do nó com uma junção.',
    'Add spot heights or contours that cover these items (Terrain → Spot height, or download the elevation model of the area), or fix the node elevation with a junction.',
    'Agregue puntos acotados o curvas que cubran esos elementos (Terreno → Punto acotado, o descargue el modelo de elevación del área), o fije la cota del nudo con una unión.',
  ),
  // ---- a nozzle the catalogue item no longer has (MOD-15)
  'check.nozzle_missing': ('Bocal que não existe mais no item do catálogo', 'Nozzle no longer in the catalogue item', 'Boquilla que ya no existe en el elemento del catálogo'),
  'warn.nozzle_missing': ('Bocal que não existe mais no item do catálogo', 'Nozzle no longer in the catalogue item', 'Boquilla que ya no existe en el elemento del catálogo'),
  // ---- catalogue import (MOD-06, MOD-09, MOD-10, MOD-18)
  'cat.pnAsk.title': ('Unidade da coluna PN', 'Unit of the PN column', 'Unidad de la columna PN'),
  'cat.pnAsk.body': (
    '{n} linha(s) têm PN de até 25 sem unidade. Pela ISO, PN 10 é 10 bar (102 m); nos tubos de irrigação brasileiros, PN 40, 60 e 80 são metros de coluna d\'água. Como ler esses valores?',
    '{n} row(s) have a PN of at most 25 without a unit. By ISO, PN 10 is 10 bar (102 m); Brazilian irrigation pipes give PN 40, 60 and 80 in metres of head. How should these values be read?',
    '{n} fila(s) tienen PN de hasta 25 sin unidad. Según ISO, PN 10 es 10 bar (102 m); los tubos de riego brasileños dan PN 40, 60 y 80 en metros de columna de agua. ¿Cómo leer esos valores?',
  ),
  'cat.pnAsk.bar': ('Em bar', 'In bar', 'En bar'),
  'cat.pnAsk.m': ('Em metros', 'In metres', 'En metros'),
  'cat.importInUse': (
    '{n} item(ns) substituído(s) estão em uso no desenho ({v}): confira diâmetros, curvas e preços.',
    '{n} replaced item(s) are used in the drawing ({v}): check their diameters, curves and prices.',
    '{n} elemento(s) sustituido(s) se usan en el dibujo ({v}): revise diámetros, curvas y precios.',
  ),
  'cat.importSkipped': (
    '{n} linha(s) sem diâmetro, curva ou seção ficaram de fora (linhas {v}).',
    '{n} row(s) without a diameter, curve or section were left out (rows {v}).',
    '{n} fila(s) sin diámetro, curva o sección quedaron fuera (filas {v}).',
  ),
  'cat.importUnits': (
    'Válvulas: kv = coeficiente de vazão (m³/h com 1 bar de perda), kcoef = K de K·v²/2g, k e n = a lei h = k·Q^n (Q em m³/s). Classe: ratingM em metros; pn em bar até 25 e em metros acima; uma unidade na célula (bar, psi, kPa, MPa, m) vale mais. Sem coluna id, a mesma linha importada de novo substitui o seu item, nunca outro.',
    'Valves: kv = flow coefficient (m³/h at 1 bar of loss), kcoef = K of K·v²/2g, k and n = the law h = k·Q^n (Q in m³/s). Class: ratingM in metres; pn in bar up to 25 and in metres above; a unit in the cell (bar, psi, kPa, MPa, m) wins. Without an id column, the same row imported again replaces its own item, never another one.',
    'Válvulas: kv = coeficiente de caudal (m³/h con 1 bar de pérdida), kcoef = K de K·v²/2g, k y n = la ley h = k·Q^n (Q en m³/s). Clase: ratingM en metros; pn en bar hasta 25 y en metros arriba; una unidad en la celda (bar, psi, kPa, MPa, m) prevalece. Sin columna id, la misma fila importada de nuevo sustituye su propio elemento, nunca otro.',
  ),
  // ---- reference exchange rates (MOD-30)
  'dlg.ratesStale': (
    'As taxas de referência são de {d}, há {n} dias: confira a taxa atual antes de converter, sobretudo em moedas de inflação alta.',
    'The reference rates are from {d}, {n} days ago: check the current rate before converting, above all for currencies of high inflation.',
    'Las tasas de referencia son del {d}, hace {n} días: verifique la tasa actual antes de convertir, sobre todo en monedas de inflación alta.',
  ),
  // ---- the motor of a pump at its duty point (MOD-16)
  'warn.pump_motor_overload': (
    'Bomba acima da potência do motor, mesmo com o fator de serviço',
    'Pump above its motor power, even with the service factor',
    'Bomba por encima de la potencia del motor, incluso con el factor de servicio',
  ),
  'adv.pump_motor_overload.why': (
    'No ponto de operação, a potência no eixo (ρ·g·Q·H/η) passa da potência nominal do motor vezes o seu fator de serviço: o motor aquece, a proteção desarma ou ele queima.',
    'At the duty point the shaft power (ρ·g·Q·H/η) exceeds the motor rating times its service factor: the motor overheats, its protection trips or it burns out.',
    'En el punto de operación, la potencia en el eje (ρ·g·Q·H/η) supera la potencia nominal del motor por su factor de servicio: el motor se calienta, la protección se dispara o se quema.',
  ),
  'adv.pump_motor_overload.how': (
    'Escolha uma bomba com motor maior, reduza a vazão do turno ou a altura manométrica, ou use um inversor de frequência com rotação menor.',
    'Choose a pump with a larger motor, reduce the flow of the system flow or the head, or use a variable-speed drive at a lower speed.',
    'Elija una bomba con motor mayor, reduzca el caudal del turno o la altura manométrica, o use un variador de frecuencia con menor velocidad.',
  ),
  'warn.pump_motor_sf': (
    'Bomba acima da potência nominal do motor, dentro do fator de serviço',
    'Pump above its motor rating, within the service factor',
    'Bomba por encima de la potencia nominal del motor, dentro del factor de servicio',
  ),
  'adv.pump_motor_sf.why': (
    'A potência no eixo no ponto de operação passa da potência nominal do motor, mas cabe no fator de serviço (1,15 nos motores comuns, mais nos submersos pequenos): o motor aguenta, com vida útil e rendimento menores.',
    'The shaft power at the duty point exceeds the motor rating but stays within the service factor (1.15 for common motors, more for small submersible ones): the motor copes, with a shorter life and a lower efficiency.',
    'La potencia en el eje en el punto de operación supera la potencia nominal del motor, pero cabe en el factor de servicio (1,15 en los motores comunes, más en los sumergibles pequeños): el motor aguanta, con menor vida útil y rendimiento.',
  ),
  'adv.pump_motor_sf.how': (
    'Confira a potência do motor na ficha do fabricante; para operação contínua, prefira um motor maior ou um ponto de operação com menos vazão.',
    'Check the motor power on the manufacturer\'s data sheet; for continuous duty prefer a larger motor or a duty point with less flow.',
    'Verifique la potencia del motor en la ficha del fabricante; para operación continua, prefiera un motor mayor o un punto de operación con menos caudal.',
  ),
  // ---- islands of irrigated areas (1.6.0 MOD, AUT-29)
  'area.subtract': ('Subtrair da área', 'Subtract from area', 'Restar del área'),
  'area.holes.clear': ('Remover as ilhas da área', 'Remove the islands of the area', 'Quitar las islas del área'),
  'hist.subtractArea': ('Subtrair da área ({n})', 'Subtract from area ({n})', 'Restar del área ({n})'),
  'hist.clearAreaHoles': ('Remover ilhas ({n})', 'Remove islands ({n})', 'Quitar islas ({n})'),
  'area.subtract.noShape': (
    'Selecione uma polilinha fechada, um círculo ou outra forma fechada para tirar da área (e a área, se a forma tocar mais de uma).',
    'Select a closed polyline, a circle or another closed shape to take out of the area (and the area, when the shape touches more than one).',
    'Seleccione una polilínea cerrada, un círculo u otra forma cerrada para quitar del área (y el área, si la forma toca más de una).',
  ),
  'area.subtract.noArea': ('Nenhuma área toca a forma selecionada.', 'No area meets the selected shape.', 'Ninguna área toca la forma seleccionada.'),
  'area.subtract.missed': (
    'A forma não corta a área: nada mudou (uma forma dentro de uma ilha já existente não muda a área).',
    'The shape does not cut the area: nothing changed (a shape inside an island that is already there leaves the area as it was).',
    'La forma no corta el área: nada cambió (una forma dentro de una isla ya existente no cambia el área).',
  ),
  'area.subtract.done': (
    '{n} área(s) alterada(s), {m} peça(s): a forma virou ilha (ou recorte) e saiu do desenho.',
    '{n} area(s) changed, {m} piece(s): the shape became an island (or a notch) and left the drawing.',
    '{n} área(s) modificada(s), {m} pieza(s): la forma pasó a ser isla (o recorte) y salió del dibujo.',
  ),
  'area.holes.none': ('Nenhuma área selecionada tem ilhas.', 'No selected area has islands.', 'Ningún área seleccionada tiene islas.'),
  'area.holes.cleared': ('Ilhas removidas de {n} área(s): o contorno inteiro é irrigado.', 'Islands removed from {n} area(s): the whole outline is irrigated.', 'Islas quitadas de {n} área(s): se riega todo el contorno.'),
  'area.holes.info': ('Ilhas (não irrigadas)', 'Islands (not irrigated)', 'Islas (no regadas)'),
  'area.holes.value': ('{n}, {a} fora da área de {g}', '{n}, {a} left out of {g}', '{n}, {a} fuera del área de {g}'),
  'ai.op.subtract_from_area': ('Subtrair {n} da área', 'Subtract {n} from the area', 'Restar {n} del área'),
  'ai.op.set_area_holes': ('Definir as ilhas da área {n}', 'Set the islands of area {n}', 'Definir las islas del área {n}'),
  // ---- File → Insert project (1.6.0 MOD)
  'file.insertProject': ('Inserir projeto…', 'Insert project…', 'Insertar proyecto…'),
  'hist.insertProject': ('Inserir projeto', 'Insert project', 'Insertar proyecto'),
  'insert.notProject': (
    'O arquivo não é um projeto do OpenCADIrrigation (.oci.json): para desenhos e mapas use Importar desenho.',
    'The file is not an OpenCADIrrigation project (.oci.json): for drawings and maps use Import drawing.',
    'El archivo no es un proyecto de OpenCADIrrigation (.oci.json): para dibujos y mapas use Importar dibujo.',
  ),
  'insert.done': (
    '{n} itens inseridos de {f} ({l} camada(s), {s} turno(s) e {b} bloco(s) novos)',
    '{n} items inserted from {f} ({l} new layer(s), {s} system flow(s) and {b} block(s))',
    '{n} elementos insertados de {f} ({l} capa(s), {s} turno(s) y {b} bloque(s) nuevos)',
  ),
  'insert.placedGeo': ('no mesmo lugar do terreno, pelas georreferências', 'in the same place on the ground, by the georeferences', 'en el mismo lugar del terreno, por las georreferencias'),
  'insert.tookGeo': ('o projeto passou a usar a georreferência do arquivo', 'the project now uses the georeference of the file', 'el proyecto pasó a usar la georreferencia del archivo'),
  'insert.noGeo': (
    'o projeto aberto não tem georreferência: os itens entraram como estavam desenhados',
    'the open project has no georeference: the items came in as drawn',
    'el proyecto abierto no tiene georreferencia: los elementos entraron como estaban dibujados',
  ),
  'insert.renamed': (
    '{n} item(ns) do catálogo com o mesmo id e outro conteúdo ganharam um id novo',
    '{n} catalogue item(s) with the same id and other data got a new id',
    '{n} elemento(s) del catálogo con el mismo id y otros datos recibieron un id nuevo',
  ),
  'insert.converted': ('preços convertidos de {c} para {t}', 'prices converted from {c} to {t}', 'precios convertidos de {c} a {t}'),
  'ai.op.insert_project': ('Inserir o projeto {n}', 'Insert the project {n}', 'Insertar el proyecto {n}'),
};
