<#
.SYNOPSIS
    Module d'audit : Informations systeme.
.DESCRIPTION
    Verifie : version OS, RAM, disque dur, uptime, CPU.
#>

Set-StrictMode -Version Latest

function Get-AuditSystem {
    <#
    .SYNOPSIS
        Execute les tests de l'information systeme et ajoute les resultats au rapport.
    #>
    param(
        [Parameter(Mandatory)][object]$Report,
        # Seuils de tolerance (defaut : Get-AuditDefaultThresholds)
        [object]$Thresholds
    )

    if (-not $Thresholds) { $Thresholds = Get-AuditDefaultThresholds }

    $section = Add-AuditSection $Report -Name "Systeme" `
        -Description "Version, ressources materielles et disponibilite."

    # ---- 1. Version Windows ----
    $os = Get-CimInstance Win32_OperatingSystem
    $test = Add-AuditTest $section -Name "Version de l'OS" -Status "INFO" `
        -Message "$($os.Caption) - Build $($os.Version) ($($os.OSArchitecture))"
    Add-AuditDetail $test -Rows @(
        [pscustomobject]@{ Nom = 'Nom';              Valeur = $os.Caption },
        [pscustomobject]@{ Nom = 'Build';            Valeur = $os.Version },
        [pscustomobject]@{ Nom = 'Architecture';     Valeur = $os.OSArchitecture },
        [pscustomobject]@{ Nom = 'Derniere install'; Valeur = $os.InstallDate.ToString('dd/MM/yyyy') }
    )

    # ---- 2. Memoire RAM ----
    $totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
    $freeGB  = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
    $usedGB  = [math]::Round($totalGB - $freeGB, 1)
    $ramStatus = 'OK'
    if ($totalGB -lt $Thresholds.Ram.FailGo) {
        $ramStatus = 'FAIL'
        $msg = "RAM insuffisante : ${totalGB} Go"
    }
    elseif ($totalGB -lt $Thresholds.Ram.WarnGo) {
        $ramStatus = 'WARN'
        $msg = "RAM moderee : ${totalGB} Go (recommande : 8 Go+)"
    }
    else {
        $msg = "${totalGB} Go totaux, ${freeGB} Go disponibles"
    }
    $test = Add-AuditTest $section -Name "Memoire RAM" -Status $ramStatus -Message $msg
    Add-AuditDetail $test -Rows @(
        [pscustomobject]@{ Metrique = 'Total';     Valeur = "$totalGB Go" },
        [pscustomobject]@{ Metrique = 'Libre';     Valeur = "$freeGB Go" },
        [pscustomobject]@{ Metrique = 'Utilisee';  Valeur = "$usedGB Go" }
    )

    # ---- 3. Disque dur ----
    $disks = @(Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 })
    foreach ($disk in $disks) {
        $diskTotalGB  = [math]::Round($disk.Size / 1GB, 1)
        $diskFreeGB   = [math]::Round($disk.FreeSpace / 1GB, 1)
        $diskUsedPct  = [math]::Round((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100, 1)
        $diskStatus = 'OK'
        if ($diskUsedPct -ge $Thresholds.Disque.FailPct) {
            $diskStatus = 'FAIL'
            $diskMsg = "Disque $($disk.DeviceID) presque plein : ${diskUsedPct}% utilise"
        }
        elseif ($diskUsedPct -ge $Thresholds.Disque.WarnPct) {
            $diskStatus = 'WARN'
            $diskMsg = "Disque $($disk.DeviceID) : ${diskUsedPct}% utilise, surveiller"
        }
        else {
            $diskMsg = "Disque $($disk.DeviceID) : ${diskTotalGB} Go, ${diskFreeGB} Go libres (${diskUsedPct}%)"
        }
        $test = Add-AuditTest $section -Name "Disque $($disk.DeviceID)" -Status $diskStatus -Message $diskMsg
        Add-AuditDetail $test -Rows @(
            [pscustomobject]@{ Unite = $disk.DeviceID; Total = "$diskTotalGB Go"; Libre = "$diskFreeGB Go"; Utilise = "${diskUsedPct}%" }
        )
    }
    if ($disks.Count -eq 0) {
        Add-AuditTest $section -Name "Disques" -Status "FAIL" -Message "Aucun disque detecte !"
    }

    # ---- 4. CPU ----
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $cpuCores = $cpu.NumberOfCores
    $test = Add-AuditTest $section -Name "Processeur" -Status "INFO" `
        -Message "$($cpu.Name) - $cpuCores coeurs"

    # ---- 5. Uptime (temps de fonctionnement) ----
    $uptime = (Get-Date) - $os.LastBootUpTime
    Add-AuditTest $section -Name "Uptime" -Status "INFO" `
        -Message "Le systeme tourne depuis $($uptime.Days)j $($uptime.Hours)h $($uptime.Minutes)m"

    return
}

Export-ModuleMember -Function Get-AuditSystem
