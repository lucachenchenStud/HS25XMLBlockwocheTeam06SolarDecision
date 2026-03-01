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

## PDF Generation (XSL-FO)

Die PDF-Generierung läuft lokal über:

1. `data/recommendation.xml` + `xslt/fo/report.fo.xsl` → FO (Saxon)
2. FO → PDF (Apache FOP)

### PDF Renderer per Env Var

Im Docker-Setup kann das PDF-Rendering umgeschaltet werden:

- `PDF_RENDERER=local` (Standard): lokale Erstellung mit Apache FOP im Container
- `PDF_RENDERER=remote`: Sendet das erzeugte FO an einen externen FOP-Service
- `FOP_REMOTE_URL`: Ziel-URL für `remote` (Standard: `https://fop.xml.hslu-edu.ch/fop.php`)

Beispiel lokal:

```bash
PDF_RENDERER=local docker compose up --build
```

Beispiel mit externem Endpoint:

```bash
PDF_RENDERER=remote FOP_REMOTE_URL=https://fop.xml.hslu-edu.ch/fop.php docker compose up --build
```

---

Export Endpoint (/report.pdf)

Der PDF-Export wird über den HTTP-Endpunkt /report.pdf bereitgestellt.
Der Endpunkt akzeptiert optionale Query-Parameter (z. B. dt) zur zeitlichen Auswahl der Datenbasis.

Das Rendering-Verhalten wird über Environment-Variablen gesteuert:

- `PDF_RENDERER=local` → lokale PDF-Erstellung mit Apache FOP im Container

- `PDF_RENDERER=remote` → Weiterleitung des FO-Dokuments an einen externen FOP-Service

- `FOP_REMOTE_URL` → Konfiguration des Remote-Endpunkts

Diese Konfigurierbarkeit ermöglicht unterschiedliche Deployment-Szenarien, ohne die XML-Transformationslogik zu verändern.

---

Error View Darstellung (XHTML)

Die Fehlerdarstellung erfolgt über ein separates XSLT-2.0-Stylesheet, das eine XHTML-1.0-Strict Seite erzeugt.

Die Error View kann getestet werden, indem ein ungültiger Query-Parameter verwendet wird:

```bash
https://localhost:3000/report.pdf?dt=not-a-date
```

Die Darstellung wird über folgende Parameter gesteuert:

- statusCode

- title

- message

- requestPath

Fehlerzustände werden strukturiert und benutzerfreundlich angezeigt, wodurch die Robustheit der Anwendung erhöht wird.

---

Technische Umsetzung der PDF- und Export-Komponenten
FO PDF Generator – Transformationslogik

Die PDF-Erstellung basiert auf einer XSLT-2.0-Transformation, welche XML-Daten in ein vollständiges XSL-FO-Dokument überführt.

Die Implementierung umfasst:

- Verarbeitung eines optionalen Zeitparameters `dt`

- Dynamische Auswahl des passenden `sample`-Datensatzes

- Fallback-Logik auf den letzten Eintrag bei fehlender Übereinstimmung

- Preisumrechnung in CHF/kWh mittels XSLT-Funktion

- Aggregation der letzten 24 Einträge zur statistischen Verteilung

- Definition eines vollständigen FO-Seitenlayouts mit Header, Footer, Tabellen und Seitenzahlen

Das erzeugte FO-Dokument dient als Grundlage für das anschliessende Rendering durch Apache FOP.

---

Export-Endpunkt – Verarbeitungsschicht

Der Export-Endpunkt verbindet die HTTP-Anfrage mit der Transformationspipeline.

Funktionalität:

- Entgegennahme optionaler Query-Parameter

- Auslösung der XML → XSL-FO Transformation

- Übergabe des FO-Dokuments an den konfigurierten Renderer

- Rückgabe des erzeugten PDFs als HTTP-Response

---

Error View – Strukturierte Fehlerbehandlung

Die Fehlerdarstellung wird über ein eigenständiges XSLT-2.0-Stylesheet generiert, welches eine validierungsfähige XHTML-Seite ausgibt.

Die Implementierung stellt sicher:

- Parameterbasierte Fehlerdarstellung

- Saubere Trennung von Fehler- und Erfolgsfall

- Konsistente visuelle Aufbereitung von Statusinformationen

- Stabilität der Anwendung bei ungültigen Eingaben
