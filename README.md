# SolarDecision Hub

**SolarDecision Hub** ist eine XML-basierte Entscheidungsplattform für private und gewerbliche Solaranlagenbesitzer. Ziel ist es, auf Basis strukturierter Energie-, Wetter- und Marktdaten eine fundierte Empfehlung zu liefern, ob erzeugter Solarstrom aktuell **eingespeist oder selbst genutzt** werden soll.

Die Plattform ist bewusst **XML-zentrisch** aufgebaut und nutzt XML-Technologien als Kern der gesamten Datenverarbeitung, Validierung, Logik und Darstellung.

---

## Kernidee

Solaranlagenbesitzer stehen vor Entscheidungsunsicherheit aufgrund stark schwankender Strompreise und unvorhersehbarer Energieverfügbarkeit. SolarDecision Hub schafft Transparenz und Entscheidungsunterstützung durch:

- konsolidierte XML-Datenhaltung
- regelbasierte Empfehlungsgenerierung mit XSLT
- visuelle Aufbereitung über XHTML und SVG
- optionales Reporting als PDF über XSL-FO

---

## Architekturüberblick

- **Datenhaltung:** ausschliesslich in XML
- **Validierung:** XSD und Schematron vor jeder Weiterverarbeitung
- **Transformationen:**
    - XML → XHTML für das Web-Dashboard
    - XML → SVG für grafische Visualisierungen
    - XML → XSL-FO → PDF für Reports
- **Frontend:** XHTML-konform mit minimalem JavaScript
- **Backend:** kein Einsatz von Webservices oder Datenbanken

Die gesamte Anwendungslogik basiert auf XML und XSLT. JavaScript wird ausschliesslich für UI-Interaktionen eingesetzt.

---

## Erfüllung der Rahmenbedingungen

- Webserver mit minimalem JavaScript
- Ausschliessliche XML-Datenhaltung
- Kein Daten-Update ohne vorherige Validierung
- Einsatz von XSLT als zentrales Feature
- XHTML-konformes Frontend
- Nutzung von SVG und XSL-FO für Visualisierung und Reporting

---

## Ziel

Eine schlanke, standardkonforme Plattform, die XML nicht nur als Datenformat nutzt, sondern als **zentrales Architekturprinzip**, um nachvollziehbare, plausible und nutzerrelevante Entscheidungen für Solaranlagenbesitzer zu ermöglichen und so die Wirtschaftlichkeit zu erhöhen.

---

## Data Setup 

java -jar tools/saxon-he.jar -xsl:csv_to_prices_xml.xsl -it:main -o:data/prices.xml csv-uri=imports/prices.csv
java -jar tools\saxon-he.jar -xsl:csv_to_sunshine_xml.xsl -it:main -o:data/sunshine.xml csv-uri=imports/sunshine.csv

## Recommendation Engine

java -jar tools/saxon-he.jar -xsl:cluster_recommendations.xsl -it:main -o:data/recommendation.xml prices-uri=data/prices.xml sunshine-uri=data/sunshine.xml

## Dashboard Creation

java -jar tools\saxon-he.jar -s:data\recommendation.xml -xsl:dashboard.xsl -o:web\dashboard.xhtml

## PDF Generation (XSL-FO)

Die PDF-Generierung läuft jetzt lokal über:

1. `data/recommendation.xml` + `xslt/fo/report.fo.xsl` -> FO (Saxon)
2. FO -> PDF (Apache FOP)

### PDF Renderer per Env Var

Im Docker-Setup kann das PDF-Rendering umgeschaltet werden:

- `PDF_RENDERER=local` (Standard): lokale Erstellung mit Apache FOP im Container
- `PDF_RENDERER=remote`: Sendet das erzeugte FO an einen externen FOP-Service
- `FOP_REMOTE_URL`: Ziel-URL für `remote` (Standard: `https://fop.xml.hslu-edu.ch/fop.php`)

Beispiel lokal (FOP im Container):

```bash
PDF_RENDERER=local docker compose up --build
```

Beispiel mit Original-Endpoint:

```bash
PDF_RENDERER=remote FOP_REMOTE_URL=https://fop.xml.hslu-edu.ch/fop.php docker compose up --build
```

### Errorview

The errorview can be tested by using an incorrect query param `https://localhost:3000/report.pdf?dt=not-a-date"
