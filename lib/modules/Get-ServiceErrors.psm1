<#
.SYNOPSIS
    Module d'audit : Services en erreur.
.DESCRIPTION
    Liste les services Windows en état d'erreur ou arrêtés de manière critique.
#>

Set-StrictMode -Version Latest

function Get-AuditServices {
    <#
    .SYNOPSIS
        Exécute les tests des services et ajoute les résultats au rapport.
    #>
    param(
        [Parameter(Mandatory)][object]$Report
    )

    $section = Add-AuditSection $Report -Name "Services" `
        -Description "Services Windows en état d'erreur ou non démarrés."

    # ---- 1. Services automatiques arrêtés ----
    # NB : @() garantit un tableau même quand aucun (ou un seul) service est retourné.
    try {
        $errorServices = @(Get-Service | Where-Object { $_.Status -eq 'Stopped' -and $_.StartType -eq 'Automatic' })
    } catch {
        Add-AuditTest $section -Name "Services automatiques en erreur" -Status "WARN" `
            -Message "Impossible de récupérer la liste des services."
        return $section
    }

    if ($errorServices.Count -eq 0) {
        Add-AuditTest $section -Name "Services automatiques en erreur" -Status "OK" `
            -Message "Aucun service automatique arrêté anormalement."
    } else {
        $names = $errorServices | ForEach-Object { $_.Name } | Select-Object -First 10
        $test = Add-AuditTest $section -Name "Services automatiques en erreur" -Status "WARN" `
            -Message "$($errorServices.Count) service(s) automatique(s) arrêté(s) : $($names -join ', ')"
        Add-AuditDetail $test -Rows @(
            $errorServices | Select-Object -First 10 | ForEach-Object {
                [pscustomobject]@{ Service = $_.Name; DisplayName = $_.DisplayName; Status = 'Arrêté' }
            }
        )
    }

    # ---- 2. Services critiques qui ne tournent pas ----
    # Quelques services critiques à surveiller
    $criticalServices = @(
        'Dhcp',       # Service DHCP
        'Dnscache',   # Cache DNS
        'W32Time',    # Service d'heure Windows
        'lanmanwork', # Service Travail
        'Spooler',    # Spouleur d'impression
        'LanmanServer'
    )
    foreach ($svcName in $criticalServices) {
        try {
            $svc = Get-Service -Name $svcName -ErrorAction Stop
            if ($svc.Status -ne 'Running') {
                Add-AuditTest $section -Name "Service critique : $svcName" -Status "WARN" `
                    -Message "Le service $($svc.DisplayName) est $($svc.Status). Cela peut affecter le réseau ou la session."
            } else {
                Add-AuditTest $section -Name "Service critique : $svcName" -Status "OK" `
                    -Message "$($svc.DisplayName) est en cours d'exécution."
            }
        } catch {
            # Service non présent sur cette machine, on saute silencieusement
            continue
        }
    }

    return
}

Export-ModuleMember -Function Get-AuditServices
