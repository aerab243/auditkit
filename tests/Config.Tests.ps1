Describe 'Fichier de configuration' {
    BeforeAll {
        $script:ConfigPath = Join-Path $PSScriptRoot '..\config\auditkit.config.json'
    }

    It 'le fichier de configuration existe' {
        Test-Path $script:ConfigPath | Should -Be $true
    }

    It 'est un JSON valide' {
        $raw = Get-Content $script:ConfigPath -Raw
        { $raw | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'contient tous les seuils utilises par les modules' {
        $c = Get-Content $script:ConfigPath -Raw | ConvertFrom-Json
        $c.seuils.ram.failGo | Should -Not -BeNullOrEmpty
        $c.seuils.ram.warnGo | Should -Not -BeNullOrEmpty
        $c.seuils.disque.failPct | Should -Not -BeNullOrEmpty
        $c.seuils.disque.warnPct | Should -Not -BeNullOrEmpty
        $c.seuils.signatures.warnJours | Should -Not -BeNullOrEmpty
        $c.seuils.signatures.failJours | Should -Not -BeNullOrEmpty
        $c.seuils.scan.warnJours | Should -Not -BeNullOrEmpty
        $c.seuils.services.maxListe | Should -Not -BeNullOrEmpty
    }

    It 'declare les 4 modules du projet' {
        $c = Get-Content $script:ConfigPath -Raw | ConvertFrom-Json
        $c.modules.'Get-SystemInfo.psm1' | Should -Be $true
        $c.modules.'Get-FirewallInfo.psm1' | Should -Be $true
        $c.modules.'Get-AntivirusInfo.psm1' | Should -Be $true
        $c.modules.'Get-ServiceErrors.psm1' | Should -Be $true
    }
}
