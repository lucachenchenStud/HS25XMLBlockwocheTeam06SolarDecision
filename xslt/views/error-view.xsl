<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                exclude-result-prefixes="xs">

    <xsl:output method="xml" indent="yes" encoding="UTF-8"
                doctype-public="-//W3C//DTD XHTML 1.0 Strict//EN"
                doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"/>

    <xsl:param name="statusCode" as="xs:string" select="'500'"/>
    <xsl:param name="title" as="xs:string" select="'Internal Server Error'"/>
    <xsl:param name="message" as="xs:string" select="'Unexpected error'"/>
    <xsl:param name="requestPath" as="xs:string" select="'/'"/>

    <xsl:template match="/error">
        <html xmlns="http://www.w3.org/1999/xhtml">
            <head>
                <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
                <title><xsl:value-of select="$statusCode"/> - <xsl:value-of select="$title"/></title>
                <style type="text/css">
                    body { font-family: Helvetica, Arial, sans-serif; margin: 0; background: #f2f4f7; color: #101828; }
                    .wrap { max-width: 760px; margin: 48px auto; padding: 0 20px; }
                    .card { background: #ffffff; border: 1px solid #d0d5dd; border-radius: 10px; padding: 24px; }
                    .code { font-size: 46px; line-height: 1; font-weight: 700; color: #b42318; margin: 0 0 10px 0; }
                    .title { font-size: 24px; margin: 0 0 14px 0; }
                    .msg { margin: 0 0 12px 0; color: #344054; }
                    .meta { margin: 0; color: #667085; font-size: 14px; }
                    .btn { display: inline-block; margin-top: 18px; background: #111827; color: #ffffff; text-decoration: none; padding: 10px 14px; border-radius: 8px; }
                </style>
            </head>
            <body>
                <div class="wrap">
                    <div class="card">
                        <p class="code"><xsl:value-of select="$statusCode"/></p>
                        <h1 class="title"><xsl:value-of select="$title"/></h1>
                        <p class="msg"><xsl:value-of select="$message"/></p>
                        <p class="meta">Pfad: <xsl:value-of select="$requestPath"/></p>
                        <a class="btn" href="/">Zur Startseite</a>
                    </div>
                </div>
            </body>
        </html>
    </xsl:template>
</xsl:stylesheet>
