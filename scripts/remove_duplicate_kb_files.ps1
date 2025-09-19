param(
  [string]$Folder = "..\kb-html",
  [string]$ArchiveFolder = "..\archive\kb-duplicates",
  [switch]$WhatIf = $true
)

Write-Host "Scanning folder: $Folder"
$files = Get-ChildItem -Path $Folder -Filter "*.html" -File | Sort-Object Name

# Ensure archive folder exists if not WhatIf
if (-not $WhatIf -and -not (Test-Path $ArchiveFolder)) {
  New-Item -Path $ArchiveFolder -ItemType Directory | Out-Null
}

# Group by (size, title after stripping number prefix)
$grouped = @{}

foreach ($f in $files) {
  $size = $f.Length
  if ($f.Name -match "^\d+\s*-\s*(.+)$") {
    $title = $Matches[1].Trim()
    $key = "$size|$title"
    if (-not $grouped.ContainsKey($key)) {
      $grouped[$key] = @()
    }
    $grouped[$key] += ,$f
  }
}

$moved = 0
foreach ($key in $grouped.Keys) {
  $matches = $grouped[$key]
  if ($matches.Count -le 1) { continue }

  $sorted = $matches | Sort-Object {
    if ($_.Name -match "^(\d+)\s*-\s*") { [int]$Matches[1] } else { 0 }
  }
  $keep = $sorted[-1]
  $toArchive = $sorted[0..($sorted.Count - 2)]

  foreach ($f in $toArchive) {
    $targetPath = Join-Path -Path $ArchiveFolder -ChildPath $f.Name
    if ($WhatIf) {
      Write-Host "Would move '$($f.Name)' to '$ArchiveFolder' (duplicate of '$($keep.Name)')"
    } else {
      Move-Item -Path $f.FullName -Destination $targetPath -Force
      Write-Host "Moved '$($f.Name)' → '$ArchiveFolder'"
      $moved++
    }
  }
}

if (-not $WhatIf) {
  Write-Host "DONE: $moved duplicate files moved to $ArchiveFolder"
} else {
  Write-Host "WHATIF: No files moved. Run with -WhatIf:\$false to actually move."
}