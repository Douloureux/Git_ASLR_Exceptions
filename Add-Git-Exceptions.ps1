Param (
    [string]$Path
)

Function GetGitPath {
    Param (
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$Path
    )

    if ($Path -eq "") {
        $GFWRegKeyPath = "SOFTWARE\GitForWindows"

        $HKLM = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Default)
        $GFWKey = $HKLM.OpensubKey($GFWRegKeyPath)

        $Path = $GFWKey.GetValue("InstallPath")
    }

    return $Path
}

Function AddExceptions {
    Param ([parameter(Mandatory=$true)][string]$Path)

    $EXEsAll  = Get-ChildItem $Path -Filter "*.exe" -Recurse
    $EXEsRoot = Get-ChildItem $Path -Filter "*.exe"
    $EXEs = $EXEsAll | Where-Object -Property FullName -NotIn ($EXEsRoot | Select-Object -ExpandProperty FullName)

    $IFEOPath = "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options"

    $MitigationAuditOptions = [byte[]]::new(0x10)
    $MitigationOptions      = [byte[]]::new(0x10)
    $MitigationOptions[1]=0x2


    $HKLM = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Default)
    $IFEO = $HKLM.OpensubKey($IFEOPath, $true)


    forEach ($EXE in $EXEs) {
        $EXEPath = $EXE.FullName
        $EXEName = $EXE.Name
        $EXEKey = $IFEO.CreateSubKey($EXEName)

        $EXEKey.SetValue("UseFilter",1, [Microsoft.Win32.RegistryValueKind]::DWord)

        $GUID = New-Guid
        $GUIDString = "{" + $GUID.ToString() + "}"

        $EXEKeyFullPath = $EXEKey.CreateSubKey($GUIDString)
        $EXEKeyFullPath.SetValue("FilterFullPath",         $EXEPath,                [Microsoft.Win32.RegistryValueKind]::String)
        $EXEKeyFullPath.SetValue("MitigationOptions",      $MitigationOptions,      [Microsoft.Win32.RegistryValueKind]::Binary)
        $EXEKeyFullPath.SetValue("MitigationAuditOptions", $MitigationAuditOptions, [Microsoft.Win32.RegistryValueKind]::Binary)
    }
}


$myWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
$myWindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($myWindowsID)
 
$adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator
 
if ($myWindowsPrincipal.IsInRole($adminRole))
   {
   clear-host
   }
else
   {
   $newProcess = new-object System.Diagnostics.ProcessStartInfo "PowerShell";
   $newProcess.Arguments = $myInvocation.MyCommand.Definition;
   $newProcess.Verb = "runas";
   
   [System.Diagnostics.Process]::Start($newProcess);
   exit
   }
 
AddExceptions(GetGitPath($Path))
