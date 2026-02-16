<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:f="urn:dash"
                exclude-result-prefixes="xs f">

    <xsl:output method="xml" indent="yes" encoding="UTF-8"
                doctype-public="-//W3C//DTD XHTML 1.0 Strict//EN"
                doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"/>

    <!-- Date time selected by user -->
    <xsl:param name="dt" as="xs:string" select="''"/>

    <!-- ========= Helpers ========= -->

    <xsl:function name="f:to-chf" as="xs:decimal">
        <xsl:param name="rp" as="xs:decimal"/>
        <xsl:sequence select="$rp div 100"/>
    </xsl:function>

    <xsl:function name="f:clamp" as="xs:decimal">
        <xsl:param name="v" as="xs:decimal"/>
        <xsl:param name="lo" as="xs:decimal"/>
        <xsl:param name="hi" as="xs:decimal"/>
        <xsl:sequence select="if ($v lt $lo) then $lo else if ($v gt $hi) then $hi else $v"/>
    </xsl:function>

    <!-- Map value to y pixel (0..h), with padding -->
    <xsl:function name="f:y" as="xs:decimal">
        <xsl:param name="v" as="xs:decimal"/>
        <xsl:param name="minv" as="xs:decimal"/>
        <xsl:param name="maxv" as="xs:decimal"/>
        <xsl:param name="h" as="xs:decimal"/>
        <xsl:variable name="range" select="if ($maxv = $minv) then 1 else ($maxv - $minv)"/>
        <xsl:sequence select="$h - ((($v - $minv) div $range) * $h)"/>
    </xsl:function>

    <xsl:template match="/clusters">
        <xsl:variable name="all" select="sample"/>
        <xsl:variable name="n" select="count($all)"/>
        <xsl:variable name="last30" select="$all[position() gt ($n - 720)]"/>

        <xsl:variable name="dtNorm"
                      select="if (normalize-space($dt) = '') then ''
          else concat(normalize-space($dt), ':00')"/>

        <xsl:variable name="picked"
                      select="if ($dtNorm = '') then ()
          else $all[xs:dateTime(@datetime) le xs:dateTime($dtNorm)][last()]"/>

        <xsl:variable name="cur" select="if (exists($picked)) then $picked else $all[last()]"/>

        <xsl:variable name="curPriceRp" select="xs:decimal($cur/price)"/>
        <xsl:variable name="curPriceChf" select="f:to-chf($curPriceRp)"/>
        <xsl:variable name="curSun" select="xs:decimal($cur/sunshine)"/>

        <xsl:variable name="priceSeries" select="for $s in $last30 return f:to-chf(xs:decimal($s/price))"/>
        <xsl:variable name="sunSeries" select="for $s in $last30 return xs:decimal($s/sunshine)"/>

        <xsl:variable name="minPrice" select="min($priceSeries)"/>
        <xsl:variable name="maxPrice" select="max($priceSeries)"/>
        <xsl:variable name="minSun" select="min($sunSeries)"/>
        <xsl:variable name="maxSun" select="max($sunSeries)"/>

        <!-- Thresholds -->
        <xsl:variable name="p33" select="f:to-chf(xs:decimal(thresholds/price/@q33))"/>
        <xsl:variable name="p66" select="f:to-chf(xs:decimal(thresholds/price/@q66))"/>
        <xsl:variable name="s33" select="xs:decimal(thresholds/sunshine/@q33)"/>
        <xsl:variable name="s66" select="xs:decimal(thresholds/sunshine/@q66)"/>

        <!-- Recommendation styling -->
        <xsl:variable name="rec" select="string($cur/@recommendation)"/>
        <xsl:variable name="recTitle"
                      select="if ($rec = 'SELL') then 'Verkaufen'
                              else if ($rec = 'BUY') then 'Kaufen'
                              else 'Nicht verkaufen'"/>
        <xsl:variable name="recColor"
                      select="if ($rec = 'SELL') then 'good'
                              else if ($rec = 'BUY') then 'info'
                              else 'bad'"/>
        <xsl:variable name="confidence"
                      select="if ($rec = 'SELL') then '85% Sicherheit'
                              else if ($rec = 'BUY') then '80% Sicherheit'
                              else '85% Sicherheit'"/>

        <xsl:variable name="recText">
            <xsl:choose>
                <xsl:when test="$rec = 'SELL'">
                    <xsl:text>Der Strompreis ist im oberen Bereich und die erwartete Eigennutzung ist eher tief. Ein Verkauf ins Netz ist aktuell vorteilhaft.</xsl:text>
                </xsl:when>
                <xsl:when test="$rec = 'BUY'">
                    <xsl:text>Der Strompreis ist im unteren Bereich. Falls möglich lohnt sich ein Bezug aus dem Netz statt Eigenverbrauch zu priorisieren.</xsl:text>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:text>Die Sonneneinstrahlung ist hoch, was eine gute Eigenproduktion durch Solaranlagen ermöglicht. Es lohnt sich den selbst produzierten Strom zu nutzen statt ihn zu verkaufen.</xsl:text>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>

        <html xmlns="http://www.w3.org/1999/xhtml">
            <head>
                <title>Energie Dashboard</title>
                <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>

                <style type="text/css">
                    :root{
                        --bg:#f6f7fb;
                        --card:#ffffff;
                        --text:#101828;
                        --muted:#667085;
                        --border:#eaecf0;
                        --good:#12b76a;
                        --bad:#f04438;
                        --info:#2563eb;
                        --warn:#f59e0b;
                    }
                    body{
                        margin:0;
                        font-family: system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial, sans-serif;
                        background:var(--bg);
                        color:var(--text);
                    }
                    .page{ padding:22px 22px 28px 22px; }
                    .topbar{
                        display:flex;
                        align-items:flex-start;
                        justify-content:space-between;
                        margin-bottom:16px;
                        gap:16px;
                    }
                    .title{ font-size:26px; font-weight:800; }
                    .subtitle{ color:var(--muted); margin-top:2px; font-size:13px; }

                    .actions{ display:flex; gap:10px; align-items:center; flex-wrap:wrap; }
                    .btn{
                        background:var(--card);
                        border:1px solid var(--border);
                        border-radius:10px;
                        padding:10px 14px;
                        font-weight:600;
                        font-size:13px;
                        cursor:pointer;
                    }
                    .btn.primary{
                        background:#111827;
                        color:white;
                        border-color:#111827;
                    }
                    .dt-label{
                        font-weight:700;
                        font-size:13px;
                        color:var(--muted);
                    }
                    .dt-input{
                        border:1px solid var(--border);
                        border-radius:10px;
                        padding:10px 12px;
                        font-weight:600;
                        font-size:13px;
                        background:var(--card);
                    }
                    .dt-hint{
                        color:var(--muted);
                        font-size:12px;
                        margin-top:6px;
                    }

                    .grid-top{
                        display:grid;
                        grid-template-columns: 2fr 1fr;
                        gap:16px;
                        margin-bottom:16px;
                    }
                    .grid-bottom{
                        display:grid;
                        grid-template-columns: 1fr 1fr;
                        gap:16px;
                    }
                    .card{
                        background:var(--card);
                        border:1px solid var(--border);
                        border-radius:14px;
                        padding:18px;
                        box-shadow: 0 1px 2px rgba(16,24,40,0.06);
                    }
                    .card-header{
                        display:flex;
                        justify-content:space-between;
                        align-items:center;
                        margin-bottom:10px;
                    }
                    .card-title{ font-weight:800; }
                    .card-sub{ color:var(--muted); font-size:13px; margin-top:2px; }
                    .badge{
                        font-size:12px;
                        font-weight:800;
                        padding:6px 10px;
                        border-radius:999px;
                        color:white;
                    }
                    .badge.good{ background:var(--good); }
                    .badge.bad{ background:var(--bad); }
                    .badge.info{ background:var(--info); }

                    .recommend{
                        border-width:2px;
                    }
                    .recommend.good{ border-color: rgba(18,183,106,0.5); }
                    .recommend.bad{ border-color: rgba(240,68,56,0.5); }
                    .recommend.info{ border-color: rgba(37,99,235,0.5); }

                    .rec-line{
                        display:flex;
                        gap:10px;
                        color:var(--muted);
                        line-height:1.35;
                        font-size:13px;
                        padding:10px 0 14px 0;
                        border-bottom:1px solid var(--border);
                        margin-bottom:14px;
                    }
                    .dot{
                        width:10px; height:10px; border-radius:999px; margin-top:4px;
                    }
                    .dot.good{ background:var(--good); }
                    .dot.bad{ background:var(--bad); }
                    .dot.info{ background:var(--info); }

                    .kpis{
                        display:grid;
                        grid-template-columns: 1fr 1fr;
                        gap:14px;
                    }
                    .kpi .label{ color:var(--muted); font-size:12px; margin-bottom:4px; }
                    .kpi .value{ font-size:22px; font-weight:900; }

                    .chart-wrap{
                        margin-top:10px;
                    }
                    .mini-kpis{
                        display:grid;
                        grid-template-columns: 1fr 1fr;
                        gap:12px;
                        margin-top:12px;
                    }
                    .mini{
                        border-radius:12px;
                        padding:12px 14px;
                        border:1px solid var(--border);
                    }
                    .mini.blue{ background:#f0f6ff; }
                    .mini.yellow{ background:#fff7e6; }
                    .mini .mini-label{ color:var(--muted); font-size:12px; margin-bottom:4px; }
                    .mini .mini-value{ font-weight:900; font-size:18px; }

                    .gauge-center{
                        display:flex;
                        align-items:center;
                        justify-content:center;
                        padding-top:10px;
                    }

                    svg{ display:block; width:100%; height:auto; }
                    .axis-text{ fill: #98a2b3; font-size:11px; }
                    .grid-line{ stroke:#eaecf0; stroke-width:1; }
                    .line-blue{ fill:none; stroke:#2563eb; stroke-width:2.5; }
                    .line-orange{ fill:none; stroke:#f59e0b; stroke-width:2.5; }
                    .needle{ stroke:#111827; stroke-width:6; stroke-linecap:round; }
                    .needle-dot{ fill:#111827; }
                </style>
            </head>

            <body>
                <div class="page">

                    <div class="topbar">
                        <div>
                            <div class="title">Energie Dashboard</div>
                            <div class="subtitle">
                                Historische Daten der letzten 30 Tage
                                <xsl:text> </xsl:text>
                                <xsl:text> </xsl:text>
                                <xsl:text>Empfehlung für </xsl:text>
                                <xsl:value-of select="$cur/@datetime"/>
                                <xsl:if test="normalize-space($dt) != '' and exists($picked)">
                                    <xsl:text> </xsl:text>
                                    <xsl:text>basierend auf Auswahl </xsl:text>
                                    <xsl:value-of select="$dtNorm"/>
                                </xsl:if>
                            </div>
                        </div>

                        <div class="actions">
                            <!-- Date time picker -->
                            <form method="get" action="/" style="display:flex; gap:10px; align-items:center; margin:0;">
                                <label for="dt" class="dt-label">Zeitpunkt</label>
                                <input id="dt" name="dt" type="datetime-local" class="dt-input"
                                       value="{if ($dtNorm != '') then substring($dtNorm, 1, 16) else ''}"/>
                                <button class="btn primary" type="submit">Empfehlung anzeigen</button>
                            </form>
                            
                            <a href="/feedback"><div class="btn primary">Feedback</div></a>
                            <div class="btn primary">PDF Export</div>
                        </div>
                    </div>

                    <div class="grid-top">

                        <!-- Recommendation -->
                        <div class="card recommend {$recColor}">
                            <div class="card-header">
                                <div>
                                    <div class="card-title">
                                        <xsl:value-of select="$recTitle"/>
                                    </div>
                                    <div class="card-sub">Basierend auf aktuellen Marktdaten</div>
                                </div>
                                <div class="badge {$recColor}">
                                    <xsl:value-of select="$confidence"/>
                                </div>
                            </div>

                            <div class="rec-line">
                                <div class="dot {$recColor}"></div>
                                <div>
                                    <xsl:value-of select="normalize-space($recText)"/>
                                </div>
                            </div>

                            <div class="kpis">
                                <div class="kpi">
                                    <div class="label">Ø Strompreis</div>
                                    <div class="value">
                                        <xsl:value-of select="format-number($curPriceChf, '0.00')"/>
                                        <xsl:text> CHF/kWh</xsl:text>
                                    </div>
                                </div>
                                <div class="kpi">
                                    <div class="label">Ø Sonneneinstrahlung</div>
                                    <div class="value">
                                        <xsl:value-of select="format-number($curSun, '0')"/>
                                        <xsl:text> W/m²</xsl:text>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- Gauge -->
                        <div class="card">
                            <div class="card-title">Aktueller Strompreis</div>
                            <div class="card-sub">Echtzeit Marktpreis</div>

                            <div class="gauge-center">
                                <xsl:call-template name="gauge">
                                    <xsl:with-param name="value" select="$curPriceChf"/>
                                    <xsl:with-param name="minv" select="$minPrice"/>
                                    <xsl:with-param name="maxv" select="$maxPrice"/>
                                    <xsl:with-param name="p33" select="$p33"/>
                                    <xsl:with-param name="p66" select="$p66"/>
                                </xsl:call-template>
                            </div>
                        </div>

                    </div>

                    <div class="grid-bottom">

                        <!-- Price chart -->
                        <div class="card">
                            <div class="card-title">Strompreise</div>
                            <div class="card-sub">Historische Entwicklung der Strompreise (CHF pro kWh)</div>

                            <div class="chart-wrap">
                                <xsl:call-template name="line-chart">
                                    <xsl:with-param name="values" select="$priceSeries"/>
                                    <xsl:with-param name="minv" select="$minPrice"/>
                                    <xsl:with-param name="maxv" select="$maxPrice"/>
                                    <xsl:with-param name="strokeClass" select="'line-blue'"/>
                                </xsl:call-template>
                            </div>

                            <div class="mini-kpis">
                                <div class="mini blue">
                                    <div class="mini-label">Max. Strompreis</div>
                                    <div class="mini-value">
                                        <xsl:value-of select="format-number($maxPrice, '0.000')"/>
                                        <xsl:text> CHF/kWh</xsl:text>
                                    </div>
                                </div>
                                <div class="mini blue">
                                    <div class="mini-label">Min. Strompreis</div>
                                    <div class="mini-value">
                                        <xsl:value-of select="format-number($minPrice, '0.000')"/>
                                        <xsl:text> CHF/kWh</xsl:text>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- Sunshine chart -->
                        <div class="card">
                            <div class="card-title">Sonneneinstrahlung</div>
                            <div class="card-sub">Historische Sonneneinstrahlung (W pro m²)</div>

                            <div class="chart-wrap">
                                <xsl:call-template name="line-chart">
                                    <xsl:with-param name="values" select="$sunSeries"/>
                                    <xsl:with-param name="minv" select="$minSun"/>
                                    <xsl:with-param name="maxv" select="$maxSun"/>
                                    <xsl:with-param name="strokeClass" select="'line-orange'"/>
                                </xsl:call-template>
                            </div>

                            <div class="mini-kpis">
                                <div class="mini yellow">
                                    <div class="mini-label">Max. Sonneneinstrahlung</div>
                                    <div class="mini-value">
                                        <xsl:value-of select="format-number($maxSun, '0')"/>
                                        <xsl:text> W/m²</xsl:text>
                                    </div>
                                </div>
                                <div class="mini yellow">
                                    <div class="mini-label">Min. Sonneneinstrahlung</div>
                                    <div class="mini-value">
                                        <xsl:value-of select="format-number($minSun, '0')"/>
                                        <xsl:text> W/m²</xsl:text>
                                    </div>
                                </div>
                            </div>
                        </div>

                    </div>

                </div>
            </body>
        </html>
    </xsl:template>

    <!-- ========= SVG Line Chart Template ========= -->
    <xsl:template name="line-chart">
        <xsl:param name="values" as="item()*"/>
        <xsl:param name="minv" as="xs:decimal"/>
        <xsl:param name="maxv" as="xs:decimal"/>
        <xsl:param name="strokeClass" as="xs:string"/>

        <xsl:variable name="w" select="720"/>
        <xsl:variable name="h" select="220"/>
        <xsl:variable name="padL" select="44"/>
        <xsl:variable name="padR" select="12"/>
        <xsl:variable name="padT" select="14"/>
        <xsl:variable name="padB" select="26"/>
        <xsl:variable name="plotW" select="$w - $padL - $padR"/>
        <xsl:variable name="plotH" select="$h - $padT - $padB"/>
        <xsl:variable name="cnt" select="count($values)"/>
        <xsl:variable name="dx" select="if ($cnt le 1) then 0 else ($plotW div ($cnt - 1))"/>

        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {$w} {$h}" role="img" aria-label="Line chart">
            <xsl:for-each select="0 to 4">
                <xsl:variable name="gy" select="$padT + (position()-1) * ($plotH div 4)"/>
                <line class="grid-line" x1="{$padL}" y1="{$gy}" x2="{$w - $padR}" y2="{$gy}"/>
            </xsl:for-each>

            <text class="axis-text" x="6" y="{$padT + 10}">
                <xsl:value-of select="format-number($maxv, '0.###')"/>
            </text>
            <text class="axis-text" x="6" y="{$padT + $plotH + 2}">
                <xsl:value-of select="format-number($minv, '0.###')"/>
            </text>

            <xsl:variable name="pts">
                <xsl:for-each select="$values">
                    <xsl:variable name="i" select="position() - 1"/>
                    <xsl:variable name="x" select="$padL + ($i * $dx)"/>
                    <xsl:variable name="y" select="$padT + f:y(xs:decimal(.), $minv, $maxv, $plotH)"/>
                    <xsl:value-of select="format-number($x,'0.##')"/>
                    <xsl:text>,</xsl:text>
                    <xsl:value-of select="format-number($y,'0.##')"/>
                    <xsl:if test="position() != last()">
                        <xsl:text> </xsl:text>
                    </xsl:if>
                </xsl:for-each>
            </xsl:variable>

            <polyline class="{$strokeClass}" points="{normalize-space($pts)}"/>
            <line class="grid-line" x1="{$padL}" y1="{$padT + $plotH}" x2="{$w - $padR}" y2="{$padT + $plotH}"/>
        </svg>
    </xsl:template>

    <!-- ========= SVG Gauge Template ========= -->
    <xsl:template name="gauge">
        <xsl:param name="value" as="xs:decimal"/>
        <xsl:param name="minv" as="xs:decimal"/>
        <xsl:param name="maxv" as="xs:decimal"/>
        <xsl:param name="p33" as="xs:decimal"/>
        <xsl:param name="p66" as="xs:decimal"/>
        
        <xsl:variable name="w" select="380"/>
        <xsl:variable name="h" select="240"/>
        <xsl:variable name="cx" select="$w div 2"/>
        <xsl:variable name="cy" select="180"/>
        <xsl:variable name="r" select="130"/>
        <xsl:variable name="pi_r" select="3.14159 * $r"/>
        
        <xsl:variable name="v" select="if ($value &lt; $minv) then $minv else if ($value &gt; $maxv) then $maxv else $value"/>
        <xsl:variable name="t" select="if ($maxv = $minv) then 0.5 else (($v - $minv) div ($maxv - $minv))"/>
        <xsl:variable name="angle" select="180 * $t"/> 
        
        <xsl:variable name="f25" select="0.25"/>
        <xsl:variable name="f75" select="0.75"/>
        
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {$w} {$h}" role="img">
            <path d="M { $cx - $r } { $cy } A { $r } { $r } 0 0 1 { $cx + $r } { $cy }"
                  fill="none" stroke="#84cc16" stroke-width="28"
                  stroke-dasharray="{ ($f25 * $pi_r) } { $pi_r }" />
            
            <path d="M { $cx - $r } { $cy } A { $r } { $r } 0 0 1 { $cx + $r } { $cy }"
                  fill="none" stroke="#d0d5dd" stroke-width="28"
                  stroke-dasharray="{ (0.50 * $pi_r) } { $pi_r }"
                  stroke-dashoffset="-{ ($f25 * $pi_r) }" />
            
            <path d="M { $cx - $r } { $cy } A { $r } { $r } 0 0 1 { $cx + $r } { $cy }"
                  fill="none" stroke="#f04438" stroke-width="28"
                  stroke-dasharray="{ (0.25 * $pi_r) } { $pi_r }"
                  stroke-dashoffset="-{ ($f75 * $pi_r) }" />
            
            <g transform="rotate({$angle - 180}, {$cx}, {$cy})">
                <line x1="{$cx}" y1="{$cy}" x2="{$cx + $r - 25}" y2="{$cy}" 
                      stroke="#101828" stroke-width="7" stroke-linecap="round"/>
            </g>
            <circle cx="{$cx}" cy="{$cy}" r="10" fill="#101828"/>
            
            <text x="{ $cx - $r - 15 }" y="{ $cy + 42 }" font-family="sans-serif" font-size="14" font-weight="600" fill="#667085">
                <xsl:value-of select="format-number($minv, '0.00')"/>
            </text>
            <text x="{ $cx + $r + 15 }" y="{ $cy + 42 }" font-family="sans-serif" font-size="14" font-weight="600" fill="#667085" text-anchor="end">
                <xsl:value-of select="format-number($maxv, '0.00')"/>
            </text>
            
            <text x="{$cx}" y="{ $cy + 42 }" text-anchor="middle" font-family="sans-serif" font-size="22" font-weight="900" fill="#101828">
                <xsl:value-of select="format-number($value, '0.00')"/>
                <xsl:text> CHF/kWh</xsl:text>
            </text>
        </svg>
    </xsl:template>

</xsl:stylesheet>
