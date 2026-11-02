part of '../site.dart';

const _de = SiteText(
  title: 'OpenCADIrrigation: kostenlose KI-Software für Bewässerungsplanung',
  description: 'Kostenlose Open-Source-Software für Bewässerungsplanung: Ein KI-Assistent setzt Regner und Tropfer, verlegt Rohre und dimensioniert die Anlage im Browser.',
  keywords: 'Bewässerungsplanung mit KI, KI-Software für Bewässerungsplanung, automatische Bewässerungsplanung, automatische Regneranordnung, KI-Assistent für Bewässerung, Bewässerungsplanung, Software für Bewässerungsplanung, Open-Source-Bewässerungssoftware, Bewässerungssoftware, CAD Bewässerung, Tropfbewässerung, Mikroberegnung, Beregnung, Center-Pivot, hydraulische Berechnung, Rohrdimensionierung, Gleichmäßigkeit der Bewässerung, DXF, DWG, Gartenbewässerung, landwirtschaftliche Bewässerung, kostenlose Bewässerungssoftware',
  h1: 'Kostenlose Open-Source-Software für die Bewässerungsplanung mit KI-Assistent',
  tagline: 'Beschreiben Sie Feld, Garten oder Sportplatz und lassen Sie den KI-Assistenten Regner und Tropfleitungen anordnen, die Rohre verlegen und die Anlage dimensionieren – oder zeichnen Sie sie selbst mit den automatischen Werkzeugen. Tropf-, Mikroregner-, Regner- und Center-Pivot-Anlagen direkt im Browser, ohne Installation, mit den Projekten auf Ihrem eigenen Computer.',
  intro: 'OpenCADIrrigation vereint CAD-Zeichnung, hydraulisches Netz, Berechnung und einen KI-Assistenten. Umreißen Sie die Fläche oder lassen Sie die KI den Standort im Satellitenbild finden; erstellen Sie Laterale, Ventile und Hauptleitung von Hand, mit den Ein-Klick-Generatoren oder indem Sie die KI darum bitten; drücken Sie F5 und erhalten Sie Rohrdurchmesser, Drücke, Gleichmäßigkeit, Betriebsschichten, Stückliste und druckfertige Berichte. Der Assistent arbeitet mit Claude-Modellen (Anthropic) oder GPT-Modellen (OpenAI) und Ihrem eigenen API-Schlüssel, direkt aus dem Browser. In 20 Sprachen verfügbar, passend zur Sprache Ihres Computers.',
  openApp: 'App öffnen',
  tutorial: 'Interaktives Tutorial',
  seeExamples: 'Fertige Beispiele ansehen',
  aiTitle: 'Ein KI-Assistent, der mit Ihnen zeichnet und plant',
  aiIntro: 'Öffnen Sie das KI-Panel neben der Zeichnung und sagen Sie in eigenen Worten, was Sie brauchen. Der Assistent liest das Projekt, sieht sich Satellitenbild und Gelände an und arbeitet mit denselben Werkzeugen wie die Menüs. Was er zeichnet, ist deshalb eine echte Planung mit Elementen, Rohren, Ventilen, Zonen und Ergebnissen, kein bloßes Bild. Jede Änderung wartet auf Ihre Zustimmung oder wird auf Wunsch automatisch angewendet und lässt sich mit einem Klick rückgängig machen.',
  aiPoints: [
    (
      'Zeichnet und plant automatisch',
      'Ordnet Regner und Tropfleitungen an, teilt Felder in Blöcke auf, passt Pivots ein, verlegt Rohre und setzt Ventile, platziert Pumpe und Wasserquelle, führt die Auslegung aus, behebt die Warnungen, optimiert die Kosten und schreibt anschließend den technischen Erläuterungsbericht und das Angebot.',
    ),
    (
      'Sieht sich den Standort an',
      'Findet den Standort anhand einer Adresse, betrachtet das Satellitenbild eines georeferenzierten Projekts und das Gelände (Schummerung, Höhenlinien, Hangneigung, Profile), liest die Zeichnungen und GIS-Dateien, die Sie anhängen, und nimmt Elemente aus einem PDF-Datenblatt in den Katalog auf. Umrandet die Felder auf dem Bild selbstständig, folgt den Punkten und Linien, die Sie auf der Karte markieren, und heftet Feldfotos mit GPS dort an die Zeichnung, wo sie aufgenommen wurden.',
    ),
    (
      'Erklärt und prüft',
      'Beantwortet Fragen zum Projekt und zu seinen Ergebnissen, erklärt jede Projektmeldung und wie sie sich beheben lässt, führt die Analysen aus und pflegt im Projekt eine Aufgabenliste und Notizen zu Ihren Entscheidungen. Prüft auf Wunsch das ganze Projekt, ohne etwas zu ändern, und sieht sich das Blatt an, bevor Sie es exportieren.',
    ),
    (
      'Ihr Schlüssel, Ihre Kontrolle',
      'Claude-Modelle von Anthropic oder GPT-Modelle von OpenAI in den Klassen Spitzenmodell, Mittelklasse und schnell, mit Ihrem eigenen API-Schlüssel direkt aus dem Browser aufgerufen, ohne zwischengeschalteten Server. Vier Modi („Nur lesen“, „Erst planen“, „Vor jeder Änderung fragen“, „Änderungen automatisch anwenden“), Schritt- und Ausgabenlimit pro Aufgabe; jede Antwort lässt sich rückgängig machen, und nichts wird gesendet, bevor Sie auf Senden klicken.',
    ),
  ],
  aiCta: 'KI-Assistent öffnen',
  featuresTitle: 'Was OpenCADIrrigation kann',
  features: [
    (
      'KI-Assistent',
      'Optional: Stellen Sie der KI Fragen zum Projekt oder lassen Sie sie für Sie zeichnen und planen. Sie ordnet Regner und Tropfleitungen an, teilt Felder auf, verlegt Rohre und startet die Dimensionierung und die automatischen Werkzeuge; dabei sieht sie sich Satellitenbild und Gelände an und nutzt Claude-Modelle (Anthropic) oder GPT-Modelle (OpenAI) mit Ihrem eigenen API-Schlüssel, direkt aus dem Browser und ohne zwischengeschalteten Server. Nichts wird gesendet, bevor Sie auf Senden klicken, und jede Änderung wartet auf Ihre Zustimmung (oder wird auf Wunsch automatisch angewendet) und lässt sich rückgängig machen.',
    ),
    (
      'Automatischer Entwurf und Dimensionierung',
      'Lateralblöcke und Regnerraster mit einem Klick, Regneranordnung mit angepasster Niederschlagsrate, Zoneneinteilung nach Durchfluss, Verlegung von Rohren und Ventilen, Aufteilung von Feldern in Blöcke, Einpassen von Pivots und Vegetationserkennung in Luftbildern; Rohrdimensionierung per linearer Optimierung unter Einhaltung des Druckfensters der Emitter und der Druckstufe der Rohre, mit Abwägung zwischen Rohr- und Energiekosten.',
    ),
    (
      'Vollwertiges CAD',
      'Linien, Polylinien, Bögen, Splines, Schraffuren, Bemaßungen, Texte, Ebenen und Blöcke, mit Koordinateneingabe, Objektfang, polarer Spur, Griffen, Revisionswolken und den Kurzbefehlen von CAD-Programmen (L, PL, C, D, ZE…).',
    ),
    (
      'Hydraulisches Netz',
      'Wasserquellen, Pumpen mit fester und variabler Drehzahl, Hauptleitung, Zonen-, Druckminder-, Druckhalte- und Durchflussregelventile, Regner mit integriertem Ventil, Laterale mit Emittern, Tropfbänder, Filter und Wasserzähler, dazu Center-Pivots und Linearanlagen mit ihrem Regnerpaket, Schlauchtrommelmaschinen und Oberflächenbewässerung.',
    ),
    (
      'Validierte Hydraulik',
      'Hazen-Williams, Darcy-Weisbach, Scobey und Manning, Einzelverluste der verwendeten Formteile, Emitter q = k·Hˣ, Netzberechnung mit dem Global Gradient Algorithm (wie in EPANET), Pumpenkennlinien mit NPSH, Druckstoßberechnung nach dem Charakteristikenverfahren mit Be-/Entlüftungsventilen und eine 24-Stunden-Simulation mit Energietarifen.',
    ),
    (
      'Gelände, Klima und Agronomie',
      'Höhenlinien, Höhenpunkte, trianguliertes Geländemodell mit Bruchkanten, Online-Geländehöhen, LAS-Punktwolken, Hangneigungskarten und Längsprofile; heruntergeladenes oder selbst eingegebenes Standortklima, FAO-56-Kulturen nach Wachstumsphasen, Böden, effektiver Regen und Auswaschung für den Wasserbedarf, dazu Wasserbudgets für Grünanlagen.',
    ),
    (
      'Berichte, Pläne und Material',
      'Zonen, Rohre, Emitter, Gleichmäßigkeit (CU, DU, EU), Programm des Steuergeräts und Ventilverkabelung; Stückliste mit Formteilen und Angebot mit Arbeitskosten, Steuern und Amortisationszeit; PDF-Plansätze mit Baudetails und Diagrammen in jeder der 20 Sprachen und alle Tabellen als Excel-, CSV- und TXT-Datei.',
    ),
    (
      'Datenaustausch',
      'Importiert DXF, DWG, PDF-Pläne, KML/KMZ, Shapefiles, GeoJSON, GPX, LandXML, LAS, DGN, EPANET .inp, CSV/XYZ, GeoTIFF und Bilder; exportiert DXF 2000 mit nativen Objekten (oder R12), DWG, PDF, PNG, SVG, KML/KMZ, GeoJSON, Shapefiles, GPX, LandXML, EPANET .inp und IFC.',
    ),
    (
      'Herstellerkataloge',
      'Herstellerkataloge in JSON (Netafim, Rivulis, Jain, Toro, Rain Bird, Nelson, Hunter, NaanDanJain, Senninger, Irritec, Bermad, Schneider, Amanco Wavin, Multilit), sofort einsatzbereit, dazu eigene Pakete aus einer Datei oder URL.',
    ),
    (
      'Offline und im Feld',
      'Nach dem ersten Besuch startet die App auch ohne Netzverbindung, auf Computer, Tablet oder Smartphone, im hellen oder dunklen Design. Im Feld zeichnet das Geräte-GPS bei der Begehung Umrisse und Linien auf, markiert Punkte und zeigt Entfernung und Richtung zum ausgewählten Objekt für die Absteckung.',
    ),
  ],
  howTitle: 'So funktioniert es',
  how: [
    (
      'Fläche zeichnen oder importieren',
      'Laden Sie ein DXF, DWG, KML oder ein Satellitenbild, zeichnen Sie Feld, Garten oder Sportplatz direkt oder nennen Sie dem KI-Assistenten die Adresse: Er findet den Standort auf der Karte. Fügen Sie Höhenlinien hinzu oder laden Sie die Geländehöhe ab einer Koordinate.',
    ),
    (
      'Netz aufbauen, von Hand oder mit der KI',
      'Erzeugen Sie Lateralblöcke oder Regnerraster mit einem Klick, oder bitten Sie den KI-Assistenten, die Regner anzuordnen, das Feld aufzuteilen, die Rohre zu verlegen und Ventile, Pumpe und Wasserquelle zu setzen; verbinden Sie danach alles über die Hauptleitung.',
    ),
    (
      'Auslegen und dokumentieren',
      'Drücken Sie F5 oder bitten Sie die KI darum: Die App dimensioniert Zonen und Hauptleitung, prüft Drücke und Fließgeschwindigkeiten und erstellt Berichte, Stückliste und den PDF-Plan.',
    ),
  ],
  examplesTitle: 'Fertige Beispiele zum Öffnen',
  examplesIntro: 'Jedes Projekt öffnet sich vollständig und wird mit F5 ausgelegt. Nutzen Sie die Beispiele zum Kennenlernen der App oder als Ausgangspunkt.',
  examples: [
    SiteExample('orchard', 'Obstgarten', 'Mikroregner auf Zitrus und Tropfbewässerung auf Reben, Brunnen mit Pumpe und Filter, geneigtes Gelände.'),
    SiteExample('garden', 'Hausgarten', 'Versenkregner auf dem Vorgarten-Rasen, Getrieberegner hinten und Tropfbewässerung in den Beeten, gespeist aus dem Netz mit Zähler und Rückflussverhinderer.'),
    SiteExample('sportsField', 'Fußballplatz', 'Normplatz 105 × 68 m mit Schwinghebelregnern in fünf Reihen, Speicher, Pumpe und Nachtbetrieb.'),
    SiteExample('rowCrop', 'Reihenkultur mit Tropfbewässerung', 'Vier Tomatenblöcke mit Tropfband, Verteilleitungen mit Ventilen, Siebfilter, Pumpe und geneigtes Gelände.'),
    SiteExample('pivot', 'Center-Pivot', 'Ein 300-m-Pivot auf Mais, gespeist über Hauptleitung, Brunnen und Pumpe; Turm-, Spannen- und Düsenbericht.'),
    SiteExample('greenhouse', 'Gemüsegewächshaus', 'Vier Paprikatunnel mit druckkompensierendem Tropfrohr, eine Zone je Tunnel, Behälter, kleine Pumpe und Scheibenfilter.'),
    SiteExample('nursery', 'Baumschule', 'Drei Beete 12 × 48 m unter hängenden Mikroregnern im 4 × 4-m-Raster, eine Zone je Beet, Hochbehälter, kleine Pumpe und Scheibenfilter.'),
    SiteExample('coffee', 'Kaffee auf Höhenlinien', 'Drei Kaffeeblöcke am Hang mit gekrümmten Lateralen entlang der Höhenlinien (geführter Block), PC-Tropfrohr, Brunnen und Pumpe am Hangfuß.'),
    SiteExample('bananas', 'Bananenplantage', 'Zwei Bananenblöcke unter druckkompensierenden Mikroregnern im 5 × 5-m-Raster, Brunnen mit Tauchpumpe, Scheibenfilter und geneigtes Gelände.'),
    SiteExample(
      'sugarcane',
      'Zuckerrohr mit unterirdischer Tropfbewässerung',
      'Zwei Zuckerrohrblöcke mit 20-mm-PC-Tropfrohr in 0,3 m Tiefe, 180-m-Laterale, unterirdische Verteilleitungen, Speicher, Pumpe, Siebfilter und Be-/Entlüfter.',
    ),
    SiteExample(
      'gravity',
      'Tropfbewässerung im Schwerkraftbetrieb',
      'Ein Speicher 40 m über zwei tropfbewässerten Gemüseblöcken, ohne Pumpe: Absperrschieber, Druckminderer und Scheibenfilter an der Hauptleitung; Höhenlinien des Hangs.',
    ),
    SiteExample('pasture', 'Weideberegnung', 'Drei Koppeln 72 × 72 m mit Schwinghebelregner-Leitungen im 12 × 18-m-Raster, Verteilleitungen mit Ventilen, Speicher, Pumpe und Rückschlagventil.'),
    SiteExample('golf', 'Golfloch', 'Abschlag mit Sprühdüsen, Fairway mit Getrieberegnern im Dreiecksraster (zwei Zonen) und Grün mit Regnern am Rand, Teich mit Pumpe und Nachtbetrieb.'),
    SiteExample(
      'sectorPivot',
      'Sektorpivot mit Endregner',
      'Ein 250-m-Pivot auf Sojabohnen, der 270° überstreicht und den Hofquadranten frei lässt, mit 12-m³/h-Endregner; Teich, 20-PS-Pumpe und Absperrschieber.',
    ),
    SiteExample('linear', 'Linearberegnung', 'Eine 392-m-Linearanlage auf Weizen, die 800 m entlang eines Kanals fährt, Entnahme mit 30-PS-Pumpe und Rückschlagventil; Turm- und Düsenbericht.'),
  ],
  faqTitle: 'Häufige Fragen',
  faq: [
    (
      'Was ist OpenCADIrrigation?',
      'OpenCADIrrigation ist eine kostenlose Open-Source-Webanwendung für die Planung von Druckbewässerungsanlagen: ein CAD mit Hydraulik-Rechenkern, der das Netz anlegt, die Rohre dimensioniert, Drücke und Gleichmäßigkeit prüft und Stückliste und Berichte erstellt – vom Hausgarten bis zum Center-Pivot. Dazu kommt ein optionaler KI-Assistent, der das Projekt anhand einer Beschreibung des Standorts mit Ihnen zeichnet und plant.',
    ),
    (
      'Kann eine KI das Projekt für mich planen?',
      'Ja, wenn Sie das möchten. Der optionale KI-Assistent arbeitet im geöffneten Projekt mit denselben Werkzeugen wie die Menüs: Beschreiben Sie den Standort oder lassen Sie ihn das Satellitenbild und das Gelände eines georeferenzierten Projekts ansehen, und er ordnet Regner und Tropfleitungen an, teilt Felder in Blöcke auf, verlegt Rohre und setzt Ventile, platziert Pumpe und Wasserquelle, startet die Auslegung und die automatischen Werkzeuge, behebt die Warnungen, optimiert die Kosten und schreibt den Erläuterungsbericht. Vor jeder Änderung fragt er nach (oder wendet die Änderungen auf Wunsch automatisch an), und jede Antwort lässt sich mit einem Klick rückgängig machen. Ein Modell kann sich irren; prüfen Sie seine Arbeit daher wie die eines Kollegen.',
    ),
    (
      'Welche KI-Modelle nutzt es?',
      'Claude-Modelle von Anthropic (standardmäßig Claude Opus 5.5, außerdem Claude Fable 5.1, Claude Sonnet 5.5 und Claude Haiku 5.5) und GPT-Modelle von OpenAI (GPT-6 Astra, GPT-6.1 Sol und GPT-6 Luna): Spitzen-, Mittelklasse- und schnelle Modelle beider Unternehmen, jeweils mit fünf Stufen der Denktiefe. Sie wählen das Modell in den Einstellungen des Assistenten und fügen Ihren eigenen API-Schlüssel ein; das Panel zeigt die Tokens und die geschätzten Kosten jeder Antwort, und ein Schrittlimit sowie ein Ausgabenlimit stoppen eine Aufgabe, die sich in die Länge zieht.',
    ),
    (
      'Was sendet der KI-Assistent und wohin?',
      'Nichts, solange Sie nicht auf Senden klicken. Dann gehen Ihre Nachricht, die angehängten Dateien und die von Ihnen angehakten Projektdaten direkt von Ihrem Browser an die API des gewählten Anbieters, Anthropic oder OpenAI, ohne zwischengeschalteten Server von OpenCADIrrigation, zusammen mit den Ergebnissen der Werkzeuge, die der Assistent beim Antworten nutzt, einschließlich Bildern der Zeichnung. Der Anbieter rechnet die Nutzung über Ihr Konto ab. Der Schlüssel bleibt nur für die Dauer der Sitzung im Arbeitsspeicher, es sei denn, Sie lassen ihn auf dem Gerät speichern, und er gelangt nie in Projektdateien, Freigabelinks oder Exporte. Das Diktieren per Sprache übernimmt, wenn Sie es nutzen, die Spracherkennung des Browsers selbst, die den Ton an den Hersteller des Browsers sendet (Google bei Chrome, Microsoft bei Edge, Apple bei Safari). Gespeicherte Gespräche bleiben in Ihrem Browser, nie in Projektdateien oder Links.',
    ),
    (
      'Ist OpenCADIrrigation kostenlos?',
      'Ja. Es ist kostenlos für berufliche, akademische und private Nutzung, ohne Registrierung. Außerdem ist es Open Source unter der MIT-Lizenz; der Quellcode ist auf GitHub veröffentlicht. Der optionale KI-Assistent nutzt Ihr eigenes Konto bei Anthropic oder OpenAI, über das der jeweilige Anbieter die Nutzung abrechnet.',
    ),
    (
      'Für wen ist es gedacht?',
      'Für Planer landwirtschaftlicher und landschaftsgärtnerischer Bewässerung, Agronomen und Ingenieure, Fachhändler, Lehrende und Studierende. Mit dem interaktiven Tutorial, 15 fertigen Beispielen und dem KI-Assistenten geht es ohne Handbuch los.',
    ),
    (
      'Muss ich etwas installieren?',
      'Nein. Es läuft in Chrome, Edge, Firefox und Safari auf Computer, Tablet und Smartphone und lässt sich als App (PWA) installieren, die sich in einem eigenen Fenster öffnet.',
    ),
    (
      'Funktioniert es offline?',
      'Ja, nach dem ersten Besuch: Die App speichert eine Kopie von sich selbst im Browser (etwa 24 MB, einmal je Version), sodass der nächste Start – als installierte App oder über die Website – ohne Netzverbindung funktioniert, im Büro wie im Feld. Hintergrundkarten, Online-Geländehöhen und -Klimadaten, per URL geladene Kataloge und der KI-Assistent brauchen weiterhin eine Verbindung; eine neue Version wird im Hintergrund heruntergeladen und ab dem nächsten Start verwendet.',
    ),
    (
      'Werden meine Projekte in der Cloud gespeichert?',
      faqCloudAnswerEn,
    ),
    (
      'Wie wird die Hydraulik berechnet?',
      'Reibungsverluste nach Hazen-Williams, Darcy-Weisbach, Scobey oder Manning, Emitter nach q = k·Hˣ und das gesamte Netz mit dem Global Gradient Algorithm, dem Verfahren von EPANET. Die Rohrdurchmesser werden per linearer Optimierung innerhalb des Druckfensters der Emitter und der Druckstufe der Rohre bestimmt; außerdem prüft die Berechnung Gleichmäßigkeit (CU, DU, EU), Spülung und Druckstöße nach dem Charakteristikenverfahren (Ventilschließung, Pumpenausfall, Be-/Entlüftungsventile), mit einer 24-Stunden-Simulation von Drücken und Energiekosten.',
    ),
    (
      'Funktioniert es mit anderen CAD-Programmen?',
      'Ja. Es importiert DXF und DWG bis Version 2018, DGN V7 und PDF-Pläne und exportiert DXF 2000 mit nativen Objekten (Polylinien mit Bögen, Schraffuren, Splines, Bemaßungen, Blöcke mit Attributen), DXF R12 für ältere Programme und DWG 2000. Für GIS, Vermessung und BIM liest und schreibt es außerdem KML/KMZ, Shapefiles, GeoJSON, GPX, LandXML und EPANET .inp, liest LAS-Punktwolken und exportiert IFC 4.',
    ),
    (
      'In welchen Sprachen ist es verfügbar?',
      'In 20 Sprachen, denselben wie auf dieser Website (die Liste steht am Seitenende). Die App öffnet sich in der Sprache Ihres Computers, und unter Ansicht → Sprache können Sie jederzeit wechseln.',
    ),
  ],
  loading: 'Das Bewässerungs-CAD wird geladen…',
  slow: 'Das Laden dauert länger als üblich. Prüfen Sie die Verbindung oder laden Sie die Seite neu; der Inhalt oben ist bereits lesbar.',
  noScript: 'OpenCADIrrigation benötigt JavaScript. Aktivieren Sie JavaScript im Browser und laden Sie die Seite neu.',
  otherLanguages: 'Sprachen',
  footer: 'Herstellerkataloge und Beispielprojekte können im JSON-Format zur Aufnahme in OpenCADIrrigation eingereicht werden.',
  sourceCode: 'Quellcode (MIT-Lizenz)',
  subCategory: 'CAD für Bewässerung',
  screenshotLabel: 'Dimensionierte Bewässerungsanlage mit Ergebnissen je Zone',
  notFoundTitle: 'Seite nicht gefunden',
  notFoundText: 'Diese Adresse gibt es auf dieser Website nicht. OpenCADIrrigation ist eine einzige Anwendung; öffnen Sie sie über die Startseite.',
  notFoundHome: 'Zu OpenCADIrrigation',
);
