$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Split-Path -Parent $MyInvocation.MyCommand.Path))
$rootWithSlash = $root.TrimEnd('\') + '\'
$port = 8230

$listener = New-Object System.Net.Sockets.TcpListener([Net.IPAddress]::Loopback, $port)
try { $listener.Start() }
catch {
  Write-Host "Cannot listen on port $port."
  Write-Host $_.Exception.Message
  Write-Host "An instance may already be running - just open http://127.0.0.1:$port/ in your browser."
  exit 1
}

Start-Process "http://127.0.0.1:$port/"
Write-Host "Serving at http://127.0.0.1:$port/"
Write-Host "Keep this window open while playing. Close it to quit."
Write-Host ""

$types = @{
  '.html' = 'text/html; charset=utf-8'
  '.js'   = 'text/javascript'
  '.css'  = 'text/css'
  '.png'  = 'image/png'
  '.jpg'  = 'image/jpeg'
  '.svg'  = 'image/svg+xml'
  '.mp3'  = 'audio/mpeg'
  '.txt'  = 'text/plain; charset=utf-8'
}

while ($true) {
  $client = $listener.AcceptTcpClient()
  try {
    $stream = $client.GetStream()
    $reader = New-Object IO.StreamReader($stream, [Text.Encoding]::ASCII, $false, 8192, $true)
    $requestLine = $reader.ReadLine()
    while ($true) {
      $line = $reader.ReadLine()
      if ($null -eq $line -or $line -eq '') { break }
    }

    $path = '/'
    if ($requestLine -match '^GET\s+(\S+)') { $path = $Matches[1] }
    $path = ($path -split '\?')[0]
    $path = [Uri]::UnescapeDataString($path)
    if ($path -eq '/') { $path = '/index.html' }

    $rel = $path.TrimStart('/') -replace '/', '\'
    $file = [IO.Path]::GetFullPath((Join-Path $root $rel))

    if (($file -eq $root -or $file.StartsWith($rootWithSlash)) -and (Test-Path -LiteralPath $file -PathType Leaf)) {
      $bytes = [IO.File]::ReadAllBytes($file)
      $ext = [IO.Path]::GetExtension($file).ToLower()
      $ctype = $types[$ext]
      if (-not $ctype) { $ctype = 'application/octet-stream' }
      $head = "HTTP/1.1 200 OK`r`nContent-Type: $ctype`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`n`r`n"
      $headBytes = [Text.Encoding]::ASCII.GetBytes($head)
      $stream.Write($headBytes, 0, $headBytes.Length)
      $stream.Write($bytes, 0, $bytes.Length)
    } else {
      $body = [Text.Encoding]::UTF8.GetBytes('404 Not Found')
      $head = "HTTP/1.1 404 Not Found`r`nContent-Type: text/plain`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n"
      $headBytes = [Text.Encoding]::ASCII.GetBytes($head)
      $stream.Write($headBytes, 0, $headBytes.Length)
      $stream.Write($body, 0, $body.Length)
    }
    $stream.Flush()
  } catch { }
  finally { $client.Close() }
}
