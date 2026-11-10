part of '../i18n.dart';

/// Strings added in 1.7.0 for the crop rows read from the aerial image
/// (Design → Automatic design → Crop rows from the image): (pt, en, es),
/// merged into the table after the base strings (a key repeated in another
/// part is a compile-time error).
const _row = <String, (String, String, String)>{
  // ---- menu and dialog
  'row.menu': ('Fileiras da imagem…', 'Crop rows from the image…', 'Hileras de la imagen…'),
  'row.title': ('Fileiras de plantio na imagem', 'Crop rows from the image', 'Hileras de cultivo en la imagen'),
  'row.hint': (
    'Lê na imagem de satélite (ou numa foto aérea do desenho) a direção e o espaçamento das fileiras de um pomar, cafezal, vinhedo ou citros, para alinhar as laterais com as fileiras que já existem no campo. Processamento de imagem neste aparelho, sem assistente de IA.',
    'Reads the direction and spacing of the rows of an orchard, coffee, vineyard or citrus grove on the satellite image (or on an aerial photo in the drawing), to lay the laterals along the rows already in the field. Image processing on this device, no AI assistant needed.',
    'Lee en la imagen satelital (o en una foto aérea del dibujo) la dirección y el espaciamiento de las hileras de un huerto, cafetal, viñedo o cítricos, para alinear los laterales con las hileras que ya existen en el campo. Procesamiento de imagen en este dispositivo, sin asistente de IA.',
  ),
  'row.noArea': (
    'Selecione a área irrigada (ou um contorno fechado) do campo plantado e abra esta ferramenta de novo.',
    'Select the irrigated area (or a closed outline) of the planted field and open this tool again.',
    'Seleccione el área regada (o un contorno cerrado) del campo plantado y abra esta herramienta de nuevo.',
  ),
  'row.field': ('Campo: {n} · {a}', 'Field: {n} · {a}', 'Campo: {n} · {a}'),
  'row.source': ('Imagem', 'Image', 'Imagen'),
  'row.source.map': ('Imagem de satélite (mapa base)', 'Satellite imagery (base map)', 'Imagen satelital (mapa base)'),
  'row.source.image': ('Foto aérea “{n}”', 'Aerial photo “{n}”', 'Foto aérea «{n}»'),
  'row.minSpacing': ('Espaçamento mínimo ({u})', 'Closest spacing ({u})', 'Espaciamiento mínimo ({u})'),
  'row.maxSpacing': ('Espaçamento máximo ({u})', 'Widest spacing ({u})', 'Espaciamiento máximo ({u})'),
  'row.detect': ('Detectar', 'Detect', 'Detectar'),
  'row.stop': ('Parar', 'Stop', 'Detener'),
  'row.reading': ('Baixando a imagem…', 'Downloading the imagery…', 'Descargando la imagen…'),
  'row.analysing': ('Analisando a imagem… {p} %', 'Analysing the image… {p} %', 'Analizando la imagen… {p} %'),
  'row.stopped': ('Detecção interrompida.', 'Detection stopped.', 'Detección interrumpida.'),
  'row.noImagery': (
    'A imagem de satélite não carregou aqui (sem internet ou sem imagem nesta região).',
    'The satellite imagery did not load here (offline, or no imagery in this region).',
    'La imagen satelital no cargó aquí (sin internet o sin imagen en esta región).',
  ),
  // ---- results
  'row.direction': ('Direção das fileiras', 'Row direction', 'Dirección de las hileras'),
  'row.directionValue': ('{d}° (anti-horário a partir do leste)', '{d}° (counter-clockwise from east)', '{d}° (antihorario desde el este)'),
  'row.spacing': ('Espaçamento entre fileiras', 'Row spacing', 'Espaciamiento entre hileras'),
  'row.rows': ('Fileiras no campo', 'Rows across the field', 'Hileras en el campo'),
  'row.confidence': ('Confiança', 'Confidence', 'Confianza'),
  'row.conf.rows': ('{p} % — fileiras claras', '{p} % — clear rows', '{p} % — hileras claras'),
  'row.conf.uncertain': ('{p} % — incerta: confira as linhas na imagem', '{p} % — uncertain: check the lines on the image', '{p} % — incierta: revise las líneas en la imagen'),
  'row.conf.none': ('{p} % — nenhuma fileira', '{p} % — no rows', '{p} % — ninguna hilera'),
  'row.plant': ('Espaçamento entre plantas', 'Plant spacing in the row', 'Espaciamiento entre plantas'),
  'row.notVisible': ('não visível na imagem', 'not visible in the image', 'no visible en la imagen'),
  'row.cover': ('Cobertura do solo pela copa', 'Canopy ground cover', 'Cobertura del suelo por la copa'),
  'row.detail': ('Detalhe no centro, em tamanho real', 'Detail at the centre, actual pixels', 'Detalle en el centro, en tamaño real'),
  'row.otherBand': ('Fileiras na outra faixa (meio espaçamento ao lado)', 'Rows on the other band (half a spacing over)', 'Hileras en la otra franja (medio espaciamiento al lado)'),
  'row.otherBandHint': (
    'Se as linhas caíram nas entrelinhas (sombra, cobertura verde) e não nas plantas, ligue para movê-las meio espaçamento.',
    'If the lines fell on the alleys (shade, a cover crop) rather than on the plants, turn this on to move them half a spacing.',
    'Si las líneas cayeron en las entrehileras (sombra, cobertura verde) y no en las plantas, actívelo para moverlas medio espaciamiento.',
  ),
  // ---- apply
  'row.applyTitle': ('Aplicar ao projeto', 'Apply to the project', 'Aplicar al proyecto'),
  'row.apply.rows': (
    'Direção e espaçamento das fileiras na área (usados ao dividir o talhão em blocos, nos anéis de gotejamento e no bloco de laterais)',
    'Row direction and spacing on the area (used when subdividing the field into blocks, by the orchard drip rings and the lateral block)',
    'Dirección y espaciamiento de las hileras en el área (usados al dividir la parcela en bloques, en los anillos de goteo y en el bloque de laterales)',
  ),
  'row.apply.cover': ('Cobertura do solo da área ({p} %)', 'Ground cover of the area ({p} %)', 'Cobertura del suelo del área ({p} %)'),
  'row.apply.guides': ('Linhas-guia das fileiras na camada {l}', 'Guide lines of the rows on the {l} layer', 'Líneas guía de las hileras en la capa {l}'),
  'row.areaOnly': (
    'Este contorno não é uma área irrigada: só as linhas-guia podem ser desenhadas.',
    'This outline is not an irrigated area: only the guide lines can be drawn.',
    'Este contorno no es un área regada: solo se pueden dibujar las líneas guía.',
  ),
  'row.apply': ('Aplicar', 'Apply', 'Aplicar'),
  'row.applied': ('Fileiras aplicadas: {d}°, {s}; {n} linha(s)-guia.', 'Rows applied: {d}°, {s}; {n} guide line(s).', 'Hileras aplicadas: {d}°, {s}; {n} línea(s) guía.'),
  'row.hist': ('Fileiras da imagem', 'Crop rows from the image', 'Hileras de la imagen'),
  'row.fromArea': (
    'Direção e espaçamento das fileiras lidos da imagem para esta área.',
    'Row direction and spacing read from the image for this area.',
    'Dirección y espaciamiento de las hileras leídos de la imagen para esta área.',
  ),
  // ---- remarks of the reading (row.msg.<code>, numbers already with units)
  'row.msg.noField': ('O contorno não tem área.', 'The outline encloses no area.', 'El contorno no encierra área.'),
  'row.msg.noPixels': ('A imagem não tem dados dentro do contorno.', 'The image has no data inside the outline.', 'La imagen no tiene datos dentro del contorno.'),
  'row.msg.tooSmall': (
    'O campo é pequeno demais para fileiras espaçadas de {s} ou mais: aumente o contorno ou diminua o espaçamento máximo.',
    'The field is too small for rows spaced {s} or more: enlarge the outline or lower the widest spacing.',
    'El campo es demasiado pequeño para hileras espaciadas {s} o más: amplíe el contorno o reduzca el espaciamiento máximo.',
  ),
  'row.msg.flat': ('A imagem não tem contraste dentro do campo.', 'The image shows no contrast inside the field.', 'La imagen no tiene contraste dentro del campo.'),
  'row.msg.noRows': (
    'Nenhuma fileira visível: solo nu, pastagem, copa fechada ou fileiras fora da faixa de espaçamentos.',
    'No rows visible: bare soil, pasture, a closed canopy or rows outside the spacing range.',
    'Ninguna hilera visible: suelo desnudo, pastura, copa cerrada o hileras fuera del rango de espaciamientos.',
  ),
  'row.msg.coarse': (
    'A imagem tem {r} por pixel: fileiras a menos de {s} não aparecem nela.',
    'The imagery has {r} per pixel: rows closer than {s} cannot be seen in it.',
    'La imagen tiene {r} por píxel: hileras a menos de {s} no se ven en ella.',
  ),
  'row.msg.curved': (
    'As fileiras curvam ou mudam de direção no campo: a direção é uma média; divida o campo em partes retas.',
    'The rows bend or change direction across the field: the direction is an average; split the field into straight parts.',
    'Las hileras se curvan o cambian de dirección en el campo: la dirección es un promedio; divida el campo en partes rectas.',
  ),
  'row.msg.fewRows': ('Só {n} fileira(s) no campo: leitura pouco segura.', 'Only {n} row(s) across the field: a weak reading.', 'Solo {n} hilera(s) en el campo: lectura poco segura.'),
  'row.msg.fewPixels': (
    'Só {p} pixels da imagem por espaçamento: confira na imagem.',
    'Only {p} pixels of the imagery per spacing: check it on the image.',
    'Solo {p} píxeles de la imagen por espaciamiento: revíselo en la imagen.',
  ),
  'row.msg.window': (
    'Campo grande: foi lida uma janela de {a} × {b} no meio dele e as fileiras foram estendidas ao campo todo.',
    'A large field: a window of {a} × {b} in its middle was read and the rows extended over the whole field.',
    'Campo grande: se leyó una ventana de {a} × {b} en su centro y las hileras se extendieron a todo el campo.',
  ),
  // ---- AI operations
  'ai.op.detect_crop_rows': ('Ler as fileiras na imagem', 'Read the crop rows on the image', 'Leer las hileras en la imagen'),
  'ai.op.apply_crop_rows': ('Aplicar as fileiras lidas na imagem', 'Apply the crop rows read on the image', 'Aplicar las hileras leídas en la imagen'),
};
