#!/usr/bin/pwsh

param(
  [ValidateSet("server-2022", "server-23h2", "server-2025")] [string]$windowsTargetName,
  [string]$destinationDirectory = 'output',
  [ValidateSet("x64")] [string]$architecture = "x64",
  [ValidateSet("standard", "standard-core", "datacenter", "datacenter-core", "datacenter-azure", "datacenter-azure-core", "azure-stack-hci")] [string]$edition = "datacenter-core",
  [ValidateSet("cs-cz", "de-de", "en-us", "es-es", "fr-fr", "hu-hu", "it-it", "ja-jp", "ko-kr", "nl-nl", "pl-pl", "pt-br", "pt-pt", "ru-ru", "sv-se", "tr-tr", "zh-cn", "zh-tw")]
  [string]$lang = "en-us",
  [switch]$esd,
  [switch]$drivers,
  [switch]$netfx3,
  [ValidatePattern("^\d+$")] [string]$revision
)

Set-StrictMode -Version Latest
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

trap {
  Write-Host "ERROR: $_"
  @(($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR: $1') | Write-Host
  @(($_.Exception.ToString() -split '\r?\n') -replace '^(.*)$','ERROR EXCEPTION: $1') | Write-Host
  Exit 1
}

# ------------------------------
# Log helpers + DISM bucketed progress (no aria2 parsing)
# ------------------------------
$script:reAnsi = [regex]'\x1B\[[0-9;]*[A-Za-z]'
$script:LastPrintedLine = $null
function Write-CleanLine([string]$text) {
  $clean = $script:reAnsi.Replace(($text ?? ''), '')
  if ($clean -eq $script:LastPrintedLine) { return }
  $script:LastPrintedLine = $clean
  Write-Host $clean
}

# DISM buckets (0/10/.../100)
$script:DismLastBucket = -1
$script:DismEveryPercent = if ($env:DISM_PROGRESS_STEP) { [int]$env:DISM_PROGRESS_STEP } else { 10 }
$script:DismNormalizeOutput = if ($env:DISM_PROGRESS_RAW -eq '1') { $false } else { $true }

$script:reArchiving = [regex]'Archiving file data:\s+.*?\((\d+)%\)\s+done'
$script:reBracket   = [regex]'\[\s*[= \-]*\s*(\d+(?:[.,]\d+)?)%\s*[= \-]*\s*\]'
$script:reLoosePct  = [regex]'(^|\s)(\d{1,3})(?:[.,]\d+)?%(\s|$)'

function Get-PercentFromText([string]$text) {
  if ([string]::IsNullOrEmpty($text)) { return $null }
  $t = $script:reAnsi.Replace($text, '')

  $m = $script:reArchiving.Match($t)
  if ($m.Success) { return [int]$m.Groups[1].Value }

  $m = $script:reBracket.Match($t)
  if ($m.Success) {
    $pct = $m.Groups[1].Value -replace ',', '.'
    return [int][math]::Floor([double]$pct)
  }

  $m = $script:reLoosePct.Match($t)
  if ($m.Success) {
    $n = [int]$m.Groups[2].Value
    if ($n -ge 0 -and $n -le 100) { return $n }
  }
  return $null
}

function Reset-ProgressSession { $script:DismLastBucket = -1 }

function Emit-ProgressBucket([int]$pct) {
  $bucket = [int]([math]::Floor($pct / $script:DismEveryPercent) * $script:DismEveryPercent)
  if ($bucket -le $script:DismLastBucket) { return $false }
  $script:DismLastBucket = $bucket

  if ($script:DismNormalizeOutput) { Write-CleanLine ("[DISM] Progress: {0}%" -f $bucket) }
  else { Write-CleanLine ("Progress: {0}%" -f $bucket) }

  if ($bucket -ge 100) {
    Write-CleanLine "[DISM] Progress: 100% (done)"
    Reset-ProgressSession
  }
  return $true
}

function Process-ProgressLine([string]$line) {
  $pct = Get-PercentFromText $line
  if ($pct -eq $null) { return $false }
  if ($script:DismLastBucket -ge 0 -and $pct -lt $script:DismLastBucket) { Reset-ProgressSession }
  [void](Emit-ProgressBucket $pct)
  return $true
}

# ------------------------------
# Basic metadata helpers
# ------------------------------
$arch = "amd64"

function Get-EditionName($e) {
  switch ($e.ToLower()) {
    "standard"              { "SERVERSTANDARD" }
    "standard-core"         { "SERVERSTANDARDCORE" }
    "datacenter"            { "SERVERDATACENTER" }
    "datacenter-core"       { "SERVERDATACENTERCORE" }
    "datacenter-azure"      { "SERVERTURBINE" }
    "datacenter-azure-core" { "SERVERTURBINECORE" }
    "azure-stack-hci"       { "SERVERAZURESTACKHCICOR" }
    default { throw "Unknown Windows Server edition: $e" }
  }
}

function Get-EditionLabel($editionCode) {
  switch ($editionCode) {
    "SERVERSTANDARD"        { "Windows Server Standard" }
    "SERVERSTANDARDCORE"    { "Windows Server Standard, Core" }
    "SERVERDATACENTER"      { "Windows Server Datacenter" }
    "SERVERDATACENTERCORE"  { "Windows Server Datacenter, Core" }
    "SERVERTURBINE"         { "Windows Server Datacenter Azure" }
    "SERVERTURBINECORE"     { "Windows Server Datacenter Azure, Core" }
    "SERVERAZURESTACKHCICOR" { "Azure Stack HCI" }
    default { $editionCode }
  }
}

$dotSystemRevision = if ([string]::IsNullOrWhiteSpace($revision)) { '' } else { ".$revision" }

$TARGETS = @{
  "server-2022" = @{
    search="server 20348$dotSystemRevision $arch"
    edition=(Get-EditionName $edition)
    version="21H2"
    supportedEditions=@("SERVERDATACENTERCORE", "SERVERDATACENTER", "SERVERSTANDARDCORE", "SERVERSTANDARD")
  }
  "server-23h2" = @{
    search="windows server 25398$dotSystemRevision $arch"
    edition=(Get-EditionName $edition)
    version="23H2"
    supportedEditions=@("SERVERDATACENTERCORE", "SERVERAZURESTACKHCICOR")
  }
  "server-2025" = @{
    search="windows server 26100$dotSystemRevision $arch"
    edition=(Get-EditionName $edition)
    version="2025"
    supportedEditions=@("SERVERDATACENTERCORE", "SERVERDATACENTER", "SERVERSTANDARDCORE", "SERVERSTANDARD", "SERVERTURBINECORE", "SERVERTURBINE")
  }
}

function New-QueryString([hashtable]$parameters) {
  @($parameters.GetEnumerator() | ForEach-Object { "$($_.Key)=$([System.Net.WebUtility]::UrlEncode([string]$_.Value))" }) -join '&'
}

function Invoke-UupDumpApi([string]$name, [hashtable]$body) {
  for ($n = 0; $n -lt 15; ++$n) {
    if ($n) {
      Write-CleanLine "Waiting a bit before retrying the uup-dump api ${name} request #$n"
      Start-Sleep -Seconds 10
      Write-CleanLine "Retrying the uup-dump api ${name} request #$n"
    }
    try {
      $qs = if ($body) { '?' + (New-QueryString $body) } else { '' }
      return Invoke-RestMethod -Method Get -Uri ("https://api.uupdump.net/{0}.php{1}" -f $name, $qs)
    } catch {
      Write-CleanLine "WARN: failed the uup-dump api $name request: $_"
    }
  }
  throw "timeout making the uup-dump api $name request"
}

function Get-UupDumpIso($name, $target) {
  Write-CleanLine "Getting the $name metadata"
  $result = Invoke-UupDumpApi listid @{ search = $target.search }

  $result.response.builds.PSObject.Properties
  | ForEach-Object {
      $id = $_.Value.uuid
      $uupDumpUrl = 'https://uupdump.net/selectlang.php?' + (New-QueryString @{ id = $id })
      Write-CleanLine "Processing $name $id ($uupDumpUrl)"
      $_
    }
  | ForEach-Object {
      $id = $_.Value.uuid
      Write-CleanLine "Getting the $name $id langs metadata"
      $result = Invoke-UupDumpApi listlangs @{ id = $id }
      if ($result.response.updateInfo.build -ne $_.Value.build) {
        throw 'for some reason listlangs returned an unexpected build'
      }
      $_.Value | Add-Member -NotePropertyMembers @{ langs = $result.response.langFancyNames; info = $result.response.updateInfo }

      $langs = $_.Value.langs.PSObject.Properties.Name
      $eds = if ($langs -contains $lang) {
        Write-CleanLine "Getting the $name $id editions metadata"
        $result = Invoke-UupDumpApi listeditions @{ id = $id; lang = $lang }
        $result.response.editionFancyNames
      } else {
        Write-CleanLine "Skipping.
L3: Expected langs=$lang.
L4: Got langs=$($langs -join ',')."
        [PSCustomObject]@{}
      }
      $_.Value | Add-Member -NotePropertyMembers @{ editions = $eds }
      $_
    }
  | Where-Object {
      $langs = $_.Value.langs.PSObject.Properties.Name
      $editions = $_.Value.editions.PSObject.Properties.Name
      $res = $true

      if ($langs -notcontains $lang) {
        Write-CleanLine "Skipping. Expected langs=$lang. Got langs=$($langs -join ',')."
        $res = $false
      }

      if ($editions -notcontains $target.edition) {
        Write-CleanLine ("Skipping. Expected editions={0}.
L5: Got editions={1}." -f $target.edition, ($editions -join ','))
        $res = $false
      }

      $res
    }
  | Select-Object -First 1
  | ForEach-Object {
      $id = $_.Value.uuid
      [PSCustomObject]@{
        name               = $name
        title              = $_.Value.title
        build              = $_.Value.build
        id                 = $id
        edition            = $target.edition
        editionLabel       = Get-EditionLabel $target.edition
        version            = $target.version
        virtualEdition     = $target['virtualEdition']
        apiUrl             = 'https://api.uupdump.net/get.php?' + (New-QueryString @{ id = $id; lang = $lang; edition = $target.edition })
        downloadUrl        = 'https://uupdump.net/download.php?' + (New-QueryString @{ id = $id; pack = $lang; edition = $target.edition })
        downloadPackageUrl = 'https://uupdump.net/get.php?' + (New-QueryString @{ id = $id; pack = $lang; edition = $target.edition })
      }
    }
}

function Get-IsoWindowsImages($isoPath) {
  $isoPath = Resolve-Path $isoPath
  Write-CleanLine "Mounting $isoPath"
  $isoImage = Mount-DiskImage $isoPath -PassThru
  try {
    $isoVolume = $isoImage | Get-Volume
    $installPath = if ($esd) { "$($isoVolume.DriveLetter):\sources\install.esd" } else { "$($isoVolume.DriveLetter):\sources\install.wim" }
    Write-CleanLine "Getting Windows images from $installPath"
    Get-WindowsImage -ImagePath $installPath | ForEach-Object {
      $image = Get-WindowsImage -ImagePath $installPath -Index $_.ImageIndex
      [PSCustomObject]@{ index = $image.ImageIndex; name = $image.ImageName; version = $image.Version }
    }
  }
  finally {
    Write-CleanLine "Dismounting $isoPath"
    Dismount-DiskImage $isoPath | Out-Null
  }
}

# ------------------------------
# Patch uup_download_windows.cmd with sed - quiet aria2 flags
# ------------------------------
function Patch-Aria2-Flags {
  param([string]$CmdPath)
  if (-not (Test-Path $CmdPath)) { return }

  $sed = Get-Command sed -ErrorAction SilentlyContinue
  if ($sed) {
    Write-CleanLine "Patching aria2 flags in $CmdPath using sed."
    # Remove conflicting flags first
    & $sed.Path -ri 's/\s--console-log-level=\w+\b//g; s/\s--summary-interval=\d+\b//g; s/\s--download-result=\w+\b//g; s/\s--enable-color=\w+\b//g; s/\s-(q|quiet(=\w+)?)\b//g' $CmdPath
    # Inject quiet set right after "%aria2%"
    & $sed.Path -ri 's@("%aria2%"\s+)@\1--quiet=true --console-log-level=error --summary-interval=0 --download-result=hide --enable-color=false @g' $CmdPath
    return
  }

  # Fallback: PowerShell regex (preserves UTF-16LE)
  Write-CleanLine "sed not found. Patching aria2 flags in $CmdPath using PowerShell fallback."
  $bytes   = [System.IO.File]::ReadAllBytes($CmdPath)
  $content = [System.Text.Encoding]::Unicode.GetString($bytes)

  $patternsToRemove = @(
    '\s--console-log-level=\w+\b',
    '\s--summary-interval=\d+\b',
    '\s--download-result=\w+\b',
    '\s--enable-color=\w+\b',
    '\s-(?:q|quiet(?:=\w+)?)\b'
  )
  foreach ($re in $patternsToRemove) {
    $content = [regex]::Replace($content, $re, '', 'IgnoreCase, CultureInvariant')
  }
  $inject = '--quiet=true --console-log-level=error --summary-interval=0 --download-result=hide --enable-color=false '
  $content = [regex]::Replace($content, '("%aria2%"\s+)', ('$1' + $inject), 'IgnoreCase, CultureInvariant')

  $newBytes = [System.Text.Encoding]::Unicode.GetBytes($content)
  [System.IO.File]::WriteAllBytes($CmdPath, $newBytes)
}

function Get-WindowsIso($name, $destinationDirectory) {
  $target = $TARGETS[$name]
  if (-not $target) { throw "Unknown Windows Server target: $name" }
  if ($target.supportedEditions -notcontains $target.edition) {
    $supported = $target.supportedEditions | ForEach-Object { Get-EditionLabel $_ }
    throw "Edition '$(Get-EditionLabel $target.edition)' is not available for $name. Supported: $($supported -join ', ')."
  }

  $iso = Get-UupDumpIso $name $target
  if (-not $iso) { throw "Can't find UUP for $name ($($target.search)), lang=$lang, edition=$($target.edition)." }

  $isoHasEdition    = $iso.PSObject.Properties.Name -contains 'edition' -and $iso.edition
  $hasVirtualMember = $iso.PSObject.Properties.Name -contains 'virtualEdition' -and $iso.virtualEdition
  $effectiveEdition = if ($isoHasEdition) { Get-EditionLabel $iso.edition } else { Get-EditionLabel $target.edition }
  $verbuild = if ($iso.version) { $iso.version } elseif ($iso.title -match 'version\s*([^\s\(]+)') { $matches[1] } else { $iso.build }

  $buildDirectory               = "$destinationDirectory/$name"
  $destinationIsoPath           = "$buildDirectory.iso"
  $destinationIsoMetadataPath   = "$destinationIsoPath.json"
  $destinationIsoChecksumPath   = "$destinationIsoPath.sha256.txt"

  if (Test-Path $buildDirectory) { Remove-Item -Force -Recurse $buildDirectory | Out-Null }
  New-Item -ItemType Directory -Force $buildDirectory | Out-Null

  $edn = if ($hasVirtualMember) { $iso.virtualEdition } else { $effectiveEdition }
  Write-CleanLine $edn
  $title = "$name $edn $($iso.build)"

  Write-CleanLine "Downloading the UUP dump download package for $title from $($iso.downloadPackageUrl)"
  $downloadPackageBody = if ($hasVirtualMember) { @{ autodl=3; updates=1; cleanup=1; 'virtualEditions[]'=$iso.virtualEdition } } else { @{ autodl=2; updates=1; cleanup=1 } }
  Invoke-WebRequest -Method Post -Uri $iso.downloadPackageUrl -Body $downloadPackageBody -OutFile "$buildDirectory.zip" | Out-Null
  Expand-Archive "$buildDirectory.zip" $buildDirectory

  $convertConfig = (Get-Content $buildDirectory/ConvertConfig.ini) `
    -replace '^(AutoExit\s*)=.*','$1=1' `
    -replace '^(ResetBase\s*)=.*','$1=1' `
    -replace '^(Cleanup\s*)=.*','$1=1'

  $tag = ""
  if ($esd) { $convertConfig = $convertConfig -replace '^(wim2esd\s*)=.*', '$1=1'; $tag += ".E" }
  if ($drivers) {
    $convertConfig = $convertConfig -replace '^(AddDrivers\s*)=.*', '$1=1'
    $tag += ".D"
    Write-CleanLine "Copy Dell drivers to $buildDirectory directory"
    Copy-Item -Path Drivers -Destination $buildDirectory/Drivers -Recurse
  }
  if ($netfx3) { $convertConfig = $convertConfig -replace '^(NetFx3\s*)=.*', '$1=1'; $tag += ".N" }
  if ($hasVirtualMember) {
    $convertConfig = $convertConfig `
      -replace '^(StartVirtual\s*)=.*','$1=1' `
      -replace '^(vDeleteSource\s*)=.*','$1=1' `
      -replace '^(vAutoEditions\s*)=.*',"`$1=$($iso.virtualEdition)"
  }
  Set-Content -Encoding ascii -Path $buildDirectory/ConvertConfig.ini -Value $convertConfig

  Write-CleanLine "Creating the $title iso file inside the $buildDirectory directory"
  Push-Location $buildDirectory

  # Patch aria2 flags in the batch before running it
  Patch-Aria2-Flags -CmdPath (Join-Path $buildDirectory 'uup_download_windows.cmd')

  # Raw log path
  $rawLog = Join-Path $env:RUNNER_TEMP "uup_dism_aria2_raw.log"

  choco install aria2 /y *> $null

  & {
    powershell cmd /c uup_download_windows.cmd 2>&1 |
      Tee-Object -FilePath $rawLog |
      ForEach-Object {
        $raw = [string]$_
        if ([string]::IsNullOrEmpty($raw)) { return }
        foreach ($crChunk in ($raw -split "`r")) {
          foreach ($line in ($crChunk -split "`n")) {
            if ($line -eq $null) { continue }
            # DISM progress buckets; aria2 is not parsed here
            if (-not (Process-ProgressLine $line)) {
              if ($line -match '^\s*(Mounting image|Saving image|Applying image|Exporting image|Unmounting image|Deployment Image Servicing and Management tool|^=== )') {
                Reset-ProgressSession
              }
              Write-CleanLine $line
            }
          }
        }
      }
  }

  if ($LASTEXITCODE) {
    Write-Host "::warning title=Build failed::Dumping last 1500 raw log lines"
    Get-Content $rawLog -Tail 1500 | Write-Host
    throw "uup_download_windows.cmd failed with exit code $LASTEXITCODE"
  }

  Pop-Location

  $sourceIsoPath = Resolve-Path $buildDirectory/*.iso
  $IsoName = Split-Path $sourceIsoPath -leaf

  Write-CleanLine "Getting the $sourceIsoPath checksum"
  $isoChecksum = (Get-FileHash -Algorithm SHA256 $sourceIsoPath).Hash.ToLowerInvariant()
  Set-Content -Encoding ascii -NoNewline -Path $destinationIsoChecksumPath -Value $isoChecksum

  $windowsImages = Get-IsoWindowsImages $sourceIsoPath
  Set-Content -Path $destinationIsoMetadataPath -Value (
    ([PSCustomObject]@{
      name    = $name
      title   = $iso.title
      build   = $iso.build
      version = $verbuild
      edition = $iso.edition
      editionLabel = $iso.editionLabel
      tags    = $tag
      checksum = $isoChecksum
      images  = @($windowsImages)
      uupDump = @{
        id                 = $iso.id
        apiUrl             = $iso.apiUrl
        downloadUrl        = $iso.downloadUrl
        downloadPackageUrl = $iso.downloadPackageUrl
      }
    } | ConvertTo-Json -Depth 99) -replace '\\u0026','&'
  )

  Write-CleanLine "Moving the created $sourceIsoPath to $destinationDirectory/$IsoName"
  Move-Item -Force $sourceIsoPath "$destinationDirectory/$IsoName"

  Write-Output "ISO_NAME=$IsoName" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
  Write-CleanLine 'All Done.'
}

Get-WindowsIso $windowsTargetName $destinationDirectory
