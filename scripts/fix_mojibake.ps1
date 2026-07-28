$path = "e:\calanderwala\calanderwala\web\index.html"
$enc = New-Object System.Text.UTF8Encoding $false
$content = [System.IO.File]::ReadAllText($path, $enc)

function Make([int[]]$codes) {
    $sb = New-Object System.Text.StringBuilder
    foreach ($c in $codes) { [void]$sb.Append([char]$c) }
    return $sb.ToString()
}

$tk2 = Make @(195,402,194,160,195,8218,194,167,195,8218,194,179)
$taka = [char]0x09F3

$content = $content.Replace($tk2, $taka)

[System.IO.File]::WriteAllText($path, $content, $enc)
Write-Host ("Length: " + $content.Length)