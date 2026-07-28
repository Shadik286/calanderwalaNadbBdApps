$path = "e:\calanderwala\calanderwala\web\index.html"
$enc = New-Object System.Text.UTF8Encoding $false
$content = [System.IO.File]::ReadAllText($path, $enc)
$lines = $content -split "`n"
for ($lineNo = 1726; $lineNo -lt 1732; $lineNo++) {
    $line = $lines[$lineNo]
    Write-Host "Line $($lineNo+1):"
    for ($i = 0; $i -lt $line.Length; $i++) {
        if ([int][char]$line[$i] -ge 128) {
            Write-Host ("  col $i : " + [int][char]$line[$i])
        }
    }
}