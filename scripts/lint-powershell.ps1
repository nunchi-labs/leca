$ErrorActionPreference = 'Stop'
$settings = Join-Path (Get-Location) 'PSScriptAnalyzerSettings.psd1'
$files = @(git -c "safe.directory=$(Get-Location)" ls-files '*.ps1')
$issues = foreach ($file in $files) {
    Invoke-ScriptAnalyzer -Path $file -Settings $settings
}
if ($issues) {
    $issues | Format-Table -AutoSize | Out-String -Width 220 | Write-Output
    exit 1
}
