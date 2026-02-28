const express = require('express')
const path = require('path')
const fs = require('fs')
const os = require('os') // used for temporary directory management
const libxmljs = require('libxmljs2')
const app = express()
const { execFile } = require('child_process')

const schemaCache = new Map();
// Choose between local Apache FOP rendering and remote FOP service rendering.
const PDF_RENDERER = (process.env.PDF_RENDERER || 'local').trim().toLowerCase()
const FOP_REMOTE_URL = (process.env.FOP_REMOTE_URL || 'https://fop.xml.hslu-edu.ch/fop.php').trim()

app.use(express.static(__dirname));
app.use(express.text());
app.use(express.urlencoded({ extended: false }));

function runCommand(command, args, options = {}) {
    // Run shell commands in one place so the rest of the code can simply use await + try/catch.
    return new Promise((resolve, reject) => {
        // Keep one shared process config (e.g. larger output buffer for Saxon/FOP logs).
        execFile(command, args, { maxBuffer: 50 * 1024 * 1024, ...options }, (err, stdout, stderr) => {
            if (err) {
                // Normalize subprocess failures into one consistent error shape.
                const message = (stderr || err.message || '').trim()
                reject(new Error(`${command} failed: ${message}`))
                return
            }
            resolve({ stdout, stderr })
        })
    })
}

function createHttpError(status, message) {
    // Helper to pass HTTP status + message into Express error middleware.
    const err = new Error(message)
    err.status = status
    return err
}

async function renderErrorView(statusCode, title, message, requestPath) {
    // Build the error page by transforming error.xml with the XSLT error view.
    const saxonJar = path.resolve('tools', 'saxon-he.jar')
    const xmlPath = path.resolve('web', 'error.xml')
    const xslPath = path.resolve('xslt', 'views', 'error-view.xsl')

    const args = [
        '-jar', saxonJar,
        `-s:${xmlPath}`,
        `-xsl:${xslPath}`,
        `statusCode=${String(statusCode)}`,
        `title=${title || 'Internal Server Error'}`,
        `message=${message || 'Unexpected error'}`,
        `requestPath=${requestPath || '/'}`
    ]

    const { stdout } = await runCommand('java', args)
    return stdout
}

async function generateFoReport(dt) {
    // Step 1: recommendation XML -> FO file (via Saxon).
    const saxonJar = path.resolve('tools', 'saxon-he.jar')
    const xmlPath = path.resolve('data', 'recommendation.xml')
    const xslPath = path.resolve('xslt', 'fo', 'report.fo.xsl')
    const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'solardecision-'))
    const foPath = path.join(tempDir, 'report.fo')
    const dtParam = (dt || '').trim()

    const saxonArgs = [
        '-jar', saxonJar,
        `-s:${xmlPath}`,
        `-xsl:${xslPath}`,
        `-o:${foPath}`,
        `dt=${dtParam}`
    ]

    try {
        await runCommand('java', saxonArgs)
        return fs.readFileSync(foPath)
    } finally {
        fs.rmSync(tempDir, { recursive: true, force: true })
    }
}

async function renderPdfLocal(foBuffer) {
    // Step 2a: FO -> PDF using local Apache FOP binary.
    const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'solardecision-'))
    const foPath = path.join(tempDir, 'report.fo')
    const pdfPath = path.join(tempDir, 'report.pdf')

    try {
        fs.writeFileSync(foPath, foBuffer)
        await runCommand('fop', ['-fo', foPath, '-pdf', pdfPath])
        return fs.readFileSync(pdfPath)
    } finally {
        fs.rmSync(tempDir, { recursive: true, force: true })
    }
}

async function renderPdfRemote(foBuffer) {
    // Step 2b: FO -> PDF by sending FO to remote FOP endpoint.
    const response = await fetch(FOP_REMOTE_URL, {
        method: 'POST',
        body: foBuffer,
        headers: {
            'Content-Type': 'application/xml'
        }
    })

    if (!response.ok) {
        const responseText = await response.text()
        throw new Error(`Remote FOP failed (${response.status}): ${responseText}`)
    }

    const arrayBuffer = await response.arrayBuffer()
    return Buffer.from(arrayBuffer)
}

async function generatePdfReport(dt) {
    // Single entry point for the full report pipeline (XML -> FO -> PDF).
    const foBuffer = await generateFoReport(dt)
    if (PDF_RENDERER === 'remote') {
        return renderPdfRemote(foBuffer)
    }
    return renderPdfLocal(foBuffer)
}

