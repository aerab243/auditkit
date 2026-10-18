<#
.SYNOPSIS
    Module d'audit : Pare-feu Windows.
.DESCRIPTION
    Verifie l'etat du pare-feu pour les profils Domaine, Prive et Public.
#>

Set-StrictMode -Version Latest

function Audit-Firewall {
    <#
    .SYNOPSIS
        Execute les tests du pare-feu et ajoute les resultats au rapport.
    #>
    param(
        [Parameter(Mandatory)][object]$Report
    )

    $section = Add-AuditSection $Report -Name "Pare-feu" `
        -Description "Etat des profils du Pare-feu Windows Defender."

    $profiles = Invoke-AuditCommand { Get-NetFirewallProfile }
    if (-not $profiles) {
        Add-AuditTest $section -Name "Pare-feu" -Status "WARN" `
            -Message "Impossible de lire les profils du pare-feu. Verifier que le service est actif."
        return
    }

    foreach ($p in $profiles) {
        # Profil : Domain, Private, Public
        $label = switch ($p.Name) {
            'Domain'  { 'Domaine' }
            'Private' { 'Prive' }
            'Public'  { 'Public' }
            default   { $p.Name }
        }

        $enabled = $p.Enabled
        if (-not $enabled) {
            $status = 'FAIL'
            $msg = "Pare-feu $label : DESACTIVE - risque important"
        }
        else {
            $status = 'OK'
            $msg = "Pare-feu $label : active"
        }
        $test = Add-AuditTest $section -Name "Pare-feu $label" -Status $status -Message $msg

        # Details : regles actives
        try {
            $ruleCount = (Get-NetFirewallRule -Profile $p.Name -ErrorAction SilentlyContinue | Measure-Object).Count
        } catch {
            $ruleCount = 0
        }
        $defaultAction = switch ($p.DefaultInboundAction) {
            'Block'   { 'Bloquer' }
            'Allow'   { 'Autoriser' }
            default    { [string]$p.DefaultInboundAction }
        }
        $stateText = 'Desactive'
        if ($enabled) { $stateText = 'Active' }
        Add-AuditDetail $test -Rows @(
            [pscustomobject]@{ Parametre = 'Etat';                       Valeur = $stateText },
            [pscustomobject]@{ Parametre = 'Action par defaut (entree)'; Valeur = $defaultAction },
            [pscustomobject]@{ Parametre = 'Regles actives';            Valeur = "$ruleCount" }
        )
    }

    # Resume global du pare-feu
    $anyDisabled = $profiles | Where-Object { -not $_.Enabled }
    if ($anyDisabled) {
        $names = ($anyDisabled.Name -join ', ')
        Add-AuditTest $section -Name "Resume pare-feu" -Status "WARN" `
            -Message "Profil(s) desactive(s) : $names. Le pare-feu doit etre active sur tous les profils."
    } else {
        Add-AuditTest $section -Name "Resume pare-feu" -Status "OK" `
            -Message "Tous les profils du pare-feu sont actives."
    }

    return
}

Export-ModuleMember -Function Audit-Firewall
