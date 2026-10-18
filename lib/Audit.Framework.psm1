<#
.SYNOPSIS
    AuditKit - Module Framework.
    Fournit le moteur de rapport et les helpers communs a tous les modules.
.DESCRIPTION
    Ce module centralise :
      - la structure du rapport (objet "AuditReport")
      - l'ajout de sections / tests / resultats
      - la detection de statut (OK / WARN / FAIL / INFO)
      - l'export en HTML
.NOTES
    A charger avec :  Import-Module -Name .\lib\Audit.Framework.psm1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Charger le namespace System.Web (necessaire pour HttpUtility)
if (-not ('System.Web.HttpUtility' -as [type])) {
    Add-Type -AssemblyName System.Web
}

# ============================================================================
#  Statuts possibles
# ============================================================================
$script:STATUS = @{
    'OK'   = @{ Label = 'OK';     CssClass = 'ok';   Icon = 'OK' }
    'WARN' = @{ Label = 'Warning';CssClass = 'warn'; Icon = 'WARN' }
    'FAIL' = @{ Label = 'FAIL';   CssClass = 'fail'; Icon = 'FAIL' }
    'INFO' = @{ Label = 'Info';   CssClass = 'info'; Icon = 'INFO' }
}

# ============================================================================
#  Nouveau rapport
# ============================================================================
function New-AuditReport {
    <#
    .SYNOPSIS
        Cree un objet de rapport vide pret a l'emploi.
    #>
    param(
        [Parameter(Mandatory)] [string]$HostName,
        [string]$Title = 'Audit Windows'
    )

    $report = [pscustomobject]@{
        Title        = $Title
        HostName     = $HostName
        GeneratedAt  = Get-Date
        Generator    = 'AuditKit'
        Sections     = [System.Collections.Generic.List[object]]::new()
    }
    return $report
}

# ============================================================================
#  Ajoute une section au rapport
# ============================================================================
function Add-AuditSection {
    <#
    .SYNOPSIS
        Ajoute une section (titre + description) au rapport.
    #>
    param(
        [Parameter(Mandatory)] [object]$Report,
        [Parameter(Mandatory)] [string]$Name,
        [string]$Description = ''
    )
    $section = [pscustomobject]@{
        Name        = $Name
        Description = $Description
        Tests       = [System.Collections.Generic.List[object]]::new()
    }
    $Report.Sections.Add($section)
    return $section
}

# ============================================================================
#  Ajoute un test (resultat) a une section
# ============================================================================
function Add-AuditTest {
    <#
    .SYNOPSIS
        Ajoute un test a une section avec un statut et un message.
    #>
    param(
        [Parameter(Mandatory)] [object]$Section,
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [ValidateSet('OK','WARN','FAIL','INFO')][string]$Status,
        [string]$Message = ''
    )
    $test = [pscustomobject]@{
        Name     = $Name
        Status   = $Status
        Message  = $Message
        Details  = $null
        Timestamp = Get-Date
    }
    $Section.Tests.Add($test)
    return $test
}

# ============================================================================
#  Ajoute des details (tableau) a un test
# ============================================================================
function Add-AuditDetail {
    <#
    .SYNOPSIS
        Ajoute des lignes de details (ex: tableau) a un test.
    #>
    param(
        [Parameter(Mandatory)] [object]$Test,
        [Parameter(Mandatory)] [object[]]$Rows
    )
    $Test.Details = $Rows
}

