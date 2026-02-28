<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:fo="http://www.w3.org/1999/XSL/Format"
                xmlns:f="urn:report"
                exclude-result-prefixes="xs f">

    <xsl:output method="xml" indent="yes" encoding="UTF-8"/>
    <xsl:param name="dt" as="xs:string" select="''"/>

    <xsl:function name="f:to-chf" as="xs:decimal">
        <xsl:param name="rp" as="xs:decimal"/>
        <xsl:sequence select="$rp div 100"/>
    </xsl:function>

    <xsl:template match="/clusters">
        <xsl:variable name="all" select="sample"/>
        <xsl:variable name="dtNorm"
                      select="if (normalize-space($dt) = '') then '' else concat(normalize-space($dt), ':00')"/>
        <xsl:variable name="picked"
                      select="if ($dtNorm = '') then () else $all[xs:dateTime(@datetime) le xs:dateTime($dtNorm)][last()]"/>
        <xsl:variable name="cur" select="if (exists($picked)) then $picked else $all[last()]"/>
        <xsl:variable name="curPriceChf" select="f:to-chf(xs:decimal($cur/price))"/>
        <xsl:variable name="curSun" select="xs:decimal($cur/sunshine)"/>
        <xsl:variable name="generatedAt" select="current-dateTime()"/>

        <xsl:variable name="n" select="count($all)"/>
        <xsl:variable name="last24" select="$all[position() gt ($n - 24)]"/>

        <fo:root>
            <fo:layout-master-set>
                <fo:simple-page-master master-name="a4"
                                       page-height="29.7cm"
                                       page-width="21cm"
                                       margin-top="1.2cm"
                                       margin-bottom="1.2cm"
                                       margin-left="1.6cm"
                                       margin-right="1.6cm">
                    <fo:region-body margin-top="1.0cm" margin-bottom="1.0cm"/>
                    <fo:region-before extent="1.0cm"/>
                    <fo:region-after extent="0.9cm"/>
                </fo:simple-page-master>
            </fo:layout-master-set>

            <fo:page-sequence master-reference="a4">
                <fo:static-content flow-name="xsl-region-before">
                    <fo:block font-family="Helvetica" font-size="9pt" color="#667085">SolarDecision Hub</fo:block>
                </fo:static-content>

                <fo:static-content flow-name="xsl-region-after">
                    <fo:block font-family="Helvetica" font-size="9pt" color="#667085" text-align="end">
                        Seite <fo:page-number/>
                    </fo:block>
                </fo:static-content>

                <fo:flow flow-name="xsl-region-body">
                    <fo:block font-family="Helvetica" font-size="20pt" font-weight="bold" color="#101828" space-after="6pt">
                        SolarDecision Report
                    </fo:block>

                    <fo:block font-family="Helvetica" font-size="10pt" color="#667085" space-after="14pt">
                        Erzeugt am <xsl:value-of select="format-dateTime($generatedAt, '[D01].[M01].[Y0001] [H01]:[m01]:[s01]')"/>
                    </fo:block>

                    <fo:block font-family="Helvetica" font-size="13pt" font-weight="bold" color="#101828" space-after="8pt">
                        Aktuelle Empfehlung
                    </fo:block>

                    <fo:table table-layout="fixed" width="100%" border-collapse="separate" border-separation="0pt">
                        <fo:table-column column-width="36%"/>
                        <fo:table-column column-width="64%"/>
                        <fo:table-body>
                            <fo:table-row>
                                <fo:table-cell padding="6pt" background-color="#f2f4f7" border="0.5pt solid #d0d5dd">
                                    <fo:block font-family="Helvetica" font-size="10pt" font-weight="bold">Zeitpunkt</fo:block>
                                </fo:table-cell>
                                <fo:table-cell padding="6pt" border="0.5pt solid #d0d5dd">
                                    <fo:block font-family="Helvetica" font-size="10pt">
                                        <xsl:value-of select="$cur/@datetime"/>
                                    </fo:block>
                                </fo:table-cell>
                            </fo:table-row>

                            <fo:table-row>
                                <fo:table-cell padding="6pt" background-color="#f2f4f7" border="0.5pt solid #d0d5dd">
                                    <fo:block font-family="Helvetica" font-size="10pt" font-weight="bold">Empfehlung</fo:block>
                                </fo:table-cell>
                                <fo:table-cell padding="6pt" border="0.5pt solid #d0d5dd">
                                    <fo:block font-family="Helvetica" font-size="10pt">
                                        <xsl:choose>
                                            <xsl:when test="$cur/@recommendation = 'SELL'">Verkaufen</xsl:when>
                                            <xsl:when test="$cur/@recommendation = 'BUY'">Kaufen</xsl:when>
                                            <xsl:otherwise>Nicht verkaufen</xsl:otherwise>
                                        </xsl:choose>
                                        <xsl:text> (</xsl:text>
                                        <xsl:value-of select="$cur/@recommendation"/>
                                        <xsl:text>)</xsl:text>
                                    </fo:block>
                                </fo:table-cell>
                            </fo:table-row>

                            <fo:table-row>
                                <fo:table-cell padding="6pt" background-color="#f2f4f7" border="0.5pt solid #d0d5dd">
                                    <fo:block font-family="Helvetica" font-size="10pt" font-weight="bold">Strompreis</fo:block>
                                </fo:table-cell>
                                <fo:table-cell padding="6pt" border="0.5pt solid #d0d5dd">
                                    <fo:block font-family="Helvetica" font-size="10pt">
                                        <xsl:value-of select="format-number($curPriceChf, '0.00')"/> CHF/kWh
                                    </fo:block>
                                </fo:table-cell>
                            </fo:table-row>

                            <fo:table-row>
                                <fo:table-cell padding="6pt" background-color="#f2f4f7" border="0.5pt solid #d0d5dd">
                                    <fo:block font-family="Helvetica" font-size="10pt" font-weight="bold">Sonneneinstrahlung</fo:block>
                                </fo:table-cell>
                                <fo:table-cell padding="6pt" border="0.5pt solid #d0d5dd">
                                    <fo:block font-family="Helvetica" font-size="10pt">
                                        <xsl:value-of select="format-number($curSun, '0')"/> W/m2
                                    </fo:block>
                                </fo:table-cell>
                            </fo:table-row>

                            <fo:table-row>
                                <fo:table-cell padding="6pt" background-color="#f2f4f7" border="0.5pt solid #d0d5dd">
                                    <fo:block font-family="Helvetica" font-size="10pt" font-weight="bold">Cluster</fo:block>
                                </fo:table-cell>
                                <fo:table-cell padding="6pt" border="0.5pt solid #d0d5dd">
                                    <fo:block font-family="Helvetica" font-size="10pt">
                                        <xsl:value-of select="$cur/@cluster"/>
                                    </fo:block>
                                </fo:table-cell>
                            </fo:table-row>
                        </fo:table-body>
                    </fo:table>

                    <fo:block font-family="Helvetica" font-size="13pt" font-weight="bold" color="#101828" space-before="16pt" space-after="8pt">
                        Verteilung letzte 24 Stunden
                    </fo:block>

                    <fo:table table-layout="fixed" width="100%">
                        <fo:table-column column-width="33.33%"/>
                        <fo:table-column column-width="33.33%"/>
                        <fo:table-column column-width="33.33%"/>
                        <fo:table-header>
                            <fo:table-row background-color="#f2f4f7">
                                <fo:table-cell border="0.5pt solid #d0d5dd" padding="6pt">
                                    <fo:block font-family="Helvetica" font-size="10pt" font-weight="bold">SELL</fo:block>
                                </fo:table-cell>
                                <fo:table-cell border="0.5pt solid #d0d5dd" padding="6pt">
                                    <fo:block font-family="Helvetica" font-size="10pt" font-weight="bold">HOLD</fo:block>
                                </fo:table-cell>
                                <fo:table-cell border="0.5pt solid #d0d5dd" padding="6pt">
                                    <fo:block font-family="Helvetica" font-size="10pt" font-weight="bold">BUY</fo:block>
                                </fo:table-cell>
                            </fo:table-row>
                        </fo:table-header>
                        <fo:table-body>
                            <fo:table-row>
                                <fo:table-cell border="0.5pt solid #d0d5dd" padding="8pt">
                                    <fo:block font-family="Helvetica" font-size="11pt">
                                        <xsl:value-of select="count($last24[@recommendation='SELL'])"/>
                                    </fo:block>
                                </fo:table-cell>
                                <fo:table-cell border="0.5pt solid #d0d5dd" padding="8pt">
                                    <fo:block font-family="Helvetica" font-size="11pt">
                                        <xsl:value-of select="count($last24[@recommendation='HOLD'])"/>
                                    </fo:block>
                                </fo:table-cell>
                                <fo:table-cell border="0.5pt solid #d0d5dd" padding="8pt">
                                    <fo:block font-family="Helvetica" font-size="11pt">
                                        <xsl:value-of select="count($last24[@recommendation='BUY'])"/>
                                    </fo:block>
                                </fo:table-cell>
                            </fo:table-row>
                        </fo:table-body>
                    </fo:table>
                </fo:flow>
            </fo:page-sequence>
        </fo:root>
    </xsl:template>
</xsl:stylesheet>
