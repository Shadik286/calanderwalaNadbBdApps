$path = 'e:\calanderwala\calanderwala\web\index.html'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$content = [System.IO.File]::ReadAllText($path, $utf8)
$lines = $content -split "`n"
Write-Host ('Line 7: ' + $lines[6])
Write-Host ('Line 1307: ' + $lines[1306])
Write-Host ('Line 1727: ' + $lines[1726])
Write-Host ('Line 1728: ' + $lines[1727])
Write-Host ('Line 1830: ' + $lines[1829])
Write-Host ('Total lines: ' + $lines.Count)