# ============================================================================
#  Resume du rapport
# ============================================================================
function Get-AuditSummary {
    <#
    .SYNOPSIS
        Retourne le nombre de tests par statut et un statut global.
    #>
    param([Parameter(Mandatory)][object]$Report)

    $counts = @{ OK = 0; WARN = 0; FAIL = 0; INFO = 0 }
    foreach ($sec in $Report.Sections) {
        foreach ($t in $sec.Tests) {
            $counts[$t.Status]++
        }
    }

    # Statut global : FAIL si au moins 1 FAIL, sinon WARN si au moins 1 WARN
    $globalStatus = 'OK'
    if ($counts['FAIL'] -gt 0) { $globalStatus = 'FAIL' }
    elseif ($counts['WARN'] -gt 0) { $globalStatus = 'WARN' }

    [pscustomobject]@{
        OK    = $counts['OK']
        WARN  = $counts['WARN']
        FAIL  = $counts['FAIL']
        INFO  = $counts['INFO']
        Total = $counts.Values | Measure-Object -Sum | Select-Object -Expand Sum
        GlobalStatus = $globalStatus
    }
}

# ============================================================================
#  Style CSS pour le rapport HTML (charge depuis le fichier audit-report.css)
# ============================================================================
function Get-AuditCss {
    <#
    .SYNOPSIS
        Retourne le style CSS complet pour le rapport HTML.
    #>
    $cssFile = Join-Path $PSScriptRoot 'audit-report.css'
    $css = Get-Content -Path $cssFile -Raw
    return $css
}

