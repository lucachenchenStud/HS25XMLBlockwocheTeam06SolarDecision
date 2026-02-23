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

## DELETE ME AFTER REVIEW

### Last Two Commits: Detailed Change Breakdown

This document explains the last two commits in detail.

### Commits Covered

- `e137bb28a282486947c281e5176aee23a767e08c`
  - Message: `fix(error-view): add global 500 XHTML handler and implement missing error template`
- `5696ce4534894a6a893eaccf7a7bce33190f2bb5`
  - Message: `feat(FO PDF Render): added funtionality`

### FO PDF Render Feature

#### `index.js`

This commit introduced the complete FO->PDF generation pipeline in the server.

- Added environment-controlled renderer selection:
  - `PDF_RENDERER` (`local` or `remote`)
  - `FOP_REMOTE_URL` (endpoint for remote FOP conversion)
- Added reusable command wrapper:
  - `runCommand(command, args, options)` for `java` and `fop` execution.
- Added FO generation from recommendation XML:
  - `generateFoReport(dt)` runs Saxon with:
    - source: `data/recommendation.xml`
    - stylesheet: `xslt/fo/report.fo.xsl`
    - output: temporary `report.fo`
  - Uses a temp directory and cleans up with `fs.rmSync(..., { recursive: true, force: true })`.
- Added local PDF rendering:
  - `renderPdfLocal(foBuffer)` writes FO to temp file, runs Apache FOP, returns PDF buffer.
- Added remote PDF rendering:
  - `renderPdfRemote(foBuffer)` sends FO to remote FOP via HTTP `POST`.
  - Checks HTTP status and throws explicit error on failure.
- Added high-level renderer orchestrator:
  - `generatePdfReport(dt)` chooses local or remote renderer based on env var.
- Added new route:
  - `GET /report.pdf`
  - Generates report from current or selected datetime and returns downloadable PDF.
  - Sets `Content-Disposition` filename with sanitized datetime token.
- Reworked existing route:
  - `POST /convertToPdf` no longer forwards raw request body directly to external service.
  - It now uses the same internal FO->PDF flow as `GET /report.pdf`.
- Startup logging now prints active renderer mode.

Behavior impact:

- PDF export became a first-class backend feature with consistent local/remote strategy.
- Conversion logic became deterministic and reusable between routes.
- Error handling for PDF routes was still direct/plain-text at this stage (later centralized in next commit).

#### `dashboard.xsl`

This commit connected the UI to the new PDF export route.

Changes:

- Added `.actions a { text-decoration:none; }` to make anchor buttons look consistent.
- Converted action markup from nested `<a><div class="btn">...</div></a>` to cleaner anchor-button pattern:
  - Feedback button now uses `<a href="/feedback" class="btn primary">...`.
  - Added functional PDF export anchor:
    - `href="/report.pdf?..."`
    - Includes `dt` query when a datetime is selected.
    - Uses `encode-for-uri(substring($dtNorm, 1, 16))`.

Behavior impact:

- The PDF export button became functional and passes selected datetime context to backend.
- Semantic HTML and styling consistency improved for action buttons.

#### `xslt/fo/report.fo.xsl`

This file was created and contains the FO template for PDF rendering.

Main logic:

- Input model: `/clusters` with `sample` items.
- Parameter:
  - `$dt` datetime selector.
- Helper:
  - `f:to-chf()` converts rappen-like price values to CHF by dividing by 100.
- Selection strategy:
  - Normalizes `$dt` to include seconds (`:00`).
  - Picks the latest sample `<= dt`, or falls back to last sample if none matched.
- Metrics extracted for report:
  - timestamp, recommendation, converted price, sunshine, cluster.
- Added distribution summary:
  - Counts SELL/HOLD/BUY over last 24 samples.

FO layout/content:

- A4 page master with header/footer regions.
- Header: product title.
- Footer: page number.
- Body sections:
  - Report title and generation timestamp.
  - “Aktuelle Empfehlung” table with key current metrics.
  - “Verteilung letzte 24 Stunden” table with recommendation counts.

Behavior impact:

- Enabled deterministic XML->FO transformation for rendering with FOP.
- Gave PDF output structured summary and operational metrics, not just raw values.

### Error View + 500 Handling Fix

#### `index.js`

This commit centralized error handling and integrated an XHTML error view pipeline.

New helper functions:

- `createHttpError(status, message)`
  - Normalizes custom status propagation through `next(err)`.
- `renderErrorView(statusCode, title, message, requestPath)`
  - Runs Saxon transform with:
    - source: `web/error.xml`
    - stylesheet: `xslt/views/error-view.xsl`
    - params: status code, title, message, request path.

Route-level error handling changes:

- Updated handlers to include `next` and delegate failures:
  - `GET /`
  - `GET /report.pdf`
  - `POST /convertToPdf`
  - `GET /feedback`
- Replaced direct `res.status(500).type('text/plain')...` with `next(createHttpError(...))`.

`/updateData` hardening:

- Wrapped logic in `try/catch` and forwards unexpected errors to middleware.
- Added explicit required-field checks:
  - `plant`, `price`, `date` must be present.
- Replaced direct XPath interpolation lookup with safer node traversal:
  - find all plants, match by normalized `<name>` text.
- Added not-found response for unknown plant (`404`).
- Added guard for missing `<statistics>` node.
- Keeps validation gate before writing file.

Validation fix:

- Added missing `validateDatabase(xmlDoc)` function.
- Uses `schema/database.xsd`.

Global error middleware:

- Added final Express error middleware:
  - Determines status code and title (`Not Found` vs `Internal Server Error`).
  - Logs stack trace.
  - Attempts to render XHTML error page via `renderErrorView(...)`.
  - Falls back to plain text `500` if view rendering itself fails.

Behavior impact:

- Error responses are now centralized and consistently formatted.
- Unexpected route failures surface as rendered error page instead of mixed plain-text outputs.
- `/updateData` no longer fails due to missing `validateDatabase` definition.

#### `xslt/views/error-view.xsl`

This file was previously empty and is now fully implemented.

What it does:

- Accepts runtime parameters:
  - `statusCode`
  - `title`
  - `message`
  - `requestPath`
- Matches `/error` source XML and renders XHTML 1.0 Strict output.
- Provides styled error card UI with:
  - large status code
  - human-readable title/message
  - request path display
  - link back to `/`

Behavior impact:

- Creates a reusable transform-based error view for server-side failures.
- Keeps error presentation within project’s XML/XSL architecture.

#### `web/error.xml`

New XML source used by the error-view transformation.

Contents:

- Root `<error>` element with default title/message placeholder fields.

Role:

- Acts as stable XML input for `xslt/views/error-view.xsl`.
- Dynamic details are injected via XSLT parameters at render time.

#### `schema/database.xsd`

New XSD schema for the temporary database model used by `/updateData`.

Schema structure:

- Root `<database>`
- Repeating `<plant>`
- `<name>` (string)
- `<statistics>` containing 0..n `<price>` entries
- `<price>` value typed as `xs:decimal`
- Required `date` attribute typed as `xs:dateTime`

Role:

- Validation gate to prevent invalid XML writes from `/updateData`.
- Converts previous runtime failure into predictable validation behavior.

#### `data/database.xml`

New XML fixture for `/updateData` testing and local runtime stability.

Data shape:

- Root `<database>`
- One sample plant (`ExamplePlant`)
- One sample price record under `<statistics>`

Role:

- Provides concrete data so `/updateData` can read, mutate, and validate.
- Avoids missing-file/missing-schema failures in development and container runs.


