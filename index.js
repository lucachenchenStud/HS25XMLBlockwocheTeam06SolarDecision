const express = require('express')
const path = require('path')
const fs = require('fs')
const libxmljs = require('libxmljs2')
const app = express()
const { execFile } = require('child_process')


const schemaCache = new Map();

app.use(express.static(__dirname));
app.use(express.text());
app.use(express.urlencoded({ extended: false }));

app.get('/', (req, res) => {
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
            res.status(500).type('text/plain').send(stderr || err.message)
            return
        }
        res.status(200).type('application/xhtml+xml').send(stdout)
    })
})


app.post('/convertToPdf', async (req, res) => {
    const response = await fetch('https://fop.xml.hslu-edu.ch/fop.php', {
        method: "POST",
        mode: "cors",
        cache: "no-cache",
        credentials: "same-origin",
        body: req.body,
    });
    const responseText = await (await response.blob()).arrayBuffer()
    const buffer = Buffer.from(responseText)
    fs.writeFileSync(path.resolve('temp.pdf'), buffer)
    res.sendFile(path.resolve('temp.pdf'))
})

app.post('/updateData', (req, res) => {
    const dataToUpdate = req.body
    // read database xml
    const databasePath = path.resolve('data', 'database.xml');
    const databaseXml = fs.readFileSync(databasePath, 'utf-8')
    const xmlDocDatabase = libxmljs.parseXml(databaseXml)
    // select node to update
    const plantStatistics = xmlDocDatabase.get(`//plant[name="${dataToUpdate.plant}"]/statistics`);

    // create new node with attribute etc.
    plantStatistics.node('price', dataToUpdate.price).attr('date', dataToUpdate.date)

    console.log(xmlDocDatabase.toString())

    // validate new database against schema
    const valid = validateDatabase(xmlDocDatabase)
    if (!valid) {
        res.status(400).send('Invalid XML')
        return
    }

    // write new database.xml
    fs.writeFileSync(databasePath, xmlDocDatabase.toString(), 'utf-8')

    res.sendStatus(200)
})

function validate(xmlDoc, xmlSchema) {
    const xmlDocDatabaseXsd = libxmljs.parseXml(xmlSchema)
    return xmlDoc.validate(xmlDocDatabaseXsd)
}

function validatePrices(xmlDoc) {
    const pricesSchema = fs.readFileSync(path.resolve('schema', 'prices.xsd'), 'utf-8')
    return validate(xmlDoc, pricesSchema)
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
    //TODO Validate FeedbackForm using this function
}

app.listen(3000, () => {
    console.log('listen on port', 3000)
})
