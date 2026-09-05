$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
dart run tool/bootstrap.dart @args
exit $LASTEXITCODE
