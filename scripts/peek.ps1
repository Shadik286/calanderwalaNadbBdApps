$path = "e:\calanderwala\calanderwala\web\index.html"
$enc = New-Object System.Text.UTF8Encoding $false
$content = [System.IO.File]::ReadAllText($path, $enc)

# Find all lines containing mojibake markers
$lines = $content -split "`n"
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match "Ãƒ|Ã‚|Ã¢|Ã¯Â»") {
        Write-Host ("Line " + ($i+1) + ": " + $lines[$i].Trim())
    }
}