app.get('/', (req, res, next) => {
    const dt = (req.query.dt || '').trim()

    const saxonJar = path.resolve('tools', 'saxon-he.jar')
    const xmlPath = path.resolve('data', 'recommendation.xml')
    const xslPath = path.resolve('dashboard.xsl')

    const args = [
        '-jar', saxonJar,
        `-s:${xmlPath}`,
        `-xsl:${xslPath}`,
        dt ? `dt=${dt}` : null
    ].filter(Boolean)

    execFile('java', args, { maxBuffer: 50 * 1024 * 1024 }, (err, stdout, stderr) => {
        if (err) {
            next(createHttpError(500, stderr || err.message))
            return
        }
        res.status(200).type('application/xhtml+xml').send(stdout)
    })
})

app.get('/report.pdf', async (req, res, next) => {
    try {
        const dt = (req.query.dt || '').trim()
        const pdfBuffer = await generatePdfReport(dt)
        const safeDt = dt ? dt.replace(/[^0-9T-]/g, '_') : 'latest'

        res.setHeader('Content-Type', 'application/pdf')
        res.setHeader('Content-Disposition', `attachment; filename=\"solar-report-${safeDt}.pdf\"`)
        res.status(200).send(pdfBuffer)
    } catch (err) {
        console.error('PDF generation failed:', err.message)
        next(createHttpError(500, err.message))
    }
})

app.post('/convertToPdf', async (req, res, next) => {
    try {
        const dt = typeof req.body === 'string'
            ? req.body.trim()
            : ((req.body && req.body.dt) ? String(req.body.dt).trim() : '')
        const pdfBuffer = await generatePdfReport(dt)
        res.setHeader('Content-Type', 'application/pdf')
        res.status(200).send(pdfBuffer)
    } catch (err) {
        console.error('PDF generation failed:', err.message)
        next(createHttpError(500, err.message))
    }
})

app.post('/updateData', (req, res, next) => {
    try {
        // Normalize incoming values and reject incomplete updates early.
        const dataToUpdate = (req.body && typeof req.body === 'object') ? req.body : {}
        const plantName = String(dataToUpdate.plant || '').trim()
        const priceValue = String(dataToUpdate.price || '').trim()
        const dateValue = String(dataToUpdate.date || '').trim()

        if (!plantName || !priceValue || !dateValue) {
            res.status(400).send('Missing required fields: plant, price, date')
            return
        }

        const databasePath = path.resolve('data', 'database.xml')
        const databaseXml = fs.readFileSync(databasePath, 'utf-8')
        const xmlDocDatabase = libxmljs.parseXml(databaseXml)

        const plants = xmlDocDatabase.find('//plant')
        // Match by plant name instead of building XPath with raw user input.
        const selectedPlant = plants.find((plantNode) => {
            const nameNode = plantNode.get('./name')
            return nameNode && nameNode.text().trim() === plantName
        })

        if (!selectedPlant) {
            res.status(404).send(`Unknown plant: ${plantName}`)
            return
        }

        const plantStatistics = selectedPlant.get('./statistics')
        if (!plantStatistics) {
            return next(createHttpError(500, `Plant has no statistics node: ${plantName}`))
        }

        plantStatistics.node('price', priceValue).attr('date', dateValue)

        const valid = validateDatabase(xmlDocDatabase)
        if (!valid) {
            // Keep invalid XML out of the persisted data file.
            res.status(400).send('Invalid XML')
            return
        }

        fs.writeFileSync(databasePath, xmlDocDatabase.toString(), 'utf-8')
        res.sendStatus(200)
    } catch (err) {
        next(err)
    }
})

app.get('/feedback', (req, res, next) => {
    const saxonJar = path.resolve('tools', 'saxon-he.jar')
    const xmlPath = path.resolve('data', 'feedback.xml')
    const xslPath = path.resolve('xslt', 'views', 'feedback.xsl')

    const success = req.query.success || 'false'
    const error = req.query.error || 'false' 

    const args = [
        '-jar', saxonJar,
        `-s:${xmlPath}`,
        `-xsl:${xslPath}`,
        `success=${success}`,
        `error=${error}`
    ]

    execFile('java', args, { maxBuffer: 50 * 1024 * 1024 }, (err, stdout, stderr) => {
        if (err) {
            console.error("Java Saxon Error:", stderr)
            next(createHttpError(500, "Transformation Error: " + (stderr || err.message)))
            return;
        }
        // Send the output as XHTML/HTML
        res.status(200).type('text/html').send(stdout)
    })
})

