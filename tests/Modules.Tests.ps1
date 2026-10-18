BeforeAll {
    Import-Module "$PSScriptRoot\..\lib\Audit.Framework.psm1" -Force
    Import-Module "$PSScriptRoot\..\lib\modules\Get-SystemInfo.psm1" -Force
    Import-Module "$PSScriptRoot\..\lib\modules\Get-FirewallInfo.psm1" -Force
    Import-Module "$PSScriptRoot\..\lib\modules\Get-AntivirusInfo.psm1" -Force
    Import-Module "$PSScriptRoot\..\lib\modules\Get-ServiceErrors.psm1" -Force
    $script:Thresholds = Get-AuditDefaultThresholds
}

Describe 'Modules d audit' {

    Context 'Get-AuditSystem' {
        It 'ajoute une section Systeme complete' {
            $report = New-AuditReport -HostName 'TEST-PC'
            Get-AuditSystem $report -Thresholds $script:Thresholds
            $report.Sections.Count | Should -Be 1
            $report.Sections[0].Name | Should -Be 'Systeme'
            $report.Sections[0].Tests.Count | Should -BeGreaterThan 3
        }

        It 'respecte un seuil RAM personnalise' {
            $t = Get-AuditDefaultThresholds
            $t.Ram.FailGo = 100000   # aucune machine n atteint ce seuil -> FAIL
            $report = New-AuditReport -HostName 'TEST-PC'
            Get-AuditSystem $report -Thresholds $t
            $ram = $report.Sections[0].Tests | Where-Object { $_.Name -eq 'Memoire RAM' }
            $ram | Should -Not -BeNullOrEmpty
            $ram.Status | Should -Be 'FAIL'
        }

        It 'fonctionne sans seuils explicites (defauts du framework)' {
            $report = New-AuditReport -HostName 'TEST-PC'
            Get-AuditSystem $report
            $report.Sections[0].Tests.Count | Should -BeGreaterThan 3
        }
    }

    Context 'Get-AuditFirewall' {
        It 'ajoute une section Pare-feu avec les profils et le resume' {
            $report = New-AuditReport -HostName 'TEST-PC'
            Get-AuditFirewall $report -Thresholds $script:Thresholds
            $report.Sections.Count | Should -Be 1
            $report.Sections[0].Name | Should -Be 'Pare-feu'
            $report.Sections[0].Tests.Name | Should -Contain 'Resume pare-feu'
        }
    }

    Context 'Get-AuditAntivirus' {
        It 'ajoute une section Antivirus avec l etat du service' {
            $report = New-AuditReport -HostName 'TEST-PC'
            Get-AuditAntivirus $report -Thresholds $script:Thresholds
            $report.Sections.Count | Should -Be 1
            $report.Sections[0].Tests.Name | Should -Contain 'Service Windows Defender'
        }
    }

    Context 'Get-AuditServices' {
        It 'ajoute une section Services avec les automatiques arretes' {
            $report = New-AuditReport -HostName 'TEST-PC'
            Get-AuditServices $report -Thresholds $script:Thresholds
            $report.Sections.Count | Should -Be 1
            $report.Sections[0].Tests.Name | Should -Contain 'Services automatiques en erreur'
        }
    }
}
