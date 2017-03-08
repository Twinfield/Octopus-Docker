param (
  [Parameter(Mandatory=$true)]
  [string]$OctopusVersion
)

function Execute-Command ($commandPath, $commandArguments)
{
    Write-Host "Executing '$commandPath $commandArguments'"
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $commandPath
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = $commandArguments
    $pinfo.WorkingDirectory = $pwd
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    $p.WaitForExit()

    Write-Host $stdout
    Write-Host $stderr
    Write-Host "Process exited with exit code $($p.ExitCode)"

    [pscustomobject]@{
        stdout = $stdout
        stderr = $stderr
        ExitCode = $p.ExitCode
    }
}

write-host "------------"
write-host "docker --version"
write-host "------------"
& docker --version
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

write-host "------------"
write-host "docker version"
write-host "------------"
& docker version
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
write-host "------------"

# todo: check to make sure there is an msi in the "source" directory

$env:OCTOPUS_VERSION=$OctopusVersion

$maxAttempts = 10
$attemptNumber = 0
while ($true) {
  $attemptNumber = $attemptNumber + 1
  write-host "Attempt #$attemptNumber to build container..."
  $result = Execute-Command "docker" "build --tag octopusdeploy/octopusdeploy-tentacle-prerelease:$OctopusVersion --build-arg OctopusVersion=$OctopusVersion ."
  if ($result.stderr -like "*encountered an error during Start: failure in a Windows system call: This operation returned because the timeout period expired. (0x5b4)*") {
    if ($attemptNumber -gt $maxAttempts) {
      write-host "Giving up after $attemptNumber attempts."
      exit 1
    }
    write-host "Docker failed - retrying..."
  } elseif ($result.ExitCode -ne 0) {
    write-host "Docker failed with an unknown error. Aborting."
    exit $result.ExitCode
  } else {
    exit 0
  }
}

Write-Host "Created image with tag 'octopusdeploy/octopusdeploy-tentacle-prerelease:$OctopusVersion'"