param(
    [string]$ProcessingHome = "",
    [switch]$Verify,
    [switch]$VisualCheck
)
$ErrorActionPreference = "Stop"
if (!$ProcessingHome) {
    $ProcessingHome = Split-Path (Get-Command Processing.exe -ErrorAction Stop).Source
}
$resources = Join-Path $ProcessingHome "app/resources"
$java = Join-Path $resources "jdk/bin/java.exe"
$javac = Join-Path $resources "jdk/bin/javac.exe"
if (!(Test-Path -LiteralPath $java)) {
    throw "Processing's bundled JDK was not found. Supply -ProcessingHome with your Processing installation folder."
}
$project = Split-Path $PSScriptRoot
$build = Join-Path $project ("build/" + [DateTime]::Now.ToString("yyyyMMdd-HHmmss-fff"))
$core = Join-Path $resources "core/library/*"
$app = Join-Path $ProcessingHome "app/*"
Push-Location $project
try {
    & $java "-Dcompose.application.resources.dir=$resources" -cp $app processing.mode.java.Commander "--sketch=$project" "--output=$build" --build
    if ($LASTEXITCODE -ne 0) { throw "Processing compilation failed." }
    $classpath = "$build;$core"
    if ($Verify -or $VisualCheck) {
        & $javac -encoding UTF-8 -cp $classpath -d $build tests/ReplayChecks.java tests/VisualSmoke.java
        if ($LASTEXITCODE -ne 0) { throw "Check compilation failed." }
    }
    if ($Verify) {
        & $java -cp $classpath ReplayChecks (Join-Path $project "data/baseline_positive_20260910_50")
        if ($LASTEXITCODE -ne 0) { throw "Replay verification failed." }
    }
    if ($VisualCheck) {
        & $java -cp $classpath VisualSmoke
        if ($LASTEXITCODE -ne 0) { throw "Visual check failed." }
    }
    if (!$Verify -and !$VisualCheck) {
        & $java -cp $classpath Opinionarium
        if ($LASTEXITCODE -ne 0) { throw "Opinionarium exited with an error." }
    }
} finally {
    Pop-Location
}
