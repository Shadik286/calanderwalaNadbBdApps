# Fix mojibake in index.html: rebuild the file as UTF-8 with proper characters.
$path = Join-Path $PSScriptRoot '..\web\index.html'
$path = (Resolve-Path $path).Path

$bytes = [System.IO.File]::ReadAllBytes($path)

# Decode the bytes as Windows-1252 (this is how the file is mis-decoded).
$cp1252 = [System.Text.Encoding]::GetEncoding(1252)
$content = $cp1252.GetString($bytes)

# Build the literal mojibake keys as char sequences.
function MkKey($a, $b, $c) {
    return ([char]$a) + ([char]$b) + ([char]$c)
}
function MkKey2($a, $b) {
    return ([char]$a) + ([char]$b)
}

$emDash     = [char]0x2014
$ellipsis   = [char]0x2026
$checkMark  = [char]0x2713
$middleDot  = [char]0x00B7
$copyright  = [char]0x00A9
$rsquo      = [char]0x2019
$ldquo      = [char]0x201C
$rdquo      = [char]0x201D
$nbsp       = [char]0x00A0
$strayC2    = [char]0xC2

$keys = @(
    (MkKey 0xE2 0x80 0x9D),
    (MkKey 0xE2 0x80 0xA6),
    (MkKey 0xE2 0x9C 0x93),
    (MkKey2 0xC2 0xB7),
    (MkKey2 0xC2 0xA9),
    (MkKey 0xE2 0x80 0x99),
    (MkKey 0xE2 0x80 0x9C),
    (MkKey 0xE2 0x80 0x9D)
)
$vals = @(
    $emDash,
    $ellipsis,
    $checkMark,
    $middleDot,
    $copyright,
    $rsquo,
    $ldquo,
    $rdquo
)

for ($i = 0; $i -lt $keys.Count; $i++) {
    $content = $content.Replace($keys[$i], $vals[$i])
}

$content = $content.Replace($nbsp, ' ')
$content = $content.Replace($strayC2, '')

$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($path, $content, $utf8)

Write-Host "Fixed mojibake in: $path"