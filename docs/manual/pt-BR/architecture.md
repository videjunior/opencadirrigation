# Arquitetura do código

```
bin/oci.dart                linha de comando: import, new, set, pack add, design, analyze, check, validate,
                            export, bom e schema de projetos .oci.json, um ou vários de uma vez, e
                            mcp, o servidor do Model Context Protocol (bin/src/oci_mcp_io.dart: a pasta
                            raiz, o isolate de cada chamada, stdio)
lib/
  core/                     Dart puro, sem Flutter (roda no worker, no isolate, nas ferramentas e na CLI)
    api.dart                o motor inteiro numa importação (docs/API.pt-BR.md)
    hydraulics/             fórmulas e solvers
      friction.dart           Hazen-Williams, Darcy-Weisbach (Swamee-Jain, Colebrook, Blasius, laminar,
                              transição), Scobey, Manning
      minor_losses.dart       K de acessórios, comprimento equivalente, curva h = K·Q^n + C
      emitter.dart            q = k·H^x, raio molhado, ajuste pela tabela do fabricante, janela de
                              pressão, CU de sobreposição
      lateral.dart            análise passo a passo de laterais, comprimento máximo, posições de alimentação
      network.dart            solver de rede (Global Gradient Algorithm) com emissores, bombas, PRV, PSV,
                              FCV, retenção
      sparse_solver.dart      LDLᵀ esparso com ordenação por grau mínimo
      pump.dart               curvas de bomba e do sistema, ponto de operação, potência, NPSH, CRF, energia
      uniformity.dart         CU, DU, EU, Us, variação de vazão
      water_hammer.dart       celeridade, Joukowsky, tempo crítico
      transient.dart          transientes pelo método das características (desligamento de bomba,
                              ventosas, reservatórios hidropneumáticos, cavidades de vapor)
      eps.dart                simulação de período estendido: reservatórios, horários, padrões,
                              controles, energia
    model/                  dados
      geometry.dart           Pt, Bounds, segmentos, polígonos, offsets, casco convexo, transformações afins
      entities.dart           entidades de desenho e hidráulicas (JSON, clone, transformar, grips, distância)
      catalog.dart            catálogo de componentes e base padrão, redução da classe dos tubos
      catalog_packs.dart      pacotes de fabricantes (em memória) e fusão
      currency.dart           moedas, padrão por idioma/região, câmbios de referência, conversão de preços
      project.dart            projeto: meta, parâmetros, catálogo, camadas, entidades, turnos
      terrain.dart, tin.dart  modelo do terreno: TIN de Delaunay restrito por linhas de quebra, IDW,
                              curvas de nível
      slope_map.dart          declividade e exposição numa grade
      spatial_index.dart      R-tree STR para culling, seleção e snap
      split.dart              divisão de entidades lineares
      blocks.dart, label_rules.dart, scenario.dart, proposal_settings.dart, site_climate.dart,
      pivot_machine.dart      blocos do usuário, rótulos condicionais, alternativas, configurações do
                              orçamento, clima do local, dados da máquina do pivô
      agronomy_plan.dart, agb_settings.dart, deliverables.dart, title_block.dart, pump_station.dart,
      reservoir.dart, valve_pilot.dart, dim_style.dart, layer_states.dart
                              configurações guardadas no projeto desde a 1.6.0: plano agronômico, energia
                              e água, documentos técnicos, carimbo, estações de bombeamento,
                              reservatórios, pilotos de válvula, estilo de cota, estados de camadas
      area_holes.dart, boundary.dart, lengthen.dart, edit_ops.dart, paste.dart, project_merge.dart,
      project_compare.dart    ilhas das áreas, contorno por clique interno, alongar, edições de geometria,
                              colagem, inserir projeto, comparação de duas cópias
      pipe_standards.dart, catalog_check.dart, regional.dart, read_report.dart, schema.dart
                              tubos por norma, plausibilidade do catálogo, padrões por região, leitura
                              tolerante com o seu relatório, JSON Schema do arquivo de projeto
    design/                 projetista
      network_builder.dart    entidades → grafo hidráulico (nós, trechos, zonas, agregação de emissores,
                              conexões)
      designer.dart           orquestração: zonas, linha principal, classes de pressão, telescopagem,
                              lavagem, golpe de aríete, máquinas, fiação, BOM
      lp.dart, lp_sizing.dart simplex denso de duas fases e formulação do dimensionamento
      block_generator.dart    blocos de laterais (retos e guiados) e grades de aspersores
      auto_layout.dart, zoning.dart, routing.dart, templates.dart, field_subdivision.dart,
      tree_rings.dart, pivot_fit.dart, vegetation.dart
                              projeto automático: aspersores, zonas, árvores de tubos e da linha
                              principal, modelos de gramado, blocos, anéis, ajuste de pivô, vegetação
                              em imagem aérea
      pivot.dart              hidráulica de pivô central e linear
      mechanised.dart, pivot_package.dart, corner_arm.dart, vri.dart, pivot_electrical.dart
                              pacote de aspersores e temporizador, braço de canto, taxa variável,
                              elétrica do pivô
      traveller.dart, surface_irrigation.dart, gated_pipe.dart
                              autopropelidos, sulcos, faixas e bacias, tubo janelado
      fittings.dart           seleção automática de conexões
      pump_selection.dart     escolha de bomba e motor
      agronomy.dart           ETc, balanço hídrico, programa do controlador
      climate.dart, crops.dart, soils.dart, effective_rain.dart, irrigation_requirement.dart,
      area_requirement.dart   ETo e culturas da FAO-56, solos do USDA, chuva efetiva, tabelas de necessidade
      solar_pumping.dart, wetted_bulb.dart, water_budget.dart
                              bombeamento fotovoltaico, bulbo molhado, orçamento hídrico do paisagismo
      management.dart         demandas das zonas, pivôs e estações, turnos automáticos
      valve_in_head.dart      estações de aspersores com válvula
      densogram.dart          água aplicada pelos aspersores como desenhados, uniformidade por área, vento
      electrical.dart         fiação das válvulas: rotas, estações, bitolas pela tensão no solenoide
      two_wire.dart, wire_routing.dart
                              dimensionamento de dois fios (decodificadores), rotas de fios pelas valas
      transient_analysis.dart, air_valves.dart
                              transientes da linha principal, ventosas (AWWA M51), simulação de 24 horas
      network_ops.dart, on_demand.dart, tariff.dart, energy_grouping.dart, criticality.dart,
      calibration.dart, fertigation.dart
                              operação: vazões de Clément, horários pela tarifa, agrupamento por
                              energia, N−1, calibração, fertirrigação
      proposal.dart           orçamento comercial, valas, retorno, cronograma de obra
      soil_water_balance.dart, irrigation_programme.dart, runoff_potential.dart, system_capacity.dart,
      catch_cans.dart, fertigation_stages.dart, agr_tables.dart
                              balanço hídrico diário, programa do controlador, escoamento, capacidade
                              contra o pico, uniformidade no campo, fertirrigação por estágio, as
                              tabelas de relatório deles
      pump_house.dart, solar_design.dart, water_quality.dart, multi_pivot.dart, field_machines.dart,
      agb_design.dart, agb_reports.dart
                              elétrica da casa de bombas, bombeamento solar, qualidade da água, vários
                              pivôs, faixas de carretel e sulcos, rodando como etapa do cálculo
      permit.dart, memorial.dart, om_plan.dart, budget.dart, life_cycle.dart, report_standards.dart,
      slope_report.dart       documentos técnicos, as normas dos relatórios, declividade por área
      life_scenarios.dart, reservoir.dart, analysis_control.dart, lateral_limit.dart, region_trace.dart
                              envelhecimento e entupimento, estudo do reservatório, progresso e
                              cancelamento das análises, comprimento máximo da lateral, contornos
                              traçados em imagem aérea
      crop_rows.dart          fileiras de plantio lidas na imagem aérea (direção, espaçamento, plantas,
                              cobertura)
      climate_risk.dart, climate_risk_stats.dart, irrigation_forecast.dart
                              o projeto contra quarenta anos reais, a irrigação dos próximos dias
      programme_playback.dart, programme_calendar.dart
                              o programa reproduzido na planta, o seu calendário
      scorecard.dart          o boletim de qualidade do projeto
      curve_digitiser.dart, curve_trace.dart, curve_fits.dart
                              curvas lidas na imagem de um gráfico para o catálogo
      design_check.dart       verificação de projeto
      advisor.dart            problemas explicados, configurações impossíveis, correções aplicáveis
      auto_fix.dart           correções, corrigir automaticamente, otimização
      results.dart, report_tables.dart  resultados serializáveis e tabelas dos relatórios
    io/                     leitura e escrita de formatos
      dxf.dart, dwg.dart, dgn.dart, kml.dart, shp.dart, geojson_reader.dart, gpx.dart, landxml.dart,
      las.dart, epanet_inp.dart, points_csv.dart, point_grid.dart, geoimage.dart, dem_tiff.dart
                              leitores (os de EPANET, GPX e LandXML também escrevem)
      cad_drawing.dart, cad_export.dart, dxf_r2000.dart, dwg_writer.dart
                              DXF e DWG R2000 com entidades nativas
      pdf_reader.dart, pdf_reader_fonts.dart, pdf_reader_images.dart, pdf_import.dart
                              plantas em PDF como base de fundo
      plot.dart, pdf.dart, pdf_sheet.dart, sheet_set.dart, sheet_canvas.dart, details.dart,
      plot_charts.dart, svg.dart
                              cena de plotagem, escritor PDF, conjuntos de folhas, detalhes
                              construtivos, gráficos, SVG
      fonts/                  leitor e subconjunto de TrueType, formatação OpenType (árabe, índicas),
                              bidi, dados Unicode, o registro de fontes do PDF
      shp_writer.dart, geo_export.dart, ifc.dart, xlsx.dart, catalog_io.dart, project_export.dart
                              shapefile, KML/GeoJSON, IFC 4, Excel, catálogos, despacho das exportações
      geo.dart, datum.dart    UTM, datums (SIRGAS 2000, SAD 69, Córrego Alegre), o datum do local, projeções
                              (Albers, cônica conforme de Lambert, policônica), reconhecimento de sistemas
      drawing_import.dart, import_async.dart, work_slicer.dart, safe_archive.dart, tiff_raster.dart,
      cad_xdata.dart, codepages.dart, typed_geo.dart, stakeout.dart, data_cache.dart, data_credits.dart
                              desenhos para dentro de um projeto (também para a linha de comando),
                              leitura em fatias, limites de zip, TIFF grandes, XDATA hidráulico, páginas
                              de código, coordenadas de campo digitadas, pontos para locação, downloads
                              guardados, créditos de terceiros
      doc_package.dart, doc_pdf.dart, doc_sections.dart, tech_doc.dart, tech_doc_sections.dart,
      title_block_sheet.dart, sheet_grid.dart, sheet_theme.dart, sheet_check.dart, icc_srgb.dart
                              pacotes de documentos, documentos técnicos, carimbo profissional,
                              quadrícula de coordenadas, folhas de declividade e de exposição, conferência
                              da folha, perfil sRGB do PDF/A
      dem_online.dart, climate_online.dart, share_link.dart
                              elevação e clima online, projetos num link
      forecast_online.dart, ics.dart, gif_animation.dart, scorecard_chart.dart
                              previsão do tempo do local, escritores de iCalendar e de GIF animado, o
                              radar do boletim nas pranchas
    ai/                     assistente de IA opcional, seis empresas atrás de uma só interface
      llm.dart                modelos com seus níveis e preços de tabela, tokens e custo, erros, o
                              cliente que cada empresa implementa
      llm_formats.dart        conversão de mensagens, ferramentas e resultados para o formato de cada empresa
      claude_api.dart         API Messages da Anthropic: streaming, raciocínio adaptativo, esforço,
                              cache, fallback de recusa, orçamento da tarefa, compactação, limpeza de
                              resultados antigos de ferramentas
      openai_api.dart         API Responses da OpenAI: streaming, ferramentas de função, esforço de
                              raciocínio, store: false, compactação; a base dos três clientes abaixo
      xai_api.dart, meta_api.dart, openrouter_api.dart
                              as Responses APIs da xAI, da Meta e da OpenRouter
      gemini_api.dart         a Interactions API do Google (Gemini)
      openrouter_catalog.dart a lista de modelos da OpenRouter, os modelos que o usuário acrescenta
      agent_loop.dart         o laço do agente: ferramentas, aprovações por modo, limite de etapas,
                              teto de gasto
      project_context.dart    os dados do projeto enviados com uma mensagem
    mcp/                    o servidor do Model Context Protocol do motor (docs/MCP.pt-BR.md):
                            protocolo, validador de JSON Schema, as ferramentas sobre a linha de comando
    units.dart              unidades (métrico/US), viscosidade da água, tabelas digitadas
    translate.dart          gancho de tradução para relatórios e plotagens rotularem a saída sem Flutter
    i18n/language_packs.dart registro dos pacotes de idioma (textos, tutorial, nomes do catálogo)
  app/                      Flutter
    state/                  ProjectController (projeto, seleção, câmera, undo, índice espacial, cálculo),
                            Workspace (abas e área de transferência), DesignRunner (worker/isolate/thread)
    canvas/                 CadCanvas, CadPainter, Camera, Snapper, mapa base
    tools/                  ferramentas de desenho, edição e hidráulica, pontos digitados, inserção de blocos
    keys/                   despachador de atalhos e listener nativo
    widgets/                menus, paleta, painéis, relatórios, gráficos, diálogos, layout compacto, e
                            ai/: o painel encaixado da IA e as suas vistas (conversa, dados enviados,
                            configurações)
    ai/                     o agente de uma aba: 75 ferramentas e 216 operações sobre o controller e o
                            motor (agent_tools*, agent_ops*, ops_*, op_parts/ por área), o mapa de
                            cobertura (ai_coverage.dart, coverage_parts/), o prompt de sistema, o
                            manual e os procedimentos,
                            visão (imagens, tiles, terreno), transportes (fetch, HttpClient),
                            aprovações, voltar e desfazer
    tutorial/               tutorial interativo
    io/                     arquivos, preferências, HTTP, armazenamento local, documento HTML, links externos,
                            GPS, fontes do PDF, exportação PNG de uma prancha
    actions.dart            ações de arquivo, área de transferência e exportação compartilhadas por menus, paleta e atalhos
    examples.dart           galeria de exemplos
    i18n.dart               tabela de textos pt/en/es (com as partes por área em i18n_parts/), lista de
                            idiomas e carregamento sob demanda dos pacotes
    i18n_assets.dart        lê assets/i18n/<código>.json para o idioma escolhido
    shortcuts.dart          aliases de comando (pt/en/es) e tabela de atalhos
    theme.dart              paletas escura e clara (CadPalette, 76 cores lidas por Cad.*), a regra de
                            cores CAD do canvas claro, troca de tema (CadThemeHost)
    version.dart            versão do app gerada (tool/gen_version.dart)
  worker/design_worker.dart entrada do Web Worker
assets/                     pacotes de idioma (i18n/) e os subconjuntos Noto dos PDFs (fonts/)
catalogs/                   pacotes de fabricantes (JSON) e índice
docs/                       estudo técnico, a API do motor (API.md, API.pt-BR.md) e o que a IA alcança
                            (AI_TOOLS.md, gerado)
examples/                   projetos de exemplo, uma pasta por idioma da interface (20)
tool/                       geradores: site (com o guia do usuário), catálogos, exemplos, marca, versão,
                            service worker; builds do worker e da web; fontes e fixtures de formatação
                            de texto (tool/fonts); o motor como pacote sem Flutter (engine_package.dart);
                            o checklist de lançamento (release.dart); a revisão das traduções
                            (i18n_review.dart); o hook de pre-commit e a lista de nomes proibidos
                            (hooks/); o teste de fumaça de ponta a ponta (e2e/)
test/                       testes do motor, do modelo, dos formatos e da interface; guards/ (arquivos
                            gerados, worker, pureza do motor, rede), seams/ (testes que atravessam
                            módulos), goldens/, web/
web/                        páginas, manifest, ícones, robots, sitemap, worker compilado, abertura sem rede
                            (sw.js, offline.js)
```

