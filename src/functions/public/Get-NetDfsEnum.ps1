Function Get-NetDfsEnum {
    # Wrapper for the NetDfsEnum([string]) method in the lmdfs.h header in NetApi32.dll for Distributed File Systems
    [CmdletBinding()]
    Param (

        [PSCredential]$Credentials,

        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateScript({
                Test-Path -LiteralPath $_ -PathType Container
            })]
        [String[]]$FolderPath

    )

    Process {

        foreach ($ThisFolderPath in $FolderPath) {

            $Split = $ThisFolderPath -split '\\'
            $ServerOrDomain = $Split[0]
            $DfsNamespace = $Split[1]
            $DfsLink = ""
            $Remainder = ""

            # Can't use [NetApi32Dll]::NetDfsGetInfo($ThisFolderPath) because it doesn't work if the provided path is a subfolder of a DFS folder
            # Can't use [NetApi32Dll]::NetDfsGetClientInfo($ThisFolderPath) because it does not return disabled folder targets
            # Instead need to use [NetApi32Dll]::NetDfsEnum($ThisFolderPath) then Where-Object to filter results

            [NetApi32Dll]::NetDfsEnum($ThisFolderPath)

        }

    }

}
