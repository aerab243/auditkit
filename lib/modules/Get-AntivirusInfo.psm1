<#
.SYNOPSIS
    Module d'audit : Antivirus (Windows Defender).
.DESCRIPTION
    Verifie l'etat de Windows Defender : service, protection en temps reel,
    antivirus / antimalware, definitions a jour, anciennete du dernier scan.

    NB : les cmdlets Get-MpComputerSecurity et Get-MpScan ont ete retires de
    Windows 11 24H2+. Ce module utilise Get-MpComputerStatus, present sur
    toutes les versions de Windows integrant Defender.
#>

Set-StrictMode -Version Latest

function Get-AuditAntivirus {
    <#
    .SYNOPSIS
        Execute les tests de l'antivirus et ajoute les resultats au rapport.
    #>
    param(
        [Parameter(Mandatory)][object]$Report
    )

    $section = Add-AuditSection $Report -Name "Antivirus (Windows Defender)" `
        -Description "Etat de protection de l'antivirus integre."

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

    # ---- 2. Etat de la protection ----
    # Get-MpComputerStatus est le cmdlet de reference (toutes versions).
    # Repli sur Get-MpComputerSecurity pour les builds anterieurs.
    $mp = $null
    if (Get-Command -Name Get-MpComputerStatus -ErrorAction SilentlyContinue) {
        $mp = Invoke-AuditCommand { Get-MpComputerStatus }
    }
    if (-not $mp -and (Get-Command -Name Get-MpComputerSecurity -ErrorAction SilentlyContinue)) {
        $mp = Invoke-AuditCommand { Get-MpComputerSecurity }
    }

    if (-not $mp) {
        Add-AuditTest $section -Name "Etat Windows Defender" -Status "WARN" `
            -Message "Impossible d'interroger Windows Defender (cmdlets MP indisponibles ou Defender absent)."
        return
    }

    # ---- 3. Protection en temps reel ----
    if ($mp.RealTimeProtectionEnabled) {
        Add-AuditTest $section -Name "Protection en temps reel" -Status "OK" `
            -Message "La protection en temps reel est activee."
    } else {
        Add-AuditTest $section -Name "Protection en temps reel" -Status "FAIL" `
            -Message "La protection en temps reel est DESACTIVEE."
    }

    # ---- 4. Antivirus / antimalware ----
    if ($mp.AntivirusEnabled) {
        Add-AuditTest $section -Name "Antivirus" -Status "OK" -Message "L'antivirus est actif."
    } else {
        Add-AuditTest $section -Name "Antivirus" -Status "WARN" -Message "L'antivirus est desactive."
    }

    if ($mp.AntispywareEnabled) {
        Add-AuditTest $section -Name "Antimalware" -Status "OK" -Message "L'antimalware est actif."
    } else {
        Add-AuditTest $section -Name "Antimalware" -Status "WARN" -Message "L'antimalware est desactive."
    }

    # ---- 5. Definitions de signatures ----
    $sigAgeDays = $null
    if ($mp.AntivirusSignatureLastUpdated) {
        $sigAgeDays = ((Get-Date) - $mp.AntivirusSignatureLastUpdated).Days
    }

    if ($null -eq $sigAgeDays) {
        $sigStatus = 'WARN'
        $sigMsg = "Date de derniere mise a jour des definitions inconnue."
    }
    elseif ($sigAgeDays -le 3) {
        $sigStatus = 'OK'
        $sigMsg = "Definitions a jour (maj il y a ${sigAgeDays} jour(s))."
    }
    elseif ($sigAgeDays -le 7) {
        $sigStatus = 'WARN'
        $sigMsg = "Definitions un peu anciennes (maj il y a ${sigAgeDays} jour(s))."
    }
    else {
        $sigStatus = 'FAIL'
        $sigMsg = "Definitions obsoletes (maj il y a ${sigAgeDays} jour(s))."
    }

    $test = Add-AuditTest $section -Name "Definitions de signatures" -Status $sigStatus -Message $sigMsg
    $sigRows = @()
    if ($mp.AntivirusSignatureVersion) {
        $sigRows += [pscustomobject]@{ Nom = 'Version'; Valeur = $mp.AntivirusSignatureVersion }
    }
    if ($mp.AntivirusSignatureLastUpdated) {
        $sigRows += [pscustomobject]@{ Nom = 'Derniere maj'; Valeur = $mp.AntivirusSignatureLastUpdated.ToString('dd/MM/yyyy HH:mm') }
    }
    if ($null -ne $sigAgeDays) {
        $sigRows += [pscustomobject]@{ Nom = 'Age (jours)'; Valeur = "$sigAgeDays" }
    }
    if ($sigRows.Count -gt 0) {
        Add-AuditDetail $test -Rows $sigRows
    }

    # ---- 6. Anciennete du dernier scan ----
    # NB : QuickScanAge / FullScanAge valent 4294967295 (UInt32 max) quand
    # aucun scan n'a jamais ete enregistre sur le poste.
    if ($mp.PSObject.Properties.Name -contains 'QuickScanAge') {
        $noScanSentinel = 4294967295
        $scanAges = @()
        foreach ($prop in @('QuickScanAge', 'FullScanAge')) {
            $age = $mp.$prop
            if ($null -ne $age -and [uint64]$age -lt $noScanSentinel) {
                $scanAges += [int]$age
            }
        }

        if ($scanAges.Count -eq 0) {
            Add-AuditTest $section -Name "Dernier scan antivirus" -Status "WARN" `
                -Message "Aucun scan antivirus enregistre sur ce poste."
        }
        else {
            $scanAgeDays = ($scanAges | Measure-Object -Minimum).Minimum
            $scanStatus = 'OK'
            if ($scanAgeDays -gt 7) { $scanStatus = 'WARN' }
            Add-AuditTest $section -Name "Dernier scan antivirus" -Status $scanStatus `
                -Message "Dernier scan antivirus il y a ${scanAgeDays} jour(s)."
        }
    }

    return
}

Export-ModuleMember -Function Get-AuditAntivirus