## Decisões de projeto

- **Motor em Dart puro.** `lib/core` não importa Flutter, por isso roda no Web Worker, no isolate,
  em `dart run` (ferramentas e linha de comando) e em testes rápidos. A interface só monta
  requisições e mostra resultados.
- **Um controller por projeto.** `ProjectController` guarda o projeto, a seleção, a câmera, a pilha
  de desfazer (snapshots das entidades), o índice espacial e o estado do cálculo. Toda edição passa
  por `mutate`, que tira o snapshot, marca o projeto como sujo, invalida resultados e o índice,
  notifica a interface e agenda o autosave.
- **Cálculo fora da thread.** O projeto vai serializado ao worker; o worker devolve resultados e as
  entidades redimensionadas; um contador de edições descarta resultados de um projeto que mudou
  enquanto calculava.
- **Índice espacial.** R-tree empacotada por STR reconstruída a cada edição; a pintura consulta só a
  janela visível e seleção, snap e janela de seleção consultam o índice (consulta em microssegundos
  com dezenas de milhares de entidades).
- **Desenho na tela.** A prancheta guarda o desenho entre um quadro e outro (`SceneCache`): ele só é
  gravado de novo quando muda algo que ele mostra (uma edição, a seleção, a vista, o mapa base, os
  resultados), de modo que mover o cursor repinta só o marcador de snap, a prévia da ferramenta e o
  item sob o cursor sobre uma imagem da cena. Uma cena demorada de desenhar acompanha o arrasto e o
  zoom como imagem deslocada e é redesenhada nítida quando a vista para. O painter agrupa as chamadas
  de desenho por estilo (algumas centenas de chamadas para dezenas de milhares de itens) e omite
  vértices a menos de um pixel; linhas de até um pixel físico são desenhadas como hairlines e as mais
  largas segmento a segmento (no navegador um traço largo é rasterizado na CPU), e uma vista lotada
  de linhas numa tela de alta densidade desenha as linhas de 1 px com um pixel físico. Só a barra de
  status escuta as coordenadas do cursor, então a janela não é reconstruída a cada movimento.
