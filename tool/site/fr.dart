part of '../site.dart';

const _fr = SiteText(
  title: 'OpenCADIrrigation : logiciel IA gratuit de conception d’irrigation',
  description: 'Logiciel gratuit et open source de conception d’irrigation en ligne : un assistant IA implante asperseurs et goutte-à-goutte, trace et dimensionne le réseau.',
  keywords: 'conception d’irrigation par IA, logiciel de conception d’irrigation avec IA, conception automatique d’irrigation, implantation automatique des asperseurs, assistant IA pour l’irrigation, conception d’irrigation, logiciel de conception d’irrigation, logiciel d’irrigation open source, logiciel d’irrigation, CAO irrigation, irrigation sous pression, goutte-à-goutte, micro-aspersion, aspersion, pivot central, dimensionnement hydraulique, dimensionnement des conduites, uniformité d’arrosage, DXF, DWG, arrosage des jardins, irrigation agricole, logiciel d’irrigation gratuit',
  h1: 'Logiciel gratuit et open source de conception d’irrigation avec un assistant IA',
  tagline: 'Décrivez la parcelle, le jardin ou le terrain de sport et laissez l’assistant IA implanter les arroseurs et le goutte-à-goutte, tracer les conduites et dimensionner le réseau ; ou dessinez-le vous-même avec les outils automatiques. Goutte-à-goutte, micro-aspersion, aspersion et pivot central, directement dans le navigateur, sans rien installer, avec vos projets conservés sur votre ordinateur.',
  intro: 'OpenCADIrrigation réunit le dessin CAO, le réseau hydraulique, le calcul et un assistant IA. Tracez la surface, ou laissez l’IA localiser le terrain sur l’image satellite ; posez les rampes, les vannes et la conduite principale à la main, avec les générateurs en un clic ou en le demandant à l’IA ; appuyez sur F5 et obtenez diamètres, pressions, uniformité, tours d’arrosage, nomenclature et rapports prêts à imprimer. L’assistant fonctionne avec Claude (Anthropic), GPT (OpenAI), Gemini (Google), Grok (xAI), Muse (Meta) ou, via OpenRouter, des centaines d’autres modèles, avec votre propre clé API, directement depuis le navigateur. Disponible en 20 langues, selon la langue de votre ordinateur.',
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
      'Claude (Anthropic), GPT (OpenAI), Gemini (Google), Grok (xAI), Muse (Meta) ou des centaines de modèles via OpenRouter, dont certains gratuits, avec votre propre clé API, appelés directement depuis le navigateur, sans passer par aucun serveur. Quatre modes (Lecture seule, Planifier d’abord, Demander avant chaque modification, Appliquer les modifications automatiquement), une limite d’étapes et un plafond de dépenses par tâche, l’annulation de chaque réponse, le second avis d’un autre modèle, et rien n’est envoyé avant que vous ne cliquiez sur Envoyer.',
    ),
  ],
  aiCta: 'Ouvrir l’assistant IA',
  featuresTitle: 'Ce que fait OpenCADIrrigation',
  features: [
    (
      'Assistant IA',
      'En option : interrogez l’IA sur le projet, ou laissez-la dessiner et concevoir à votre place. Elle implante les arroseurs et le goutte-à-goutte, divise les parcelles, trace les conduites, lance le dimensionnement et les outils automatiques en regardant l’image satellite et le relief, avec les modèles d’Anthropic, d’OpenAI, de Google, de xAI, de Meta ou d’OpenRouter et votre propre clé API, directement depuis votre navigateur, sans serveur intermédiaire. Rien n’est envoyé avant que vous ne cliquiez sur Envoyer, et chaque modification attend votre validation (ou s’applique automatiquement, si vous le choisissez) et peut être annulée.',
    ),
    (
      'Conception et dimensionnement automatiques',
      'Blocs de rampes et maillages d’asperseurs en un clic, implantation des arroseurs à précipitation équilibrée, répartition en zones selon le débit, tracé des conduites et des vannes, division des parcelles en blocs, ajustement des pivots à la parcelle, et détection de la végétation et des rangs de culture (direction, espacement et nombre) sur les images aériennes ; conduites dimensionnées par programmation linéaire dans la plage de pression des distributeurs et selon la classe de pression des tubes, en arbitrant entre coût des conduites et énergie.',
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
      'Risque climatique et prévision d’irrigation',
      'Confronte le projet au climat journalier du site depuis 1984 : le besoin en eau d’une année sèche, la fréquence à laquelle le système conçu serait insuffisant, les pires années et les périodes sèches. Et transforme les prévisions météo du site en ce qu’il faut irriguer dans les prochains jours : irriguer ou non, dose, durée d’arrosage et le pourcentage d’ajustement (water budget) pour le programmateur.',
    ),
    (
      'Le programme animé sur le plan',
      'Anime le programme d’irrigation sur le dessin : les zones qui fonctionnent, les conduites selon la vitesse et le débit, les pompes et le niveau du réservoir à chaque instant. Exporte le cycle en GIF animé et le programme en fichier calendrier pour le téléphone.',
    ),
    (
      'Bulletin de qualité du projet',
      'Note le projet conçu de 0 à 100 et de A à E dans sept catégories (uniformité, hydraulique, énergie, eau et sol, économie, robustesse et complétude), avec la cible de chaque indicateur et sa provenance, et indique ce qu’il faut améliorer d’abord.',
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
      'Moteur ouvert pour les scripts et les agents IA',
      'Le moteur de calcul est en Dart pur avec une ligne de commande, et il parle le Model Context Protocol (MCP) : d’autres applications d’IA peuvent créer, dimensionner et vérifier des projets avec lui sur votre propre ordinateur, cantonnées à un dossier que vous choisissez.',
    ),
    (
      'Catalogues de fabricants',
      'Catalogues de fabricants en JSON (Netafim, Rivulis, Jain, Toro, Rain Bird, Nelson, Hunter, NaanDanJain, Senninger, Irritec, Bermad, Schneider, Amanco Wavin, Multilit) prêts à l’emploi, ainsi que vos propres paquets chargés depuis un fichier ou une URL, et les courbes de pompes, d’émetteurs et d’asperseurs numérisées à partir de l’image d’une fiche technique.',
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
      'Les modèles de six entreprises, avec votre propre clé API : Claude d’Anthropic (Claude Opus 5.5 par défaut, Claude Fable 5.2, Claude Sonnet 5.5 et Claude Haiku 5.5), GPT d’OpenAI (GPT-6 Astra, GPT-6.1 Sol, GPT-6.1 Terra et GPT-6 Luna), Gemini de Google (Gemini 4 Argon, Gemini 3.8 Flash et Gemini 3.5 Flash-Lite), Grok de xAI (Grok 4.7 et Grok 4.3), Muse de Meta (Muse Wonder, Muse Spark et Muse Ember) et, avec une seule clé OpenRouter, n’importe lequel des centaines de modèles de sa liste. Vous choisissez l’entreprise et le modèle dans les paramètres de l’assistant et collez votre clé ; le panneau affiche les jetons et le coût estimé de chaque réponse, une limite d’étapes et un plafond de dépenses arrêtent une tâche qui s’éternise, et un autre modèle peut donner un second avis sur une réponse.',
    ),
    (
      'Puis-je utiliser l’assistant IA sans payer ?',
      'Le programme est gratuit ; l’assistant a besoin d’une clé d’une entreprise d’IA, qui facture ce que vous utilisez. Deux possibilités ne coûtent rien dans leurs limites : le niveau gratuit des modèles Gemini Flash de Google (là où Google le propose) et les modèles gratuits d’OpenRouter. Ces limites sont fixées par les entreprises, et sur un niveau gratuit elles peuvent utiliser ce que vous envoyez pour améliorer leurs produits : lisez donc leurs conditions avant d’envoyer un projet confidentiel.',
    ),
    (
      'Qu’envoie l’assistant IA, et à qui ?',
      'Rien tant que vous n’avez pas cliqué sur Envoyer. Votre message, les fichiers que vous joignez et les données du projet que vous cochez partent alors directement de votre navigateur vers l’API de l’entreprise choisie (Anthropic, OpenAI, Google, xAI, Meta ou OpenRouter, qui transmet la requête à l’entreprise qui exécute le modèle), sans passer par aucun serveur d’OpenCADIrrigation, avec les résultats des outils que l’assistant utilise pour répondre, images du dessin comprises. Le fournisseur facture l’utilisation sur votre compte. La clé reste en mémoire le temps de la session, sauf si vous choisissez de la mémoriser sur l’appareil, et n’entre jamais dans les fichiers de projet, les liens de partage ni les exports. La dictée vocale, si vous l’utilisez, passe par la reconnaissance vocale du navigateur lui-même, qui envoie le son à l’éditeur du navigateur (Google pour Chrome, Microsoft pour Edge, Apple pour Safari). Les conversations enregistrées restent dans votre navigateur, jamais dans les fichiers de projet ni dans les liens. Un second avis, quand vous en demandez un, envoie la question, la réponse et les données du projet à l’entreprise du modèle qui le donne.',
    ),
    (
      'OpenCADIrrigation est-il gratuit ?',
      'Oui. Il est gratuit pour un usage professionnel, universitaire et personnel, sans inscription. Il est aussi open source, sous licence MIT, et son code source est publié sur GitHub. L’assistant IA, facultatif, utilise votre propre compte auprès d’une entreprise d’IA (Anthropic, OpenAI, Google, xAI, Meta ou OpenRouter), qui en facture l’utilisation sur ce compte ; certains de leurs modèles peuvent être utilisés gratuitement, dans certaines limites.',
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
      'Oui, après la première visite : l’application conserve une copie d’elle-même dans le navigateur (environ 20 Mo, une fois par version), si bien que le démarrage suivant, de l’application installée comme du site, se fait sans réseau, au bureau comme sur le terrain. Les fonds de carte, l’altitude et le climat en ligne, les prévisions météo, les catalogues chargés par URL et l’assistant IA nécessitent toujours une connexion ; une nouvelle version se télécharge en arrière-plan et est utilisée dès le démarrage suivant.',
    ),
    (
      'Mes projets sont-ils stockés dans le cloud ?',
      'Non. Les projets sont enregistrés dans votre navigateur et dans des fichiers .oci.json que vous conservez où vous voulez ; un lien de partage transporte le projet dans l’adresse elle-même, si bien que rien n’est téléversé, et OpenCADIrrigation n’a aucun serveur qui pourrait en garder une copie. Les polices de toutes les écritures et de tous les symboles viennent de ce site lui-même. Le navigateur contacte toutefois d’autres services : les fonds de carte, l’altitude et le climat en ligne, les prévisions météo, la recherche d’adresse, les catalogues chargés par URL et, si vous l’utilisez, l’assistant IA (uniquement l’entreprise que vous avez choisie : Anthropic, OpenAI, Google, xAI, Meta ou OpenRouter) s’adressent à leurs services quand vous les utilisez ; et le site et l’application comptent les visites avec Google Analytics, qui utilise des cookies (vous pouvez le désactiver avec Paramètres des cookies, en bas des pages). La politique de confidentialité liste chaque service et ce qu’il reçoit.',
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

const _legalFr = LegalText(
  privacyTitle: 'Politique de confidentialité',
  privacyLead: 'Ce qu’OpenCADIrrigation conserve, ce qu’il envoie et à qui, en termes simples.',
  privacy: [
    LegalSection('Qui est responsable', [
      'Le site opencadirrigation.com et l’application OpenCADIrrigation sont publiés par le mainteneur d’OpenCADIrrigation, qui est le responsable du traitement des données personnelles décrites sur cette page.',
      'Contact : ouvrez un ticket (issue) dans le dépôt du projet ([github.com/videjunior/opencadirrigation/issues]($contactUrl)). Pour une question qui ne doit pas être publique, demandez-y un canal privé, sans écrire de données personnelles dans le ticket.',
    ]),
    LegalSection('En bref', [
      '- Il n’y a ni compte ni serveur d’OpenCADIrrigation derrière l’application : les projets, les enregistrements automatiques, les versions, les conversations IA, les clés et les préférences restent dans votre navigateur et dans les fichiers que vous enregistrez.',
      '- Les statistiques de visite (Google Analytics) tournent sur toutes les pages du site et dans l’application, avec leurs cookies ; vous pouvez les désactiver avec Paramètres des cookies, en bas des pages.',
      '- Les services que l’application utilise pour les polices, les cartes, le terrain, le climat, la recherche d’adresse et l’assistant IA reçoivent vos requêtes directement depuis votre navigateur quand vous les utilisez.',
    ]),
    LegalSection('Ce qui reste sur votre appareil', [
      'L’enregistrement automatique, les projets récents, les 10 dernières versions de chaque projet, les 24 conversations IA les plus récentes (avec leurs images et leurs petites pièces jointes), les clés API que vous choisissez de mémoriser, la clé Google Maps, la langue de l’interface, le thème et les autres préférences sont conservés dans le stockage de votre navigateur (localStorage et IndexedDB), et une copie de l’application dans son cache, pour qu’elle démarre hors ligne. Personne d’autre ne les reçoit, et nous n’en avons aucune copie.',
      'Ils restent jusqu’à ce que vous les supprimiez : l’option « Garder les conversations dans ce navigateur », dans les réglages de l’assistant, désactive les conversations et les supprime, et effacer les données du site dans le navigateur supprime tout. Un navigateur peut aussi les supprimer de lui-même quand l’espace vient à manquer ou, dans Safari, après quelques semaines sans visite ; conservez donc vos projets dans des fichiers .oci.json.',
      'Un lien de partage transporte le projet dans l’adresse, après le #, que les navigateurs n’envoient à aucun serveur.',
    ]),
    LegalSection('Statistiques de visite et cookies', [
      'Toutes les pages du site et l’application chargent Google Analytics 4, qui dépose les cookies _ga et _ga_<id> (ils durent jusqu’à deux ans) et enregistre les pages vues et chaque démarrage de l’application, l’heure de la visite, la page qui vous a amené, le type d’appareil et de navigateur, la taille de l’écran, la langue et une localisation approximative que Google déduit de l’adresse IP (Google Analytics 4 ne conserve pas l’adresse IP). Il ne reçoit jamais la partie de l’adresse située après le #, où un lien de partage transporte le projet, et ses fonctions publicitaires sont désactivées.',
      'Finalité : savoir combien de personnes visitent le site et utilisent l’application, et quelles pages et langues elles utilisent, afin de les améliorer. Base légale : l’intérêt légitime à mesurer l’utilisation d’un service gratuit. Les données sont conservées pendant la durée de conservation définie dans Google Analytics, au plus 14 mois.',
      'Vous pouvez vous y opposer à tout moment avec Paramètres des cookies, en bas des pages : si vous refusez, les cookies de statistiques du site sont supprimés et Google Analytics n’est plus chargé dans ce navigateur. Bloquer les cookies ou les scripts dans votre navigateur l’empêche aussi de fonctionner.',
      'Les statistiques tournent aussi pendant que l’application est ouverte, dans la page qui contient vos projets et, si vous choisissez de les mémoriser, vos clés API de l’IA : comme tout script du site, le script de Google Analytics pourrait lire le stockage du site dans votre navigateur, et il n’envoie à Google que les données ci-dessus. Google Analytics est un service de Google soumis à ses propres conditions et à sa propre politique de confidentialité, et les données peuvent être traitées aux États-Unis et dans d’autres pays.',
    ]),
    LegalSection('Hébergement', [
      'Le site est servi par Firebase Hosting (Google), qui reçoit l’adresse IP et les données techniques de chaque requête (adresse demandée, navigateur, heure) pour fournir les pages et protéger le service. Base légale : l’intérêt légitime à faire fonctionner le site en toute sécurité. Ces données ne servent à rien d’autre.',
      'L’application et toutes ses polices, y compris celles de toutes les écritures et de tous les symboles (écritures chinoise, japonaise, arabe et indiennes, flèches, emoji), viennent aussi de ce site : aucun service de polices n’est contacté.',
    ]),
    LegalSection('Services que votre navigateur contacte quand vous les utilisez', [
      '- Fonds de carte : OpenStreetMap, OpenTopoMap, CARTO, Esri, Google (avec votre propre clé) ou l’adresse que vous définissez reçoivent l’adresse IP et la zone de la carte affichée à l’écran.',
      '- Altitude et climat en ligne : Terrain Tiles (AWS Open Data), Open-Meteo, OpenTopoData et NASA POWER reçoivent les coordonnées de la zone, rien d’autre du projet.',
      '- Prévisions météo (Projet → Agronomie → Prévision d’irrigation) : MET Norway ou Open-Meteo, selon votre choix, reçoit les coordonnées du site arrondies à quatre décimales, rien d’autre du projet.',
      '- Recherche d’adresse : Nominatim (OpenStreetMap) reçoit l’adresse que vous tapez.',
      '- Catalogues chargés par URL : le serveur de cette adresse.',
      '- Assistant IA (facultatif) : l’entreprise que vous choisissez, avec votre propre clé : Anthropic, OpenAI, Google, xAI, Meta ou OpenRouter (qui transmet la requête à l’entreprise qui exécute le modèle choisi et apprend seulement que la requête vient d’OpenCADIrrigation, rien sur vous). Rien n’est envoyé avant que vous n’appuyiez sur Envoyer ; partent alors votre message, les fichiers que vous joignez, les données du projet que vous cochez, les messages précédents et, pendant qu’il travaille, les résultats des outils qu’il utilise, images du dessin comprises. Un second avis, quand vous en demandez un, envoie la question, la réponse et les données du projet à l’entreprise du modèle qui le donne. Votre accord avec chaque entreprise régit ce qu’elle en fait, et elle facture votre compte ; sur un niveau gratuit (modèles Gemini Flash de Google, modèles gratuits d’OpenRouter), l’entreprise peut utiliser ce que vous envoyez pour améliorer ses produits.',
      '- La liste des modèles d’OpenRouter : téléchargée depuis OpenRouter quand vous ouvrez Plus de modèles… dans les réglages de l’assistant, sans votre clé.',
      '- Dictée vocale : la reconnaissance vocale du navigateur envoie le son à l’éditeur du navigateur (Google dans Chrome, Microsoft dans Edge, Apple dans Safari).',
      'Chacun de ces services a sa propre politique de confidentialité et peut traiter des données hors de votre pays.',
    ]),
    LegalSection('Vos droits', [
      'En vertu de la LGPD au Brésil, du RGPD dans l’Union européenne et au Royaume-Uni, et de lois similaires, vous pouvez demander la confirmation, l’accès, la rectification et l’effacement de vos données personnelles ainsi que des informations sur leur partage, vous opposer à un traitement et retirer votre consentement.',
      'Nous ne détenons aucune donnée qui vous identifie : les statistiques sont pseudonymes, et tout le reste se trouve dans votre navigateur, sous votre contrôle. Pour toute demande, utilisez le contact ci-dessus. Vous pouvez aussi adresser une réclamation à votre autorité de protection des données (au Brésil, l’ANPD).',
    ]),
    LegalSection('Modifications', ['Quand cette politique change, la date en bas de la page change aussi.']),
  ],
  termsTitle: 'Conditions d’utilisation',
  termsLead: 'OpenCADIrrigation est un logiciel libre et gratuit. L’utiliser implique d’accepter ces conditions.',
  terms: [
    LegalSection('Le logiciel', [
      'OpenCADIrrigation est un logiciel gratuit et open source sous licence MIT ([opensource.org/license/mit]($licenseUrl)). Vous pouvez l’utiliser à toutes fins, travaux professionnels et commerciaux compris, et le copier, le modifier et le distribuer selon cette licence. Il n’y a ni frais ni compte.',
    ]),
    LegalSection('Une aide à la conception : le professionnel signe le projet', [
      'L’application aide à dessiner, calculer et documenter des systèmes d’irrigation. Ses résultats (diamètres des tuyaux, pressions, débits, uniformité, programmes d’arrosage, nomenclatures, devis et rapports, ainsi que le travail de l’assistant IA) dépendent des données que vous saisissez, des données du catalogue et du site et de modèles qui simplifient la réalité, et ils peuvent contenir des erreurs.',
      'Vérifiez-les avant de les utiliser. Un projet réalisé avec l’application doit être revu, approuvé et signé par un professionnel qualifié, qui en assume la responsabilité technique comme l’exige la loi du lieu (au Brésil, avec l’ART correspondante, l’attestation de responsabilité technique).',
    ]),
    LegalSection('Absence de garantie', [
      'Le logiciel est fourni « en l’état », sans garantie d’aucune sorte, expresse ou implicite, y compris les garanties de qualité marchande, d’adéquation à un usage particulier et d’absence de contrefaçon. En aucun cas les auteurs ou les titulaires des droits d’auteur ne pourront être tenus responsables de toute réclamation, de tout dommage ou de toute autre responsabilité découlant du logiciel ou de son utilisation (les termes de la licence MIT).',
    ]),
    LegalSection('Données et services de tiers', [
      'Les cartes, l’imagerie, l’altitude, le climat, les prévisions météo, la recherche d’adresse et les catalogues de fabricants proviennent de tiers, selon leurs propres conditions et licences (voir Aide → À propos dans l’application). Les données des catalogues sont tirées de tableaux publiés et peuvent être périmées : confirmez les modèles, les courbes et les prix avec les fiches techniques en vigueur avant d’acheter.',
      'Dans un travail professionnel, utilisez chaque source dans le respect de ses conditions : Aide → Conditions des données, dans l’application, indique ce que permet l’usage gratuit de chacune. Certains services gratuits sont réservés à un usage non commercial (les services gratuits d’Open-Meteo et les fonds de carte CARTO), c’est pourquoi l’application télécharge par défaut le climat depuis NASA POWER, les prévisions météo depuis MET Norway et l’altitude depuis Terrain Tiles ; le serveur de tuiles de l’OpenStreetMap Foundation interdit l’usage intensif et le téléchargement de zones pour un usage hors ligne, si bien que la carte conservée pour le terrain n’utilise que les tuiles déjà affichées. Les planches, les PDF et le rapport portent le crédit de chaque source : conservez-le lorsque vous livrez ou publiez le travail.',
      'L’assistant IA facultatif fonctionne avec votre propre compte auprès de l’entreprise d’IA que vous choisissez (Anthropic, OpenAI, Google, xAI, Meta ou OpenRouter), selon les conditions de cette entreprise, qui en facture l’utilisation. Un modèle peut se tromper : validez en connaissance de cause les modifications qu’il propose et vérifiez son travail.',
    ]),
    LegalSection('Votre contenu', ['Vos projets, dessins, images et fichiers vous appartiennent : vous en êtes responsable, ainsi que du droit d’utiliser ce que vous importez.']),
    LegalSection('Contact', ['Questions et problèmes : [github.com/videjunior/opencadirrigation/issues]($contactUrl). La façon dont vos données sont traitées : la politique de confidentialité.']),
  ],
  privacyLink: 'Confidentialité',
  termsLink: 'Conditions d’utilisation',
  cookieSettings: 'Paramètres des cookies',
  consentText: 'Le site et l’application comptent les visites avec Google Analytics, qui utilise des cookies. Si vous refusez, vos visites ne sont plus comptées dans ce navigateur.',
  consentAccept: 'Accepter',
  consentDecline: 'Refuser',
  updated: 'Dernière mise à jour',
  home: 'Aller à OpenCADIrrigation',
);
