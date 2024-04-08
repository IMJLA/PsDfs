
Function Get-DfsNetInfo {
    # Wrapper for the NetDfsGetInfo([string]) method in the lmdfs.h header in NetApi32.dll for Distributed File Systems
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

            <#
            # Use the NetDfsGetInfo method instead as it does not filter out disabled folder targets
            # But it does not work
            #>
            #[NetApi32Dll]::NetDfsGetClientInfo($ThisFolderPath)

            #[NetApi32Dll]::NetDfsEnum($ThisFolderPath)

            [NetApi32Dll]::NetDfsGetInfo($ThisFolderPath)

        }

    }

}
function Get-FileShareInfo {
    # Get the corresponding local file path for DFS folder targets (which are UNC paths)
    param (

        [Parameter(ValueFromPipeline)]
        [psobject[]]$ServerAndShare

    )

    process {

        # State 6 notes that the DFS path is online and active
        #$DFS = $DfsNetClientInfo #| Where-Object -FilterScript { $_.State -eq 6 }

        ForEach ($DFS in $ServerAndShare) {

            $SessionParams = @{
                #Credential    = $Credentials
                ComputerName  = $DFS.ServerName
                SessionOption = New-CimSessionOption -Protocol Dcom
            }
            $CimParams = @{
                CimSession = New-CimSession @SessionParams
                ClassName  = 'Win32_Share'
            }

            $ShareName = ($DFS.ShareName -split '\\')[0]
            $ShareLocalPath = Get-CimInstance @CimParams |
            Where-Object Name -EQ $ShareName
            $LocalPath = $DFS.ShareName -replace [regex]::Escape("$ShareName\"), $ShareLocalPath.Path

            $DFS | Add-Member -PassThru -NotePropertyMembers @{
                #DfsPath = $DFS.DfsPath
                FolderTarget = "$($DFS.ServerName)\$($DFS.ShareName)\$($DFS.DfsPath -replace [regex]::Escape($DFS.ShareName))"
                #DfsState = $DFS.State
                #ServerName = $DFS.ServerName
                #ShareName = $DFS.ShareName
                LocalPath    = $LocalPath
            }

        }

    }

}
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

if ([type]'NetApi32Dll') {

Write-Verbose 'TYPE_ALREADY_EXISTS NetApi32Dll.  It is possible that the most recent version is not loaded.  Restart PowerShell to be certain.'

} else {

Add-Type -ErrorAction Stop -TypeDefinition @"


using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Management.Automation;
using System.Runtime.InteropServices;

public class NetApi32Dll
{

    [DllImport("netapi32.dll", SetLastError = true)]
    private static extern int NetApiBufferFree
    (
        IntPtr buffer
    );

    [DllImport("netapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern int NetDfsEnum
    (
        [MarshalAs(UnmanagedType.LPWStr)] string DfsName,
        int Level,
        int PrefMaxLen,
        out IntPtr Buffer,
        [MarshalAs(UnmanagedType.I4)] out int EntriesRead,
        [MarshalAs(UnmanagedType.I4)] ref int ResumeHandle
    );

    [DllImport("netapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern int NetDfsGetClientInfo
    (
        [MarshalAs(UnmanagedType.LPWStr)] string EntryPath,
        [MarshalAs(UnmanagedType.LPWStr)] string ServerName,
        [MarshalAs(UnmanagedType.LPWStr)] string ShareName,
        int Level,
        ref IntPtr Buffer
    );

    [DllImport("netapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern int NetDfsGetInfo
    (
        [MarshalAs(UnmanagedType.LPWStr)] string EntryPath,
        [MarshalAs(UnmanagedType.LPWStr)] string ServerName,
        [MarshalAs(UnmanagedType.LPWStr)] string ShareName,
        int Level,
        ref IntPtr Buffer
    );

    public struct DFS_INFO_3
    {
        [MarshalAs(UnmanagedType.LPWStr)] public string EntryPath;
        [MarshalAs(UnmanagedType.LPWStr)] public string Comment;
        public UInt32 State;
        public UInt32 NumberOfStorages;
        public IntPtr Storages;
    }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct DFS_INFO_6
    {
        [MarshalAs(UnmanagedType.LPWStr)] public string EntryPath;
        [MarshalAs(UnmanagedType.LPWStr)] public string Comment;
        public UInt32 State;
        public UInt64 Timeout;
        public Guid Guid;
        public UInt32 NumberOfStorages;
        public UInt64 MetadataSize;
        public UInt64 PropertyFlags;
        public IntPtr Storages;
    }

    public struct DFS_STORAGE_INFO
    {
        public Int32 State;
        [MarshalAs(UnmanagedType.LPWStr)] public string ServerName;
        [MarshalAs(UnmanagedType.LPWStr)] public string ShareName;
    }
    public struct DFS_STORAGE_INFO_1
    {
        public DFS_STORAGE_STATE State;
        [MarshalAs(UnmanagedType.LPWStr)] public string ServerName;
        [MarshalAs(UnmanagedType.LPWStr)] public string ShareName;
        public DFS_TARGET_PRIORITY TargetPriority;
    }

    public struct DFS_TARGET_PRIORITY
    {
        public DFS_TARGET_PRIORITY_CLASS TargetPriorityClass;
        public UInt16 TargetPriorityRank;
        public UInt16 Reserved;
    }

    public enum DFS_TARGET_PRIORITY_CLASS
    {
        DfsInvalidPriorityClass = -1,
        DfsSiteCostNormalPriorityClass = 0,
        DfsGlobalHighPriorityClass = 1,
        DfsSiteCostHighPriorityClass = 2,
        DfsSiteCostLowPriorityClass = 3,
        DfsGlobalLowPriorityClass = 4
    }

    public enum DFS_STORAGE_STATE
    {
        DFS_STORAGE_STATE_OFFLINE = 1,

        DFS_STORAGE_STATE_ONLINE = 2,

        DFS_STORAGE_STATE_ACTIVE = 4,

        DFS_STORAGE_STATES = 0xF,
    }

    public static List<PSObject> NetDfsEnum(string DfsName)
    {

        IntPtr buffer = new IntPtr();
        int EntriesRead = 0;
        int ResumeHere = 0;
        List<PSObject> returnList = new List<PSObject>();
        const int MAX_PREFERRED_LENGTH = 0xFFFFFFF;
        const int NERR_Success = 0;

        try
        {
            int result = NetDfsEnum(DfsName, 3, MAX_PREFERRED_LENGTH, out buffer, out EntriesRead, ref ResumeHere);

            if (result != NERR_Success)
            {
                string errorMessage = new Win32Exception(Marshal.GetLastWin32Error()).Message;

                throw (new SystemException("NetDfsEnum error. System Error Code: " + result + " - " + errorMessage));
            }
            else
            {

                for (int n = 0; n < EntriesRead; n++)
                {

                    IntPtr DfsPtr = new IntPtr(buffer.ToInt64() + n * Marshal.SizeOf(typeof(DFS_INFO_3)));
                    object dfsObject = Marshal.PtrToStructure(DfsPtr, typeof(DFS_INFO_3));
                    DFS_INFO_3 dfsInfo = (DFS_INFO_3)dfsObject;

                    for (int i = 0; i < dfsInfo.NumberOfStorages; i++)
                    {
                        IntPtr storage = new IntPtr(dfsInfo.Storages.ToInt64() + i * Marshal.SizeOf(typeof(DFS_STORAGE_INFO)));

                        DFS_STORAGE_INFO storageInfo = (DFS_STORAGE_INFO)Marshal.PtrToStructure(storage, typeof(DFS_STORAGE_INFO));

                        PSObject psObject = new PSObject();
                        psObject.Properties.Add(new PSNoteProperty("FullOriginalQueryPath", DfsName));
                        psObject.Properties.Add(new PSNoteProperty("DfsEntryPath", dfsInfo.EntryPath));
                        psObject.Properties.Add(new PSNoteProperty("DfsTarget", System.IO.Path.Combine(new string[] { @"\\", storageInfo.ServerName, storageInfo.ShareName })));
                        psObject.Properties.Add(new PSNoteProperty("DfsTargetState", storageInfo.State));
                        psObject.Properties.Add(new PSNoteProperty("TargetServerName", storageInfo.ServerName));
                        psObject.Properties.Add(new PSNoteProperty("TargetShareName", storageInfo.ShareName));

                        returnList.Add(psObject);
                    }

                }
            }
        }
        finally
        {
            NetApiBufferFree(buffer);
        }
        return returnList;
    }

    public static List<PSObject> NetDfsEnum6(string DfsName)
    {

        IntPtr buffer = new IntPtr();
        int EntriesRead = 0;
        int ResumeHere = 0;
        List<PSObject> returnList = new List<PSObject>();
        const int MAX_PREFERRED_LENGTH = 0xFFFFFFF;
        const int NERR_Success = 0;
        const int Level = 6;

        try
        {
            int result = NetDfsEnum(DfsName, Level, MAX_PREFERRED_LENGTH, out buffer, out EntriesRead, ref ResumeHere);

            if (result != NERR_Success)
            {
                string errorMessage = new Win32Exception(Marshal.GetLastWin32Error()).Message;
                string customErrorMessage = "NetDfsEnum error for '" + DfsName + "'. System Error Code: " + result + " - " + errorMessage;
                throw (new SystemException(customErrorMessage));
            }
            else
            {

                Int64 dfsStart = buffer.ToInt64();
                Type dfsType = typeof(DFS_INFO_6);
                Int64 dfsSize = Marshal.SizeOf(dfsType);

                for (int n = 0; n < EntriesRead; n++)
                {

                    IntPtr dfsPtr = new IntPtr(dfsStart + n * dfsSize);

                    object dfsObject = Marshal.PtrToStructure(dfsPtr, dfsType);
                    DFS_INFO_6 dfsInfo = (DFS_INFO_6)dfsObject;

                    //if (dfsInfo.EntryPath == DfsName) {   // skip link for namespace
                    //    continue;
                    //}

                    Int64 storagesStart = dfsInfo.Storages.ToInt64();
                    Type storageType = typeof(DFS_STORAGE_INFO_1);
                    Int64 storageSize = Marshal.SizeOf(storageType);

                    for (int i = 0; i < dfsInfo.NumberOfStorages; i++)
                    {

                        //Attempted some different properties in case they were mis-mapped the same way that NumberofStorages was
                        //Int64 StartPoint = Convert.ToInt64(dfsInfo.MetadataSize); //System.AccessViolationException
                        //Int64 StartPoint = Convert.ToInt64(dfsInfo.PropertyFlags); //System.AccessViolationException
                        //Int64 StartPoint = Convert.ToInt64(dfsInfo.Timeout); //System.AccessViolationException
                        //IntPtr storagePtr = new IntPtr(StartPoint);

                        IntPtr storagePtr = new IntPtr(storagesStart + i * storageSize);
                        object storageObject = Marshal.PtrToStructure(storagePtr, storageType); //System.NullReferenceException
                        DFS_STORAGE_INFO_1 storageInfo = (DFS_STORAGE_INFO_1)storageObject;
                        PSObject psObject = new PSObject();
                        psObject.Properties.Add(new PSNoteProperty("FullOriginalQueryPath", DfsName));
                        psObject.Properties.Add(new PSNoteProperty("DfsEntryPath", dfsInfo.EntryPath));
                        psObject.Properties.Add(new PSNoteProperty("DfsTarget", System.IO.Path.Combine(new string[] { @"", storageInfo.ServerName, storageInfo.ShareName })));
                        psObject.Properties.Add(new PSNoteProperty("DfsTargetState", storageInfo.State));
                        psObject.Properties.Add(new PSNoteProperty("TargetServerName", storageInfo.ServerName));
                        psObject.Properties.Add(new PSNoteProperty("TargetShareName", storageInfo.ShareName));

                        returnList.Add(psObject);
                    }

                }
            }
        }
        finally
        {
            NetApiBufferFree(buffer);
        }

        return returnList;
    }

    public static List<PSObject> NetDfsGetInfo(string DfsEntryPath)
    {
        IntPtr buffer = new IntPtr();
        List<PSObject> returnList = new List<PSObject>();

        try
        {
            int result = NetDfsGetInfo(DfsEntryPath, null, null, 3, ref buffer);

            if (result != 0)
            {
                throw (new SystemException("Error getting DFS information"));
            }
            else
            {
                DFS_INFO_3 dfsInfo = (DFS_INFO_3)Marshal.PtrToStructure(buffer, typeof(DFS_INFO_3));

                for (int i = 0; i < dfsInfo.NumberOfStorages; i++)
                {
                    IntPtr storage = new IntPtr(dfsInfo.Storages.ToInt64() + i * Marshal.SizeOf(typeof(DFS_STORAGE_INFO)));

                    DFS_STORAGE_INFO storageInfo = (DFS_STORAGE_INFO)Marshal.PtrToStructure(storage, typeof(DFS_STORAGE_INFO));

                    PSObject psObject = new PSObject();

                    psObject.Properties.Add(new PSNoteProperty("State", storageInfo.State));
                    psObject.Properties.Add(new PSNoteProperty("ServerName", storageInfo.ServerName));
                    psObject.Properties.Add(new PSNoteProperty("ShareName", storageInfo.ShareName));

                    returnList.Add(psObject);
                }
            }
        }
        finally
        {
            NetApiBufferFree(buffer);
        }
        return returnList;
    }

    public static List<PSObject> NetDfsGetClientInfo(string DfsPath)
    {
        IntPtr buffer = new IntPtr();
        List<PSObject> returnList = new List<PSObject>();

        try
        {
            int result = NetDfsGetClientInfo(DfsPath, null, null, 3, ref buffer);

            if (result != 0)
            {
                throw (new SystemException("Error getting DFS information"));
            }
            else
            {
                DFS_INFO_3 dfsInfo = (DFS_INFO_3)Marshal.PtrToStructure(buffer, typeof(DFS_INFO_3));

                for (int i = 0; i < dfsInfo.NumberOfStorages; i++)
                {
                    IntPtr storage = new IntPtr(dfsInfo.Storages.ToInt64() + i * Marshal.SizeOf(typeof(DFS_STORAGE_INFO)));

                    DFS_STORAGE_INFO storageInfo = (DFS_STORAGE_INFO)Marshal.PtrToStructure(storage, typeof(DFS_STORAGE_INFO));

                    PSObject psObject = new PSObject();

                    psObject.Properties.Add(new PSNoteProperty("State", storageInfo.State));
                    psObject.Properties.Add(new PSNoteProperty("ServerName", storageInfo.ServerName));
                    psObject.Properties.Add(new PSNoteProperty("ShareName", storageInfo.ShareName));

                    returnList.Add(psObject);
                }
            }
        }
        finally
        {
            NetApiBufferFree(buffer);
        }
        return returnList;
    }

}


"@

}

Export-ModuleMember -Function @('Get-DfsNetInfo','Get-FileShareInfo','Get-NetDfsEnum')














