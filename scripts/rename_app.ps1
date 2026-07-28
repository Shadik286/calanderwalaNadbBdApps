$f = 'E:\calanderwala\calanderwala\web\index.html'
$c = Get-Content $f -Raw

$fixes = @{
    'Reminder24 (Reminder 24)' = 'Reminder 24'
    'Reminder24 — Reminder 24' = 'Reminder 24'
    '© 2026 Reminder 24 · Reminder24.' = '© 2026 Reminder 24.'
}

foreach ($k in $fixes.Keys) {
    $c = $c -replace [regex]::Escape($k), $fixes[$k]
}

Set-Content -Path $f -Value $c -NoNewline -Encoding UTF8
Write-Host 'Done.'