# ============================================================================
#  Export HTML
# ============================================================================
function Export-AuditReportHtml {
    <#
    .SYNOPSIS
        Exporte le rapport dans un fichier HTML autonome (pas de dependances).
    .EXAMPLE
        Export-AuditReportHtml -Report $report -Path .\rapport.html
    #>
    param(
        [Parameter(Mandatory)][object]$Report,
        [Parameter(Mandatory)][string]$Path
    )

    $summary = Get-AuditSummary $Report
    $statusInfo = $script:STATUS
    $title = [System.Web.HttpUtility]::HtmlEncode($Report.Title)
    $css = Get-AuditCss

    # ---- Construction du HTML ----
    $html = New-Object System.Text.StringBuilder
    [void]$html.AppendLine('<!DOCTYPE html>')
    [void]$html.AppendLine('<html lang="fr">')
    [void]$html.AppendLine('<head>')
    [void]$html.AppendLine('  <meta charset="UTF-8">')
    [void]$html.AppendLine('  <meta name="viewport" content="width=device-width, initial-scale=1.0">')
    [void]$html.AppendLine("  <title>$title</title>")
    [void]$html.AppendLine("  <style>$css</style>")
    [void]$html.AppendLine('</head>')
    [void]$html.AppendLine('<body>')
    [void]$html.AppendLine('  <div class="container">')

    # Header
    [void]$html.AppendLine('    <header>')
    [void]$html.AppendLine("      <h1>$title</h1>")
    [void]$html.AppendLine('      <div class="meta">')
    [void]$html.AppendLine('        <span>Host : <strong>' + [System.Web.HttpUtility]::HtmlEncode($Report.HostName) + '</strong></span>')
    [void]$html.AppendLine('        <span>Genere le : ' + $Report.GeneratedAt.ToString('dd/MM/yyyy HH:mm') + '</span>')
    [void]$html.AppendLine('      </div>')
    [void]$html.AppendLine('    </header>')

    # Banner global
    $bannerClass = $summary.GlobalStatus.ToLower()
    [void]$html.AppendLine("    <div class='global-banner $bannerClass'>")
    [void]$html.AppendLine('      Resultat global : ' + $summary.GlobalStatus + ' - ' + $summary.Total + " tests, $($summary.FAIL) eche(s), $($summary.WARN) avertissement(s)")
    [void]$html.AppendLine('    </div>')

    # Summary cards
    [void]$html.AppendLine('    <div class="summary">')
    foreach ($s in @('OK','WARN','FAIL','INFO','Total')) {
        if ($s -eq 'Total') {
            $val = $summary.Total
        } else {
            $val = $summary.$s
        }
        $cardClass = $s.ToLower()
        [void]$html.AppendLine("      <div class='summary-card $cardClass'><div class='num'>$val</div><div class='lbl'>$s</div></div>")
    }
    [void]$html.AppendLine('    </div>')

    # Sections
    foreach ($sec in $Report.Sections) {
        $secTitle = [System.Web.HttpUtility]::HtmlEncode($sec.Name)
        [void]$html.AppendLine("    <section class='test-group'>")
        [void]$html.AppendLine("      <h2>$secTitle</h2>")
        if ($sec.Description) {
            [void]$html.AppendLine('      <div class="desc">' + [System.Web.HttpUtility]::HtmlEncode($sec.Description) + '</div>')
        }
        foreach ($t in $sec.Tests) {
            $tName = [System.Web.HttpUtility]::HtmlEncode($t.Name)
            $tMsg  = ''
            if ($t.Message) { $tMsg = [System.Web.HttpUtility]::HtmlEncode($t.Message) }
            $badge = $statusInfo[$t.Status].CssClass
            $icon  = $statusInfo[$t.Status].Icon
            $lbl   = $statusInfo[$t.Status].Label
            [void]$html.AppendLine('      <div class="test">')
            [void]$html.AppendLine('        <div class="row">')
            [void]$html.AppendLine("          <span class='badge $badge'>$icon $lbl</span>")
            [void]$html.AppendLine('          <div>')
            [void]$html.AppendLine("            <div class='name'>$tName</div>")
            if ($tMsg) {
                [void]$html.AppendLine("            <div class='msg'>$tMsg</div>")
            }
            [void]$html.AppendLine('          </div>')
            [void]$html.AppendLine('        </div>')

            # Details (tableau)
            if ($t.Details) {
                $rows = $t.Details
                if ($rows.Count -gt 0) {
                    $headers = $rows[0].PSObject.Properties.Name
                    [void]$html.AppendLine('        <table>')
                    [void]$html.AppendLine('          <thead><tr>')
                    foreach ($h in $headers) {
                        [void]$html.AppendLine('            <th>' + [System.Web.HttpUtility]::HtmlEncode($h) + '</th>')
                    }
                    [void]$html.AppendLine('          </tr></thead>')
                    [void]$html.AppendLine('          <tbody>')
                    foreach ($row in $rows) {
                        [void]$html.AppendLine('            <tr>')
                        foreach ($h in $headers) {
                            $val = $row.$h
                            [void]$html.AppendLine('              <td>' + [System.Web.HttpUtility]::HtmlEncode([string]$val) + '</td>')
                        }
                        [void]$html.AppendLine('            </tr>')
                    }
                    [void]$html.AppendLine('          </tbody>')
                    [void]$html.AppendLine('        </table>')
                }
            }
            [void]$html.AppendLine('      </div>')
        }
        [void]$html.AppendLine('    </section>')
    }

    # Footer
    [void]$html.AppendLine('    <footer>')
    [void]$html.AppendLine('      Rapport genere par ' + [System.Web.HttpUtility]::HtmlEncode($Report.Generator) + ' - ' + $Report.GeneratedAt.ToString('dd/MM/yyyy HH:mm:ss'))
    [void]$html.AppendLine('    </footer>')
    [void]$html.AppendLine('  </div>')
    [void]$html.AppendLine('</body>')
    [void]$html.AppendLine('</html>')

    Set-Content -Path $Path -Value $html.ToString() -Encoding utf8
    Write-Host "  [Framework] Rapport HTML exporte : $Path" -ForegroundColor Green
    return $Path
}

# ============================================================================
#  Executer une commande en mode "lecture" (ne modifie rien)
# ============================================================================
function Invoke-AuditCommand {
    <#
    .SYNOPSIS
        Execute une commande PowerShell, capture la sortie et ne leve pas
        d'erreur qui casserait l'audit (continue sur erreur).
    #>
    param(
        [Parameter(Mandatory)][scriptblock]$Command
    )
    try {
        return & $Command
    } catch {
        Write-Warning "  [Framework] Erreur lors de l'execution : $($_.Exception.Message)"
        return $null
    }
}

Export-ModuleMember -Function *
