<#
.SYNOPSIS
    Module d'audit : Antivirus (Windows Defender).
.DESCRIPTION
    Verifie l'etat de Windows Defender : antivirus, antimalware, definitions a jour.
#>

Set-StrictMode -Version Latest

function Audit-Antivirus {
    <#
    .SYNOPSIS
        Execute les tests de l'antivirus et ajoute les resultats au rapport.
    #>
    param(
        [Parameter(Mandatory)][object]$Report
    )

    $section = Add-AuditSection $Report -Name "Antivirus (Windows Defender)" `
        -Description "Etat de protection du antivirus integre."

    # ---- 1. Service Windows Defender (WinDefend) ----
    try {
        $defenderService = Get-Service -Name WinDefend -ErrorAction Stop
        if ($defenderService.Status -ne 'Running') {
            Add-AuditTest $section -Name "Service Windows Defender" -Status "FAIL" `
                -Message "Le service WinDefend est $($defenderService.Status), il devrait etre en cours d'execution."
        } else {
            Add-AuditTest $section -Name "Service Windows Defender" -Status "OK" `
                -Message "Le service Windows Defender est en cours d'execution."
        }
    } catch {
        Add-AuditTest $section -Name "Service Windows Defender" -Status "WARN" `
            -Message "Service WinDefend non trouve (certaines editions Windows n'en ont pas)."
    }

    # ---- 2. Get-MpComputerSecurity ----
    if (-not (Get-Command -Name Get-MpComputerSecurity -ErrorAction SilentlyContinue)) {
        Add-AuditTest $section -Name "Securite Microsoft (MP)" -Status "WARN" `
            -Message "Get-MpComputerSecurity indisponible (module Microsoft.MPTerminal non charge ou Defender absent)."
        return
    }
    $msft = Invoke-AuditCommand { Get-MpComputerSecurity }
    if (-not $msft) {
        Add-AuditTest $section -Name "Securite Microsoft (MP)" -Status "WARN" `
            -Message "Get-MpComputerSecurity indisponible (module Microsoft.MPTerminal non charge ou Defender absent)."
        return
    }

    # Antivirus active
    if ($msft.RealTimeProtection.Enabled) {
        Add-AuditTest $section -Name "Protection en temps reel" -Status "OK" `
            -Message "La protection en temps reel est activee."
    } else {
        Add-AuditTest $section -Name "Protection en temps reel" -Status "FAIL" `
            -Message "La protection en temps reel est DESACTIVEE."
    }

    # Antimalware
    $am = $msft.Antimalware
    if ($am.Enabled) {
        Add-AuditTest $section -Name "Antimalware" -Status "OK" -Message "L'antimalware est active."
    } else {
        Add-AuditTest $section -Name "Antimalware" -Status "WARN" -Message "L'antimalware est desactive."
    }

    # Definitions de signatures a jour
    $sig = $msft.Signature
    $sigAgeDays = 0
    if ($sig.LastUpdated) {
        $sigAgeDays = ((Get-Date) - $sig.LastUpdated).Days
    }
    if ($sigAgeDays -le 3) {
        $sigStatus = 'OK'
        $sigMsg = "Definitions a jour (maj il y a ${sigAgeDays} jour(s))."
    } elseif ($sigAgeDays -le 7) {
        $sigStatus = 'WARN'
        $sigMsg = "Definitions un peu anciennes (maj il y a ${sigAgeDays} jour(s))."
    } else {
        $sigStatus = 'FAIL'
        $sigMsg = "Definitions obsolletes (maj il y a ${sigAgeDays} jour(s))."
    }
    $test = Add-AuditTest $section -Name "Definitions de signatures" -Status $sigStatus -Message $sigMsg
    Add-AuditDetail $test -Rows @(
        [pscustomobject]@{ Nom = 'Signature';    Valeur = $sig.Signature },
        [pscustomobject]@{ Nom = 'Derniere maj';  Valeur = $sig.LastUpdated.ToString('dd/MM/yyyy HH:mm') },
        [pscustomobject]@{ Nom = 'Age (jours)';  Valeur = "${sigAgeDays}" }
    )

    # ---- 3. Scan complet recent ? ----
    $lastScan = Invoke-AuditCommand { Get-MpScan }
    if ($lastScan) {
        $mostRecent = $lastScan | Sort-Object CompletionTime -Descending | Select-Object -First 1
        $scanAgeDays = ((Get-Date) - $mostRecent.CompletionTime).Days
        if ($scanAgeDays -le 7) { $scanStatus = 'OK' } else { $scanStatus = 'WARN' }
        $scanMsg = "Dernier scan : $($mostRecent.ScanType) il y a ${scanAgeDays} jour(s)."
        Add-AuditTest $section -Name "Dernier scan antivirus" -Status $scanStatus -Message $scanMsg
    }

    return
}

Export-ModuleMember -Function Audit-Antivirus