app.post('/submit-feedback', (req, res) => {
    const { username, rating, comment } = req.body
    const xmlPath = path.resolve('data', 'feedback.xml')

    // Keep your original sanitization but trim for XSD compatibility
    const cleanUser = (username || 'Anonymous').trim() 
    const cleanComment = (comment || '').trim().replace(/</g, "&lt;").replace(/>/g, "&gt;")
    const cleanRating = (rating || '5').trim()

    const newEntrySnippet = `
    <feedback>
        <user>${cleanUser}</user>
        <rating>${cleanRating}</rating>
        <comment>${cleanComment}</comment>
        <date>${new Date().toISOString()}</date>
    </feedback>
</feedbacks>`;

    fs.readFile(xmlPath, 'utf8', (err, data) => {
        if (err) return res.redirect('/feedback?error=true')
        
        const updatedXmlString = data.replace('</feedbacks>', newEntrySnippet);
        
        try {
            const xmlDoc = libxmljs.parseXml(updatedXmlString)

            if (validateFeedbackForm(xmlDoc)) {
                fs.writeFileSync(xmlPath, updatedXmlString, 'utf8')
                res.redirect('/feedback?success=true')
            } else {
                res.redirect('/feedback?error=true')
            }
        } catch (e) {
            console.error("XML Syntax Error:", e.message)
            res.redirect('/feedback?error=true')
        }
    })
})

function validate(xmlDoc, xmlSchema) {
    const xmlDocDatabaseXsd = libxmljs.parseXml(xmlSchema)
    return xmlDoc.validate(xmlDocDatabaseXsd)
}

function validatePrices(xmlDoc) {
    const pricesSchema = fs.readFileSync(path.resolve('schema', 'prices.xsd'), 'utf-8')
    return validate(xmlDoc, pricesSchema)
}

function validateDatabase(xmlDoc) {
    const databaseSchema = fs.readFileSync(path.resolve('schema', 'database.xsd'), 'utf-8')
    return validate(xmlDoc, databaseSchema)
}

function validateUV(xmlDoc) {
    const uvSchema = fs.readFileSync(path.resolve('schema', 'sunshine.xsd'), 'utf-8')
    return validate(xmlDoc, uvSchema)
}

function validateRecommendation(xmlDoc) {
    const recommendationSchema = fs.readFileSync(path.resolve('schema', 'recommendation.xsd'), 'utf-8')
    return validate(xmlDoc, recommendationSchema)
}

function validateFeedbackForm(xmlDoc) {
    try {
        const schemaPath = path.resolve('schema', 'feedback.xsd')
        const schemaXml = fs.readFileSync(schemaPath, 'utf-8')
        const schemaDoc = libxmljs.parseXml(schemaXml)
        
        const isValid = xmlDoc.validate(schemaDoc)
        if (!isValid) {
            console.error("Validation Errors:", xmlDoc.validationErrors.map(e => e.message))
        }
        return isValid
    } catch (err) {
        console.error("Schema or Parsing Error:", err.message)
        return false
    }
}

app.use(async (err, req, res, next) => {
    // Centralized fallback for unexpected server errors.
    if (res.headersSent) {
        next(err)
        return
    }

    const statusCode = Number(err.status || 500)
    const normalizedStatus = statusCode >= 400 ? statusCode : 500
    const title = normalizedStatus === 404 ? 'Not Found' : 'Internal Server Error'
    const message = err && err.message ? err.message : 'Unexpected error'

    console.error('Serverfehler:', err && err.stack ? err.stack : err)

    try {
        const html = await renderErrorView(normalizedStatus, title, message, req.originalUrl || req.path || '/')
        res.status(normalizedStatus).type('text/html').send(html)
    } catch (renderErr) {
        console.error('Error view rendering failed:', renderErr.message)
        res.status(500).type('text/plain').send('Internal Server Error')
    }
})

app.listen(3000, () => {
    console.log('listen on port', 3000)
    console.log('pdf renderer:', PDF_RENDERER === 'remote' ? `remote (${FOP_REMOTE_URL})` : 'local')
})
