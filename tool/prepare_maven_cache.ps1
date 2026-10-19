param(
    [string]$CacheRoot = (Join-Path $env:USERPROFILE '.gradle/caches/modules-2/files-2.1'),
    [string]$Repository = (Join-Path ([IO.Path]::GetTempPath()) 'dideban-sepehr-maven-cache')
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $CacheRoot -PathType Container)) {
    throw "Gradle artifact cache does not exist: $CacheRoot"
}

# Reuse existing artifacts without changing the global Gradle cache. Hard links
# avoid copying gigabytes when the repository and cache are on the same volume.
$null = New-Item -ItemType Directory -Path $Repository -Force
$count = 0
foreach ($group in Get-ChildItem -LiteralPath $CacheRoot -Directory) {
    foreach ($module in Get-ChildItem -LiteralPath $group.FullName -Directory) {
        foreach ($version in Get-ChildItem -LiteralPath $module.FullName -Directory) {
            $destination = Join-Path $Repository ($group.Name.Replace('.', '/') + '/' + $module.Name + '/' + $version.Name)
            foreach ($artifact in Get-ChildItem -LiteralPath $version.FullName -Recurse -File) {
                if ($artifact.Extension -notin @('.pom', '.module', '.jar', '.aar')) { continue }
                $target = Join-Path $destination $artifact.Name
                if (Test-Path -LiteralPath $target) { continue }
                $null = New-Item -ItemType Directory -Path $destination -Force
                try {
                    $null = New-Item -ItemType HardLink -Path $target -Target $artifact.FullName
                } catch {
                    Copy-Item -LiteralPath $artifact.FullName -Destination $target
                }
                $count++
            }
        }
    }
}

$localProperties = Join-Path $PSScriptRoot '../android/local.properties'
if (-not (Test-Path -LiteralPath $localProperties)) {
    throw 'Run flutter pub get first to create android/local.properties.'
}
$repositoryUri = ([Uri]([IO.Path]::GetFullPath($Repository) + [IO.Path]::DirectorySeparatorChar)).AbsoluteUri
$existing = @(Get-Content -LiteralPath $localProperties | Where-Object { $_ -notmatch '^dideban\.mavenRepository=' })
$existing += "dideban.mavenRepository=$repositoryUri"
Set-Content -LiteralPath $localProperties -Value $existing -Encoding ascii
Write-Output "Prepared $count cached artifacts. Local repository: $repositoryUri"
Write-Output 'Configured android/local.properties. Build again from Flutter or Android Studio.'
