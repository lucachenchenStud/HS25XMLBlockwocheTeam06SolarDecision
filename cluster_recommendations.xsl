<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:f="urn:functions"
                exclude-result-prefixes="xs f">

    <xsl:output method="xml" indent="yes"/>

    <xsl:param name="prices-uri" as="xs:string"/>
    <xsl:param name="sunshine-uri" as="xs:string"/>
    <xsl:param name="fail-on-invalid" as="xs:boolean" select="true()"/>


    <xsl:key name="kPriceByDt" match="price" use="@datetime"/>
    <xsl:key name="kSunByDt" match="value" use="@datetime"/>

    <!-- Quantile helper, expects sorted ascending doubles -->
    <xsl:function name="f:quantile" as="xs:double">
        <xsl:param name="sorted" as="xs:double*"/>
        <xsl:param name="q" as="xs:double"/>
        <xsl:variable name="n" select="count($sorted)"/>
        <xsl:variable name="pos" select="max((1, min(($n, ceiling($q * $n)))))"/>
        <xsl:sequence select="$sorted[$pos]"/>
    </xsl:function>

    <xsl:template name="main">
        <xsl:variable name="pdoc" select="doc($prices-uri)"/>
        <xsl:variable name="sdoc" select="doc($sunshine-uri)"/>

        <!-- Only keep price nodes that have matching sunshine -->
        <xsl:variable name="joinedPrices" as="element(price)*"
                      select="$pdoc//price[key('kSunByDt', @datetime, $sdoc)]"/>

        <!-- Extract numeric sequences -->
        <xsl:variable name="priceVals" as="xs:double*"
                      select="for $p in $joinedPrices return xs:double(normalize-space(string($p)))"/>

        <xsl:variable name="sunVals" as="xs:double*"
                      select="
        for $p in $joinedPrices
        return xs:double(
          normalize-space(
            string(key('kSunByDt', string($p/@datetime), $sdoc)[1])
          )
        )
      "/>

        <!-- Sort sequences using xsl:perform-sort -->
        <xsl:variable name="priceSorted" as="xs:double*">
            <xsl:perform-sort select="$priceVals">
                <xsl:sort select="." data-type="number" order="ascending"/>
            </xsl:perform-sort>
        </xsl:variable>

        <xsl:variable name="sunSorted" as="xs:double*">
            <xsl:perform-sort select="$sunVals">
                <xsl:sort select="." data-type="number" order="ascending"/>
            </xsl:perform-sort>
        </xsl:variable>

        <!-- Quantile thresholds -->
        <xsl:variable name="p33" select="f:quantile($priceSorted, 0.33)"/>
        <xsl:variable name="p66" select="f:quantile($priceSorted, 0.66)"/>
        <xsl:variable name="s33" select="f:quantile($sunSorted, 0.33)"/>
        <xsl:variable name="s66" select="f:quantile($sunSorted, 0.66)"/>

        <clusters>
            <thresholds>
                <price q33="{$p33}" q66="{$p66}"/>
                <sunshine q33="{$s33}" q66="{$s66}"/>
            </thresholds>

            <xsl:for-each select="$joinedPrices">
                <xsl:sort select="@datetime"/>

                <xsl:variable name="dt" select="string(@datetime)"/>
                <xsl:variable name="p" select="xs:double(normalize-space(string(.)))"/>
                <xsl:variable name="sNode" select="key('kSunByDt', $dt, $sdoc)[1]"/>
                <xsl:variable name="s" select="xs:double(normalize-space(string($sNode)))"/>

                <!-- 3 regime clustering -->
                <xsl:variable name="cluster" as="xs:integer"
                              select="
            if ($s lt $s33 or $p lt $p33) then 0
            else if ($s ge $s66 and $p ge $p66) then 2
            else 1
          "/>

                <xsl:variable name="recommendation"
                              select="if ($cluster = 2) then 'SELL' else 'HOLD'"/>

                <xsl:if test="not($p castable as xs:double)">
                    <xsl:message terminate="yes">Invalid price at {$dt}: "{$p}"</xsl:message>
                </xsl:if>

                <xsl:if test="$s lt 0">
                    <xsl:message terminate="yes">Invalid sunshine at {$dt}: {$s} must be >= 0</xsl:message>
                </xsl:if>

                <sample datetime="{$dt}" cluster="{$cluster}" recommendation="{$recommendation}">
                    <sunshine><xsl:value-of select="$s"/></sunshine>
                    <price><xsl:value-of select="$p"/></price>
                </sample>
                <xsl:if test="not($cluster = (0, 1, 2))">
                    <xsl:message terminate="yes">Invalid cluster at {$dt}: {$cluster}</xsl:message>
                </xsl:if>

                <xsl:if test="$recommendation = 'SELL' and $cluster ne 2">
                    <xsl:message terminate="yes">Rule violation at {$dt}: SELL only allowed for cluster 2</xsl:message>
                </xsl:if>
            </xsl:for-each>
        </clusters>
    </xsl:template>

</xsl:stylesheet>
