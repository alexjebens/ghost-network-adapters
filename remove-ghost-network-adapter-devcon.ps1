param(
    # Path to devcon.exe
    [string]$devconPath = "C:\Program Files (x86)\Windows Kits\8.0\Tools\x64\devcon.exe"
)
<#
.Synopsis
   Helper function to seperate devcon output between device id and name
#>
function Convert-ToDevice {
    [CmdletBinding()]
    [OutputType([PSObject])]
    Param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [string]$DeviceString
    )

    Begin {
    }
    Process {
        #PCI\VEN_1414&DEV_5353&SUBSYS_00000000&REV_00\3&267A616A&1&40: Microsoft Hyper-V S3 Cap
        #[id]: [name]
        $split = $DeviceString.Split(":");
        $id = $null
        $name = $null
        if ($split.Count -gt 1) {
            $name = $split[1].TrimStart(" ")
            $id = $split[0]
            #prefix @ to id, needed by remove
            $id = "@" + $id
        }
    
        return $obj = New-Object PSObject -Property @{
            Name = $name
            Id = $id
        }
    }
    End {
    }
}

# Get the standard Hyper-V Network Adapter name for the current Guest OS.
$version = [System.Environment]::OSVersion.Version

if ($version.Major -eq 6) {
    switch ($version.Minor) {
        #2008R2
        1 {$adapterName = "Microsoft Virtual Machine Bus Network Adapter "}
        #2012 / 2012R2
        {($_ -eq 2) -or ($_ -eq 3)} {$adapterName = "Microsoft Hyper-V Network Adapter "}
        Default { 
            Write-Host "Unknown Windows Minor Version $($version.Minor). Major Version: $($version.Major). Known minor versions are: 1, 2, 3" -ForegroundColor Red
            return 666
        }
    }
}
elseif ($version.Major -eq 10) {
    #Server 2016
    switch ($version.Minor) {
        0 {$adapterName = "Microsoft Hyper-V Network Adapter "}
        Default {
            Write-Host "Unknown Windows Minor Version $($version.Minor). Major Version: $($version.Major). Known minor versions are: 0" -ForegroundColor Red
            return 666
        }
    }
}
else {
    Write-Host "Unknown Windows Major Version $($version.Major). Known major versions are: 6, 10" -ForegroundColor Red
    return 666
}

# You don't want to uninstall an active adapter.
[array]$activeAdapterNames = Get-NetAdapter | Select-Object -ExpandProperty "InterfaceDescription" | Where-Object { $_.StartsWith($adapterName) }

# Array of format:
# PCI\VEN_1414&DEV_5353&SUBSYS_00000000&REV_00\3&267A616A&1&40: Microsoft Hyper-V S3 Cap
$devices = & $devconPath findall *

foreach ($deviceString in $devices) {
    $device = Convert-ToDevice $deviceString
    if ($device.Name -ne $null -and $device.Name.StartsWith($adapterName) -and (! $activeAdapterNames.Contains($device.Name))) {
        Write-Host "Removing adapter $($device.Name)..."
        & $devconPath remove "$($device.Id)"
    }
}
