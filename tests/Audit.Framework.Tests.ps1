BeforeAll {
    Import-Module "$PSScriptRoot\..\lib\Audit.Framework.psm1" -Force
}

Describe 'Audit.Framework - structure du rapport' {

    Context 'New-AuditReport' {
        It 'cree un rapport avec les metadonnees attendues' {
            $r = New-AuditReport -HostName 'TEST-PC' -Title 'Audit de test'
            $r.HostName | Should -Be 'TEST-PC'
            $r.Title | Should -Be 'Audit de test'
            $r.Generator | Should -Be 'AuditKit'
            $r.Sections.Count | Should -Be 0
        }
    }

    Context 'Add-AuditSection / Add-AuditTest' {
        It 'ajoute une section et des tests' {
            $r = New-AuditReport -HostName 'TEST-PC'
            $s = Add-AuditSection $r -Name 'Systeme' -Description 'desc'
            Add-AuditTest $s -Name 'Test 1' -Status 'OK' -Message 'ok'
            Add-AuditTest $s -Name 'Test 2' -Status 'FAIL'
            $r.Sections.Count | Should -Be 1
            $r.Sections[0].Tests.Count | Should -Be 2
        }

        It 'accepte les 4 statuts valides' {
            $r = New-AuditReport -HostName 'TEST-PC'
            $s = Add-AuditSection $r -Name 'S'
            foreach ($st in @('OK', 'WARN', 'FAIL', 'INFO')) {
                { Add-AuditTest $s -Name "t-$st" -Status $st } | Should -Not -Throw
            }
        }

        It 'rejette un statut invalide' {
            $r = New-AuditReport -HostName 'TEST-PC'
            $s = Add-AuditSection $r -Name 'S'
            { Add-AuditTest $s -Name 'x' -Status 'INCONNU' } | Should -Throw
        }

        It 'attache des details a un test' {
            $r = New-AuditReport -HostName 'TEST-PC'
            $s = Add-AuditSection $r -Name 'S'
            $t = Add-AuditTest $s -Name 't' -Status 'OK'
            Add-AuditDetail $t -Rows @([pscustomobject]@{ A = 1 }, [pscustomobject]@{ A = 2 })
            $t.Details.Count | Should -Be 2
        }
    }

    Context 'Get-AuditSummary' {
        It 'compte les statuts et deduit le statut global WARN' {
            $r = New-AuditReport -HostName 'TEST-PC'
            $s = Add-AuditSection $r -Name 'S'
            Add-AuditTest $s -Name 'a' -Status 'OK'
            Add-AuditTest $s -Name 'b' -Status 'OK'
            Add-AuditTest $s -Name 'c' -Status 'WARN'
            $sum = Get-AuditSummary $r
            $sum.OK | Should -Be 2
            $sum.WARN | Should -Be 1
            $sum.FAIL | Should -Be 0
            $sum.Total | Should -Be 3
            $sum.GlobalStatus | Should -Be 'WARN'
        }

        It 'passe le statut global en FAIL des un echec' {
            $r = New-AuditReport -HostName 'TEST-PC'
            $s = Add-AuditSection $r -Name 'S'
            Add-AuditTest $s -Name 'a' -Status 'WARN'
            Add-AuditTest $s -Name 'b' -Status 'FAIL'
            (Get-AuditSummary $r).GlobalStatus | Should -Be 'FAIL'
        }

        It 'reste OK quand tout est OK ou INFO' {
            $r = New-AuditReport -HostName 'TEST-PC'
            $s = Add-AuditSection $r -Name 'S'
            Add-AuditTest $s -Name 'a' -Status 'OK'
            Add-AuditTest $s -Name 'b' -Status 'INFO'
            (Get-AuditSummary $r).GlobalStatus | Should -Be 'OK'
        }
    }

    Context 'Export-AuditReportHtml' {
        It 'genere un fichier HTML contenant le titre et le resume' {
            $r = New-AuditReport -HostName 'TEST-PC' -Title 'Rapport <test>'
            $s = Add-AuditSection $r -Name 'Section & 1'
            Add-AuditTest $s -Name 'Test XSS <script>' -Status 'OK' -Message 'msg'
            $out = Join-Path $TestDrive 'rapport.html'
            $null = Export-AuditReportHtml -Report $r -Path $out
            Test-Path $out | Should -Be $true

            $html = Get-Content $out -Raw
            $html | Should -Match '<!DOCTYPE html>'
            $html | Should -Match 'TEST-PC'
            # Les caracteres speciaux HTML doivent etre echappes
            $html | Should -Match '&lt;test&gt;'
            $html | Should -Not -Match '<script>'
        }
    }

    Context 'Get-AuditDefaultThresholds' {
        It 'retourne tous les seuils attendus' {
            $t = Get-AuditDefaultThresholds
            $t.Ram.FailGo | Should -Be 4
            $t.Ram.WarnGo | Should -Be 8
            $t.Disque.FailPct | Should -Be 90
            $t.Disque.WarnPct | Should -Be 75
            $t.Signatures.WarnJours | Should -Be 3
            $t.Signatures.FailJours | Should -Be 7
            $t.Scan.WarnJours | Should -Be 7
            $t.Services.MaxListe | Should -Be 10
        }
    }
}
