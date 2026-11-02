part of '../site.dart';

const _fr = SiteText(
  title: 'OpenCADIrrigation : logiciel IA gratuit de conception d’irrigation',
  description: 'Logiciel gratuit et open source de conception d’irrigation en ligne : un assistant IA implante asperseurs et goutte-à-goutte, trace et dimensionne le réseau.',
  keywords: 'conception d’irrigation par IA, logiciel de conception d’irrigation avec IA, conception automatique d’irrigation, implantation automatique des asperseurs, assistant IA pour l’irrigation, conception d’irrigation, logiciel de conception d’irrigation, logiciel d’irrigation open source, logiciel d’irrigation, CAO irrigation, irrigation sous pression, goutte-à-goutte, micro-aspersion, aspersion, pivot central, dimensionnement hydraulique, dimensionnement des conduites, uniformité d’arrosage, DXF, DWG, arrosage des jardins, irrigation agricole, logiciel d’irrigation gratuit',
  h1: 'Logiciel gratuit et open source de conception d’irrigation avec un assistant IA',
  tagline: 'Décrivez la parcelle, le jardin ou le terrain de sport et laissez l’assistant IA implanter les arroseurs et le goutte-à-goutte, tracer les conduites et dimensionner le réseau ; ou dessinez-le vous-même avec les outils automatiques. Goutte-à-goutte, micro-aspersion, aspersion et pivot central, directement dans le navigateur, sans rien installer, avec vos projets conservés sur votre ordinateur.',
  intro: 'OpenCADIrrigation réunit le dessin CAO, le réseau hydraulique, le calcul et un assistant IA. Tracez la surface, ou laissez l’IA localiser le terrain sur l’image satellite ; posez les rampes, les vannes et la conduite principale à la main, avec les générateurs en un clic ou en le demandant à l’IA ; appuyez sur F5 et obtenez diamètres, pressions, uniformité, tours d’arrosage, nomenclature et rapports prêts à imprimer. L’assistant utilise les modèles Claude (Anthropic) ou GPT (OpenAI) avec votre propre clé API, directement depuis le navigateur. Disponible en 20 langues, selon la langue de votre ordinateur.',
  openApp: 'Ouvrir l’application',
  tutorial: 'Tutoriel interactif',
  seeExamples: 'Voir les exemples prêts',
  aiTitle: 'Un assistant IA qui dessine et conçoit avec vous',
  aiIntro: 'Ouvrez le panneau IA à côté du dessin et formulez votre demande avec vos propres mots. L’assistant lit le projet, regarde l’image satellite et le relief et travaille avec les mêmes outils que les menus, si bien que ce qu’il dessine est un véritable projet : éléments, conduites, vannes, zones et résultats, et non une simple image. Chaque modification attend votre validation, ou s’applique automatiquement si vous le préférez, et s’annule en un clic.',
  aiPoints: [
    (
      'Dessine et conçoit automatiquement',
      'Implante les asperseurs et les lignes goutte-à-goutte, divise les parcelles en blocs, ajuste les pivots, trace les conduites et les vannes, place la pompe et la source d’eau, lance le calcul, corrige les avertissements et optimise le coût, puis rédige le mémoire technique et le devis.',
    ),
    (
      'Voit le terrain',
      'Localise le terrain à partir d’une adresse, regarde l’image satellite d’un projet géoréférencé et sa topographie (relief ombré, courbes de niveau, pentes, profils), lit les dessins et les fichiers SIG que vous joignez et ajoute au catalogue des éléments tirés d’une fiche technique en PDF. Délimite tout seul les parcelles sur l’image, suit les points et les lignes que vous marquez sur la carte et épingle sur le dessin les photos de terrain avec GPS, à l’endroit où elles ont été prises.',
    ),
    (
      'Explique et vérifie',
      'Répond aux questions sur le projet et ses résultats, explique chaque message du dimensionnement et la façon de le corriger, lance les analyses et tient à jour, dans le projet, une liste des tâches et des notes sur vos décisions. Sur demande, examine tout le projet sans rien changer et regarde la planche avant que vous ne l’exportiez.',
    ),
    (
      'Votre clé, vous gardez la main',
      'Modèles Claude (Anthropic) ou GPT (OpenAI) de niveau haut de gamme, intermédiaire ou rapide, avec votre propre clé API, appelés directement depuis le navigateur, sans passer par aucun serveur. Quatre modes (Lecture seule, Planifier d’abord, Demander avant chaque modification, Appliquer les modifications automatiquement), une limite d’étapes et un plafond de dépenses par tâche, l’annulation de chaque réponse, et rien n’est envoyé avant que vous ne cliquiez sur Envoyer.',
    ),
  ],
  aiCta: 'Ouvrir l’assistant IA',
  featuresTitle: 'Ce que fait OpenCADIrrigation',
  features: [
    (
      'Assistant IA',
      'En option : interrogez l’IA sur le projet, ou laissez-la dessiner et concevoir à votre place. Elle implante les arroseurs et le goutte-à-goutte, divise les parcelles, trace les conduites, lance le dimensionnement et les outils automatiques en regardant l’image satellite et le relief, avec les modèles Claude (Anthropic) ou GPT (OpenAI) et votre propre clé API, directement depuis votre navigateur, sans serveur intermédiaire. Rien n’est envoyé avant que vous ne cliquiez sur Envoyer, et chaque modification attend votre validation (ou s’applique automatiquement, si vous le choisissez) et peut être annulée.',
    ),
    (
      'Conception et dimensionnement automatiques',
      'Blocs de rampes et maillages d’asperseurs en un clic, implantation des arroseurs à précipitation équilibrée, répartition en zones selon le débit, tracé des conduites et des vannes, division des parcelles en blocs, ajustement des pivots à la parcelle et détection de la végétation sur les images aériennes ; conduites dimensionnées par programmation linéaire dans la plage de pression des distributeurs et selon la classe de pression des tubes, en arbitrant entre coût des conduites et énergie.',
    ),
    (
      'Dessin CAO complet',
      'Lignes, polylignes, arcs, splines, hachures, cotes, textes, calques et blocs, avec saisie de coordonnées, accrochages, repérage polaire, poignées, nuages de révision et raccourcis de commande des logiciels de CAO (L, PL, C, D, ZE…).',
    ),
    (
      'Réseau hydraulique',
      'Sources d’eau, pompes à vitesse fixe ou variable, conduite principale, vannes de zone, réducteurs de pression, vannes de maintien de pression et limiteurs de débit, turbines à vanne intégrée, rampes avec distributeurs, gaines goutte-à-goutte, filtres et compteurs, ainsi que les pivots centraux et rampes frontales avec leur équipement d’aspersion, les enrouleurs et l’irrigation gravitaire.',
    ),
    (
      'Moteur hydraulique validé',
      'Hazen-Williams, Darcy-Weisbach, Scobey et Manning, pertes singulières des raccords utilisés, distributeurs q = k·Hˣ, résolution du réseau par le Global Gradient Algorithm (comme EPANET), courbes de pompe avec NPSH, régimes transitoires par la méthode des caractéristiques avec ventouses et simulation sur 24 heures avec les tarifs de l’énergie.',
    ),
    (
      'Terrain, climat et agronomie',
      'Courbes de niveau, points cotés, modèle numérique de terrain triangulé avec lignes de rupture, altitude en ligne, nuages de points LAS, cartes des pentes et profils en long ; climat du site téléchargé ou saisi, cultures FAO-56 par stade de croissance, sols, pluie efficace et lessivage pour les besoins en eau, ainsi que les budgets hydriques paysagers.',
    ),
    (
      'Rapports, plans et matériel',
      'Zones, conduites, distributeurs, uniformité (CU, DU, EU), programme du programmateur et câblage des vannes ; nomenclature avec raccords et devis avec main-d’œuvre, taxes et délai de récupération ; jeux de planches PDF avec détails de construction et graphiques, dans n’importe laquelle des 20 langues, et tous les tableaux en Excel, CSV et TXT.',
    ),
    (
      'Échange de fichiers',
      'Importe DXF, DWG, plans PDF, KML/KMZ, shapefile, GeoJSON, GPX, LandXML, LAS, DGN, EPANET .inp, CSV/XYZ, GeoTIFF et images ; exporte DXF 2000 avec entités natives (ou R12), DWG, PDF, PNG, SVG, KML/KMZ, GeoJSON, shapefile, GPX, LandXML, EPANET .inp et IFC.',
    ),
    (
      'Catalogues de fabricants',
      'Catalogues de fabricants en JSON (Netafim, Rivulis, Jain, Toro, Rain Bird, Nelson, Hunter, NaanDanJain, Senninger, Irritec, Bermad, Schneider, Amanco Wavin, Multilit) prêts à l’emploi, ainsi que vos propres paquets chargés depuis un fichier ou une URL.',
    ),
    (
      'Hors ligne et sur le terrain',
      'Après la première visite, l’application démarre sans réseau, sur ordinateur, tablette ou téléphone, en thème clair ou sombre. Sur le terrain, le GPS de l’appareil enregistre les contours et les lignes parcourus à pied, marque des points et indique la distance et l’azimut jusqu’à l’élément sélectionné pour l’implantation.',
    ),
  ],
  howTitle: 'Comment ça marche',
  how: [
    (
      'Dessinez ou importez la surface',
      'Chargez un DXF, un DWG, un KML ou une image satellite, dessinez directement la parcelle, le jardin ou le terrain de sport, ou donnez l’adresse à l’assistant IA, qui retrouve l’emplacement sur la carte. Ajoutez des courbes de niveau ou téléchargez l’altitude à partir d’une coordonnée.',
    ),
    (
      'Construisez le réseau, à la main ou avec l’IA',
      'Générez des blocs de rampes ou des maillages d’asperseurs en un clic, ou demandez à l’assistant IA d’implanter les arroseurs, de diviser la parcelle, de tracer les conduites et de placer les vannes, la pompe et la source d’eau ; puis reliez le tout par la conduite principale.',
    ),
    (
      'Dimensionnez et documentez',
      'Appuyez sur F5, ou demandez-le à l’IA : l’application dimensionne les zones et la conduite principale, vérifie pressions et vitesses et produit les rapports, la nomenclature et le plan en PDF.',
    ),
  ],
  examplesTitle: 'Exemples prêts à ouvrir',
  examplesIntro: 'Chaque projet s’ouvre complet et se dimensionne avec F5. Servez-vous-en pour découvrir l’application ou comme point de départ.',
  examples: [
    SiteExample('orchard', 'Verger', 'Micro-aspersion sur agrumes et goutte-à-goutte sur vigne, puits avec pompe et filtre, terrain en pente.'),
    SiteExample(
      'garden',
      'Jardin résidentiel',
      'Tuyères escamotables sur la pelouse avant, turbines à l’arrière et goutte-à-goutte dans les massifs, alimentés par le réseau public avec compteur et disconnecteur.',
    ),
    SiteExample('sportsField', 'Terrain de football', 'Terrain réglementaire de 105 × 68 m avec asperseurs à impact sur cinq lignes, réservoir, pompe et postes de nuit.'),
    SiteExample('rowCrop', 'Culture en rangs au goutte-à-goutte', 'Quatre parcelles de tomates en gaine goutte-à-goutte, porte-rampes avec vannes, filtre à tamis, pompe et terrain en pente.'),
    SiteExample('pivot', 'Pivot central', 'Pivot de 300 m sur maïs alimenté par une conduite principale, un puits et une pompe ; rapport des tours, travées et buses.'),
    SiteExample('greenhouse', 'Serre maraîchère', 'Quatre tunnels de poivrons en ligne goutte-à-goutte autorégulante, une zone par tunnel, réservoir, petite pompe et filtre à disques.'),
    SiteExample('nursery', 'Pépinière', 'Trois planches de 12 × 48 m sous micro-asperseurs suspendus en maille 4 × 4 m, une zone par planche, réservoir surélevé, petite pompe et filtre à disques.'),
    SiteExample(
      'coffee',
      'Caféière en courbes de niveau',
      'Trois parcelles de café à flanc de coteau avec des rampes courbes qui suivent les courbes de niveau (bloc guidé), ligne goutte-à-goutte autorégulante, puits et pompe au pied de la pente.',
    ),
    SiteExample('bananas', 'Bananeraie', 'Deux parcelles de bananiers sous micro-asperseurs autorégulants en 5 × 5 m, puits avec pompe immergée, filtre à disques et terrain en pente.'),
    SiteExample(
      'sugarcane',
      'Canne à sucre en goutte-à-goutte enterré',
      'Deux parcelles de canne en ligne goutte-à-goutte autorégulante de 20 mm enterrée à 0,3 m, rampes de 180 m, porte-rampes enterrés, réservoir, pompe, filtre à tamis et ventouse.',
    ),
    SiteExample(
      'gravity',
      'Goutte-à-goutte gravitaire',
      'Un réservoir 40 m au-dessus de deux parcelles maraîchères au goutte-à-goutte, sans pompe : vanne d’arrêt, réducteur de pression et filtre à disques sur la conduite principale ; courbes de niveau du coteau.',
    ),
    SiteExample('pasture', 'Pâturage par aspersion', 'Trois enclos de 72 × 72 m avec des lignes d’asperseurs à impact en 12 × 18 m, porte-rampes avec vannes, réservoir, pompe et clapet anti-retour.'),
    SiteExample(
      'golf',
      'Trou de golf',
      'Départ avec tuyères, fairway avec turbines en maille triangulaire (deux zones) et green avec turbines en périphérie, plan d’eau avec pompe et postes de nuit.',
    ),
    SiteExample(
      'sectorPivot',
      'Pivot sectoriel avec canon',
      'Pivot de 250 m sur soja balayant 270°, laissant libre le quadrant du corps de ferme, avec un canon d’extrémité de 12 m³/h ; plan d’eau, pompe de 20 ch et vanne d’arrêt.',
    ),
    SiteExample(
      'linear',
      'Rampe frontale',
      'Rampe frontale de 392 m sur blé parcourant 800 m le long d’un canal, prise d’eau avec pompe de 30 ch et clapet anti-retour ; rapport des tours et des buses.',
    ),
  ],
  faqTitle: 'Questions fréquentes',
  faq: [
    (
      'Qu’est-ce qu’OpenCADIrrigation ?',
      'OpenCADIrrigation est une application web gratuite et open source pour concevoir des systèmes d’irrigation sous pression : une CAO dotée d’un moteur hydraulique qui trace le réseau, dimensionne les conduites, vérifie les pressions et l’uniformité et produit la nomenclature et les rapports, du jardin résidentiel au pivot central, ainsi que d’un assistant IA facultatif qui dessine et conçoit le projet avec vous à partir d’une description du terrain.',
    ),
    (
      'Une IA peut-elle concevoir le projet à ma place ?',
      'Oui, si vous le souhaitez. L’assistant IA facultatif travaille sur le projet ouvert avec les mêmes outils que les menus : décrivez le terrain, ou laissez-le regarder l’image satellite et le relief d’un projet géoréférencé, et il implante les asperseurs et le goutte-à-goutte, divise les parcelles en blocs, trace les conduites et les vannes, place la pompe et la source d’eau, lance le calcul et les outils automatiques, corrige les avertissements, optimise le coût et rédige le mémoire technique. Il demande votre accord avant chaque modification, ou applique les modifications automatiquement si vous le choisissez, et chaque réponse s’annule en un clic. Un modèle peut se tromper : vérifiez son travail comme vous le feriez pour celui d’un collègue.',
    ),
    (
      'Quels modèles d’IA utilise-t-il ?',
      'Les modèles Claude d’Anthropic (Claude Opus 5.5 par défaut, Claude Fable 5.1, Claude Sonnet 5.5 et Claude Haiku 5.5) et les modèles GPT d’OpenAI (GPT-6 Astra, GPT-6.1 Sol et GPT-6 Luna) : un niveau haut de gamme, un intermédiaire et un rapide de chaque entreprise, chacun avec cinq profondeurs de réflexion. Vous choisissez le modèle dans les paramètres de l’assistant et collez votre propre clé API ; le panneau affiche les jetons et le coût estimé de chaque réponse, et une limite d’étapes et un plafond de dépenses arrêtent une tâche qui s’éternise.',
    ),
    (
      'Qu’envoie l’assistant IA, et à qui ?',
      'Rien tant que vous n’avez pas cliqué sur Envoyer. Votre message, les fichiers que vous joignez et les données du projet que vous cochez partent alors directement de votre navigateur vers l’API du fournisseur choisi, Anthropic ou OpenAI, sans passer par aucun serveur d’OpenCADIrrigation, avec les résultats des outils que l’assistant utilise pour répondre, images du dessin comprises. Le fournisseur facture l’utilisation sur votre compte. La clé reste en mémoire le temps de la session, sauf si vous choisissez de la mémoriser sur l’appareil, et n’entre jamais dans les fichiers de projet, les liens de partage ni les exports. La dictée vocale, si vous l’utilisez, passe par la reconnaissance vocale du navigateur lui-même, qui envoie le son à l’éditeur du navigateur (Google pour Chrome, Microsoft pour Edge, Apple pour Safari). Les conversations enregistrées restent dans votre navigateur, jamais dans les fichiers de projet ni dans les liens.',
    ),
    (
      'OpenCADIrrigation est-il gratuit ?',
      'Oui. Il est gratuit pour un usage professionnel, universitaire et personnel, sans inscription. Il est aussi open source, sous licence MIT, et son code source est publié sur GitHub. L’assistant IA, facultatif, utilise votre propre compte Anthropic ou OpenAI, et le fournisseur en facture l’utilisation sur ce compte.',
    ),
    (
      'À qui s’adresse-t-il ?',
      'Aux concepteurs d’irrigation agricole et paysagère, aux agronomes et ingénieurs, aux distributeurs de matériel, aux enseignants et aux étudiants. Le tutoriel interactif, 15 exemples prêts à l’emploi et l’assistant IA permettent de commencer sans lire de manuel.',
    ),
    (
      'Faut-il installer quelque chose ?',
      'Non. Il fonctionne dans Chrome, Edge, Firefox et Safari, sur ordinateur, tablette et téléphone, et peut s’installer comme application (PWA) qui s’ouvre dans sa propre fenêtre.',
    ),
    (
      'Fonctionne-t-il hors ligne ?',
      'Oui, après la première visite : l’application conserve une copie d’elle-même dans le navigateur (environ 24 Mo, une fois par version), si bien que le démarrage suivant, de l’application installée comme du site, se fait sans réseau, au bureau comme sur le terrain. Les fonds de carte, l’altitude et le climat en ligne, les catalogues chargés par URL et l’assistant IA nécessitent toujours une connexion ; une nouvelle version se télécharge en arrière-plan et est utilisée dès le démarrage suivant.',
    ),
    (
      'Mes projets sont-ils stockés dans le cloud ?',
      faqCloudAnswerEn,
    ),
    (
      'Comment l’hydraulique est-elle calculée ?',
      'Pertes de charge par Hazen-Williams, Darcy-Weisbach, Scobey ou Manning, distributeurs selon q = k·Hˣ et réseau complet résolu par le Global Gradient Algorithm, la méthode d’EPANET. Les conduites sont dimensionnées par programmation linéaire dans la plage de pression des distributeurs et selon la classe de pression des tubes, et le calcul vérifie aussi l’uniformité (CU, DU, EU), le rinçage et les régimes transitoires par la méthode des caractéristiques (fermeture des vannes, disjonction des pompes, ventouses), avec une simulation sur 24 heures des pressions et du coût de l’énergie.',
    ),
    (
      'Fonctionne-t-il avec d’autres logiciels de CAO ?',
      'Oui. Il importe DXF et DWG jusqu’à la version 2018, DGN V7 et des plans PDF, et exporte en DXF 2000 avec entités natives (polylignes avec arcs, hachures, splines, cotes, blocs avec attributs), en DXF R12 pour les logiciels plus anciens et en DWG 2000. Pour les SIG, la topographie et le BIM, il lit et écrit aussi KML/KMZ, shapefile, GeoJSON, GPX, LandXML et EPANET .inp, lit les nuages de points LAS et exporte en IFC 4.',
    ),
    (
      'Dans quelles langues est-il disponible ?',
      'En 20 langues, les mêmes que ce site (la liste figure en bas de la page). L’application s’ouvre dans la langue de votre ordinateur et vous pouvez en changer à tout moment dans Affichage → Langue.',
    ),
  ],
  loading: 'Chargement de la CAO d’irrigation…',
  slow: 'Le chargement prend du temps. Vérifiez la connexion ou rechargez la page ; le contenu ci-dessus est déjà lisible.',
  noScript: 'OpenCADIrrigation a besoin de JavaScript pour fonctionner. Activez JavaScript dans votre navigateur et rechargez la page.',
  otherLanguages: 'Langues',
  footer: 'Les catalogues de fabricants et les projets d’exemple peuvent être envoyés au format JSON pour être intégrés à OpenCADIrrigation.',
  sourceCode: 'Code source (licence MIT)',
  subCategory: 'CAO pour l’irrigation',
  screenshotLabel: 'Projet d’irrigation dimensionné avec résultats par zone',
  notFoundTitle: 'Page introuvable',
  notFoundText: 'Cette adresse n’existe pas sur ce site. OpenCADIrrigation est une application unique ; ouvrez-la depuis la page d’accueil.',
  notFoundHome: 'Aller à OpenCADIrrigation',
);
