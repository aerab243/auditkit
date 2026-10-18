<#
.SYNOPSIS
    AuditKit - Audit Windows (point d'entree).
.DESCRIPTION
    Lance un audit du systeme local et genere un rapport HTML autonome.

    Architecture :
        AuditKit.ps1           -> ce script (orchestrateur)
        lib\Audit.Framework    -> moteur du rapport + helpers
        lib\modules\*.psm1     -> un module d'audit par concern

    Usage (Windows) :
        # 1) Depuis un shell PowerShell (recommande, en tant qu'admin) :
            cd C:\Users\aerab\Documents\scripts
            powershell -ExecutionPolicy Bypass -File .\AuditKit.ps1

        # 2) Avec options :
            .\AuditKit.ps1 -OutDir .\reports

    Le script est 100 % lecture seule : il ne modifie rien sur le systeme.
#>

[CmdletBinding()]
param(
    # Dossier ou deposer le rapport HTML. Defaut : %USERPROFILE%\Documents\audit-reports
    [string]$OutDir = (Join-Path $env:USERPROFILE 'Documents\audit-reports'),

    # Titre du rapport
    [string]$Title = 'AuditKit - Audit Windows',

    # Mode rapide : ne fait que les tests systeme + pare-feu
    [switch]$Fast
)

$ErrorActionPreference = 'Continue'

# ============================================================================
#  0. Pre-requis : verifier qu'on tourne sous PowerShell 5+ ou 7+
# ============================================================================
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Error "PowerShell 5.0 ou superieur est requis."
    exit 1
}

# ============================================================================
#  1. Verification des droits administrateur
# ============================================================================
function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($id)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

$isAdmin = Test-IsAdmin
Write-Host "============================================================"
Write-Host "  AuditKit - Audit Windows"
Write-Host "============================================================"
Write-Host "  Host        : $env:COMPUTERNAME"
Write-Host "  PowerShell  : v$($PSVersionTable.PSVersion)"
if ($isAdmin) {
    Write-Host "  Admin       : OUI" -ForegroundColor Green
} else {
    Write-Host "  Admin       : NON (certaines infos systeme seront limitees)" -ForegroundColor Yellow
}

if (-not $isAdmin) {
    Write-Warning "Lancez en tant qu'administrateur pour un audit complet (services, pare-feu, antivirus)."
    Write-Host "  Pour continuer en mode restreint, appuyez sur ENTER - sinon Ctrl+C pour annuler."
    [void]$host.Read
}

# ============================================================================
#  2. Charger le framework et les modules
# ============================================================================
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$libDir = Join-Path $root 'lib'

Write-Host ""
Write-Host "Chargement du framework..." -ForegroundColor Cyan
Import-Module -Name (Join-Path $libDir 'Audit.Framework.psm1') -Force

$moduleDir = Join-Path $libDir 'modules'
$modulesToLoad = Get-ChildItem -Path $moduleDir -Filter '*.psm1' -File

if ($Fast) {
    $selectedModules = $modulesToLoad | Where-Object {
        $_.Name -in @('Get-SystemInfo.psm1','Get-FirewallInfo.psm1')
    }
} else {
    $selectedModules = $modulesToLoad
}

foreach ($m in $selectedModules) {
    try {
        Import-Module -Name $m.FullName -Force
        Write-Host "  Loaded: $($m.Name)" -ForegroundColor DarkCyan
    } catch {
        Write-Warning "Impossible de charger $($m.Name) : $($_.Exception.Message)"
    }
}

# ============================================================================
#  3. Creer le rapport
# ============================================================================
Write-Host ""
Write-Host "Creation du rapport..." -ForegroundColor Cyan
$report = New-AuditReport -HostName $env:COMPUTERNAME -Title $Title

# ============================================================================
#  4. Executer les modules d'audit (lecture seule)
# ============================================================================
Write-Host ""
Write-Host "Execution des modules d'audit..." -ForegroundColor Cyan

# Correspondance : nom de fichier -> fonction d'audit
$auditFunctions = @{
    'Get-SystemInfo.psm1'     = { Get-AuditSystem $report | Out-Null }
    'Get-FirewallInfo.psm1'   = { Get-AuditFirewall $report | Out-Null }
    'Get-AntivirusInfo.psm1'  = { Get-AuditAntivirus $report | Out-Null }
    'Get-ServiceErrors.psm1'  = { Get-AuditServices $report | Out-Null }
}

foreach ($m in $selectedModules) {
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    Write-Host "  -> $($m.Name) ..." -NoNewline

    $block = $auditFunctions[$m.Name]
    if (-not $block) {
        Write-Host " (pas de fonction associee, ignore)" -ForegroundColor Yellow
        continue
    }

    try {
        & $block | Out-Null
        $timer.Stop()
        Write-Host " OK ($($timer.ElapsedMilliseconds) ms)" -ForegroundColor Green
    } catch {
        $timer.Stop()
        Write-Host " ERREUR : $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ============================================================================
#  5. Resume en console
# ============================================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
$summary = Get-AuditSummary $report
Write-Host "  RESUME" -ForegroundColor Cyan
Write-Host "============================================================"
$color = 'Red'
if ($summary.GlobalStatus -eq 'OK') { $color = 'Green' }
if ($summary.GlobalStatus -eq 'WARN') { $color = 'Yellow' }
Write-Host "  Statut global : $($summary.GlobalStatus)" -ForegroundColor $color
Write-Host "    OK : $($summary.OK) | WARN : $($summary.WARN) | FAIL : $($summary.FAIL) | INFO : $($summary.INFO) (total $($summary.Total))"

# ============================================================================
#  6. Export du rapport HTML
# ============================================================================
Write-Host ""
Write-Host "Generation du rapport HTML..." -ForegroundColor Cyan

# Creer le dossier de sortie
if (-not (Test-Path $OutDir)) {
    New-Item -Path $OutDir -ItemType Directory -Force | Out-Null
}

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$reportFile = Join-Path $OutDir "AuditKit_${env:COMPUTERNAME}_${timestamp}.html"
$reportPath = Export-AuditReportHtml -Report $report -Path $reportFile

# ============================================================================
#  7. Message final
# ============================================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  Audit termine !" -ForegroundColor Green
Write-Host "  Rapport HTML : $reportPath" -ForegroundColor Green
Write-Host "============================================================"
Write-Host ""
Write-Host "Ouvrir le rapport dans le navigateur ? (o/n)"
$choice = Read-Host
if ($choice -match '^[oO1Yy]$') {
    Start-Process -FilePath $reportPath
}
Write-Host ""
Write-Host "Audit termine avec succes." -ForegroundColor DarkGreen
