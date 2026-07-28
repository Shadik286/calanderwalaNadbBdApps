$path = 'e:\calanderwala\calanderwala\web\index.html'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$content = [System.IO.File]::ReadAllText($path, $utf8)
$lines = $content -split "`n"
$out = @()
$out += "Line 7: " + $lines[6]
$out += "Line 1307: " + $lines[1306]
$out += "Line 1431: " + $lines[1430]
$out += "Line 1727: " + $lines[1726]
$out += "Line 1728: " + $lines[1727]
$out += "Line 1830: " + $lines[1829]
$out += "Total: " + $lines.Count
$out | Out-File -FilePath 'e:\calanderwala\calanderwala\scripts\inspect_out.txt' -Encoding utf8