- **Formatos próprios em Dart puro.** Leitores e escritores de DWG, PDF (com as suas fontes e a
  formatação do texto), XLSX, SHP, GeoTIFF, LAS, IFC etc. não dependem de bibliotecas nativas, o que
  mantém o app 100 % web.
- **Textos centralizados.** Todas as strings da interface são chaves de `i18n.dart`, com os textos
  em português, inglês e espanhol compilados e os outros 17 idiomas nos pacotes de `assets/i18n`; o
  motor devolve códigos (`velocity_exceeded:e12`) que a interface traduz. Todo arquivo de teste
  falha quando a interface pede uma chave que a tabela não tem (`test/flutter_test_config.dart`),
  que de outro modo apareceria crua na tela.
- **A IA usa o programa, não uma cópia dele.** As ferramentas do assistente são invólucros finos
  sobre o controller e o motor, toda alteração passa por `mutate` (um grupo de desfazer por
  resposta), e um mapa de cobertura leva cada função que o usuário alcança a uma ferramenta, uma
  operação, um comando ou uma configuração. As seis empresas ficam atrás de uma só interface
  (`llm.dart`), com a conversão de formatos num só lugar (`llm_formats.dart`) e um só laço do
  agente; o código das requisições recebe a troca HTTP como parâmetro, então os testes o executam
  contra imitações programadas.
