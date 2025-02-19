<#
.DESCRIPTION
This Script will set the correct Language Settings according to the Param. It does not remove a an entry. It will only Sort the existing keys according to the Input. if a provided parameter language doesn't exist, the script will not add this language.

.EXAMPLE
Set-LanguageSettings.ps1 -LanguageOrder "de-CH,de-DE,en-US"

.NOTES
Author: Thomas Kurth / baseVISION
Date:   19.07.2016

History
    001: First Version
    002: Correct Example in Documentation

#>
[CmdletBinding()]
Param(
    [string]$LanguageOrder
)
## Manual Variable Definition
########################################################
$DefaultLogOutputMode  = "Both"
$DebugPreference = "Continue"

$LogFilePathFolder     = "C:\Windows\Logs\SCCM"
$LogFilePathScriptName = "Set-LanguageSettings"            # This is only used if the filename could not be resolved(IE running in ISE)
$FallbackScriptPath    = "C:\Program Files\baseVISION" # This is only used if the filename could not be resolved(IE running in ISE)


#region Functions
########################################################

function Write-Log {
    <#
    .DESCRIPTION
    Write text to a logfile with the current time.

    .PARAMETER Message
    Specifies the message to log.

    .PARAMETER Type
    Type of Message ("Info","Debug","Warn","Error").

    .PARAMETER OutputMode
    Specifies where the log should be written. Possible values are "Console","LogFile" and "Both".

    .PARAMETER Exception
    You can write an exception object to the log file if there was an exception.

    .EXAMPLE
    Write-Log -Message "Start process XY"

    .NOTES
    This function should be used to log information to console or log file.
    #>
    param(
        [Parameter(Mandatory=$true,Position=1)]
        [String]
        $Message
    ,
        [Parameter(Mandatory=$false)]
        [ValidateSet("Info","Debug","Warn","Error")]
        [String]
        $Type = "Debug"
    ,
        [Parameter(Mandatory=$false)]
        [ValidateSet("Console","LogFile","Both")]
        [String]
        $OutputMode = $DefaultLogOutputMode
    ,
        [Parameter(Mandatory=$false)]
        [Exception]
        $Exception
    )
    
    $DateTimeString = Get-Date -Format "yyyy-MM-dd HH:mm:sszz"
    $Output = ($DateTimeString + "`t" + $Type.ToUpper() + "`t" + $Message)
    
    if ($OutputMode -eq "Console" -OR $OutputMode -eq "Both") {
        if($Type -eq "Error"){
            Write-Error $output
            if($Exception){
               Write-Error ("[" + $Exception.GetType().FullName + "] " + $Exception.Message)
            }
        } elseif($Type -eq "Warn"){
            Write-Warning $output
            if($Exception){
               Write-Warning ("[" + $Exception.GetType().FullName + "] " + $Exception.Message)
            }
        } elseif($Type -eq "Debug"){
            Write-Debug $output
            if($Exception){
               Write-Debug ("[" + $Exception.GetType().FullName + "] " + $Exception.Message)
            }
        } else{
            Write-Verbose $output -Verbose
            if($Exception){
               Write-Verbose ("[" + $Exception.GetType().FullName + "] " + $Exception.Message) -Verbose
            }
        }
    }
    
    if ($OutputMode -eq "LogFile" -OR $OutputMode -eq "Both") {
        try {
            Add-Content $LogFilePath -Value $Output -ErrorAction Stop
            if($Exception){
               Add-Content $LogFilePath -Value ("[" + $Exception.GetType().FullName + "] " + $Exception.Message) -ErrorAction Stop
            }
        } catch {
        }
    }
}
function New-Folder{
    <#
    .DESCRIPTION
    Creates a Folder if it's not existing.

    .PARAMETER Path
    Specifies the path of the new folder.

    .EXAMPLE
    CreateFolder "c:\temp"

    .NOTES
    This function creates a folder if doesn't exist.
    #>
    param(
        [Parameter(Mandatory=$True,Position=1)]
        [string]$Path
    )
	# Check if the folder Exists

	if (Test-Path $Path) {
		Write-Log "Folder: $Path Already Exists"
	} else {
		New-Item -Path $Path -type directory | Out-Null
		Write-Log "Creating $Path"
	}
}
function Set-RegValue {
    <#
    .DESCRIPTION
    Set registry value and create parent key if it is not existing.

    .PARAMETER Path
    Registry Path

    .PARAMETER Name
    Name of the Value

    .PARAMETER Value
    Value to set

    .PARAMETER Type
    Type = Binary, DWord, ExpandString, MultiString, String or QWord

    #>
    param(
        [Parameter(Mandatory=$True)]
        [string]$Path,
        [Parameter(Mandatory=$True)]
        [string]$Name,
        [Parameter(Mandatory=$True)]
        [AllowEmptyString()]
        $Value,
        [Parameter(Mandatory=$True)]
        [string]$Type
    )
    
    try{
        $ErrorActionPreference = 'Stop' # convert all errors to terminating errors


	   if (Test-Path $Path -erroraction silentlycontinue) {      
 
        } else {
            New-Item -Path $Path -Force -ErrorAction Stop
            Write-Log "Registry key $Path created"  
        } 
    
        $null = New-ItemProperty -Path $Path -Name $Name -PropertyType $Type -Value $Value -Force -ErrorAction Stop
        Write-Log "Registry Value $Path, $Name, $Type, $Value set"
    } catch {
        throw "Registry value not set $Path, $Name, $Value, $Type ($($_.Exception))"
    }
}
function Set-ExitMessageRegistry () {
    <#
    .DESCRIPTION
    Write Time and ExitMessage into Registry. This is used by various reporting scripts and applications like ConfigMgr or the OSI Documentation Script.

    .PARAMETER Scriptname
    The Name of the running Script

    .PARAMETER LogfileLocation
    The Path of the Logfile

    .PARAMETER ExitMessage
    The ExitMessage for the current Script. If no Error set it to Success

    #>
    param(
    [Parameter(Mandatory=$True)]
    [string]$Scriptname,
    [Parameter(Mandatory=$True)]
    [string]$LogfileLocation,
    [Parameter(Mandatory=$True)]
    [string]$ExitMessage
    )

    $DateTime = Get-Date –f o
    #The registry Key into which the information gets written must be checked and if not existing created
    if((Test-Path "HKLM:\SOFTWARE\_Custom") -eq $False)
    {
        $null = New-Item -Path "HKLM:\SOFTWARE\_Custom"
    }
    if((Test-Path "HKLM:\SOFTWARE\_Custom\Scripts") -eq $False)
    {
        $null = New-Item -Path "HKLM:\SOFTWARE\_Custom\Scripts"
    }
    try { 
        #The new key gets created and the values written into it
        $null = New-Item -Path "HKLM:\SOFTWARE\_Custom\Scripts\$Scriptname" -Force -ErrorAction Stop
        $null = New-ItemProperty -Path "HKLM:\SOFTWARE\_Custom\Scripts\$Scriptname" -Name "Scriptname" -Value "$Scriptname" -Force -ErrorAction Stop
        $null = New-ItemProperty -Path "HKLM:\SOFTWARE\_Custom\Scripts\$Scriptname" -Name "Time" -Value "$DateTime" -Force -ErrorAction Stop
        $null = New-ItemProperty -Path "HKLM:\SOFTWARE\_Custom\Scripts\$Scriptname" -Name "ExitMessage" -Value "$ExitMessage" -Force -ErrorAction Stop
        $null = New-ItemProperty -Path "HKLM:\SOFTWARE\_Custom\Scripts\$Scriptname" -Name "LogfileLocation" -Value "$LogfileLocation"  -Force -ErrorAction Stop
    } catch { 
        Write-Log "Set-ExitMessageRegistry failed" -Type Error -Exception $_.Exception
        #If the registry keys can not be written the Error Message is returned and the indication which line (therefore which Entry) had the error
        $Error[0].Exception
        $Error[0].InvocationInfo.PositionMessage
    }
}

function Change-LanguageOrder () {
     <#
    .DESCRIPTION
    This function will change the existing Language Order According to the specified Language Order.

    .PARAMETER CurrentValues
    The current Language List (Comma Separated)

    .PARAMETER SpecifiedValues
    The planned Language List (Comma Separated)

    #>
    param(
    [Parameter(Mandatory=$True)]
    [string]$CurrentValues,
    [Parameter(Mandatory=$True)]
    [string]$SpecifiedValues
    )
    $newValue = ""
    foreach($SpecifiedValue in $SpecifiedValues.Split(",")){
        if($CurrentValues -match $SpecifiedValue){
            $CurrentValues = $CurrentValues.Replace($SpecifiedValue,"")
            $newValue = "$newValue,$SpecifiedValue"
        }
    }
    $newValue = "$newValue,$CurrentValues"
    $newValue = $newValue.Replace(",,",",")
    $newValue = $newValue.Replace(",,",",")
    $newValue = $newValue.Trim(',')
    return $newValue
}

function Join-String() {
    param(   
        [string[]] $list,
        [string] $separator = ",",
        [switch] $Collapse
    )
 
    [string] $string = ''
    $first  =  $true
 
    # if called with a list parameter, rather than in a pipeline...
    if ( $list.count -ne 0 ) {
        $input = $list
    }
 
    foreach ( $element in $input  ) {
        #Skip blank elements if -Collapse is specified
        if ( $Collapse -and [string]::IsNullOrEmpty( $element)  ) {
            continue
        }
 
        if ($first) {
            $string = $element
            $first  = $false
        }
        else {
            $string += $separator + $element
        }
    }
  
    return $string
}

Function Set-DefaultNTUserDAT
{
    <#
    .SYNOPSIS
    With this function you can load or unload the default ntuser.dat of the local system

    .PARAMETER Load
    When this parameter is set, the script will load the default ntuser.dat

    .PARAMETER Unload
    When this parameter is set, the script will unload the default ntuser.dat

    .PARAMETER Path
    Specifies a path in the local registry where the default ntuser.dat should be loaded. E.g. HKCU:\DEFAULT
    Default is HKCU:\DEFAULT

    .EXAMPLE
    Set-DefaultNTUserDAT -Load -Path 'HKCU:\_TEMP\DEFAULT'
    Loads the default NTUSER.DAT to the path HKCU\_TEMP\DEFAULT
    

    .EXAMPLE
    Set-DefaultNTuserDAT -Unload
    Unloads the default NTUSER.DAT from HKCU\DEFAULT

    .NOTES
    Author: Dominik Britz
    Link: https://github.com/DominikBritz
    #>
    [CmdletBinding()]
    param
    (
        [switch]$Load,
        [switch]$Unload,
        [string]$Path='HKLM:\DEFAULT'
    )

    If ($Load -and $Unload) 
    {
        throw 'You can not call this function with both Load and Unload parameters'
        
    }

    $CMDPath = $Path -replace ':',''

    If ($Load)
    {
        Start-Process -FilePath REG.EXE -ArgumentList "LOAD $CMDPath C:\Users\Default\NTUSER.DAT"
        $i = 1
        While (-not(Test-Path $Path))
        {
            Write-Log "This is the $i loop while waiting for the default hive to appear"
            Write-Log 'Go to sleep now for 3 seconds'
            Start-Sleep -Seconds 3
            $i++
            if($i -gt 20){
                throw "Timeout Unloading Registry"
            }
        }

        Write-Log 'The default hive is now loaded'
    }

    If ($Unload) 
    {
        0 | Out-Null # http://stackoverflow.com/questions/25438409/reg-unload-and-new-key
        [gc]::Collect()
        Start-Sleep -Seconds 5
        Start-Process -FilePath REG.EXE -ArgumentList "UNLOAD $CMDPath"
        $i = 1

        While (Test-Path $Path)
        {
            Write-Log "This is the $i loop while waiting for the default hive to disappear"
            Write-Log 'Go to sleep now for 3 seconds'
            Start-Sleep -Seconds 3
            $i++
            if($i -gt 20){
                throw "Timeout Unloading Registry"
            }
        }
        Write-Log 'The default hive is now unloaded'
    }
}
#endregion

#region Dynamic Variables and Parameters
########################################################

# Try get actual ScriptName
try{
    $ScriptNameTemp = $MyInvocation.MyCommand.Name
    If($ScriptNameTemp -eq $null -or $ScriptNameTemp -eq ""){
        $ScriptName = $LogFilePathScriptName
    } else {
        $ScriptName = $ScriptNameTemp
    }
} catch {
    $ScriptName = $LogFilePathScriptName
}
$LogFilePath = "$LogFilePathFolder\{0}_{1}.log" -f ($ScriptName -replace ".ps1", ''),(Get-Date -uformat %Y%m%d%H%M)
# Try get actual ScriptPath
try{
    $ScriptPathTemp = Split-Path $MyInvocation.InvocationName
    If($ScriptPathTemp -eq $null -or $ScriptPathTemp -eq ""){
        $ScriptPath = $FallbackScriptPath
    } else {
        $ScriptPath = $ScriptPathTemp
    }
} catch {
    $ScriptPath = $FallbackScriptPath
}

#endregion

#region Initialization
########################################################

New-Folder $LogFilePathFolder
Write-Log "Start Script $Scriptname"

#endregion

#region Main Script
########################################################

try{
    # Change Current User
    $CurrentUserRegPath = 'HKCU:\Control Panel\International\User Profile'
    $CurrentUserValues = Join-String -separator "," -list (Get-ItemPropertyValue -Path $CurrentUserRegPath -Name Languages) 
    Write-Log "Found the following value for the current User ($($env:USERNAME)): $CurrentUserValues"
    $CurrentUserNewValue = Change-LanguageOrder -CurrentValues $CurrentUserValues -SpecifiedValues $LanguageOrder
    Write-Log "Transformed the value for the current User ($($env:USERNAME)) to: $CurrentUserNewValue"
    Set-RegValue -Path $CurrentUserRegPath -Name "Languages" -Value $CurrentUserNewValue.Split(",") -Type MultiString
} catch {
    Write-Log "Error Setting current User Settings" -Type Error -Exception $_.Exception
    Set-ExitMessageRegistry -Scriptname $ScriptName -LogfileLocation $LogFilePath -ExitMessage "Error"
    exit 99001
}

try{
    # Change .Default (LogonScreen)
    $LogonScreenRegPath = 'Registry::\HKEY_USERS\.DEFAULT\Control Panel\International\User Profile'
    $LogonScreenValues = Join-String -separator "," -list (Get-ItemPropertyValue -Path $LogonScreenRegPath -Name Languages) 
    Write-Log "Found the following value for the Welcome Screen: $LogonScreenValues"
    $LogonScreenNewValue = Change-LanguageOrder -CurrentValues $LogonScreenValues -SpecifiedValues $LanguageOrder
    Write-Log "Transformed the value for the Welcome Screen to: $LogonScreenNewValue"
    Set-RegValue -Path $LogonScreenRegPath -Name "Languages" -Value $LogonScreenNewValue.Split(",") -Type MultiString
} catch {
    Write-Log "Error Setting WelcomeScreen Settings" -Type Error -Exception $_.Exception
    Set-ExitMessageRegistry -Scriptname $ScriptName -LogfileLocation $LogFilePath -ExitMessage "Error"
    exit 99002
}

try{
    # Change Default User  
    Set-DefaultNTUserDAT -Load 
    $DefaultUserRegPath = 'HKLM:\Default\Control Panel\International\User Profile'
    $DefaultUserValues = Join-String -separator "," -list (Get-ItemPropertyValue -Path $DefaultUserRegPath -Name Languages) 
    Write-Log "Found the following value for the Default User: $DefaultUserValues"
    $DefaultUserNewValue = Change-LanguageOrder -CurrentValues $DefaultUserValues -SpecifiedValues $LanguageOrder
    Write-Log "Transformed the value for the Default User to: $DefaultUserNewValue"
    Set-RegValue -Path $DefaultUserRegPath -Name "Languages" -Value $DefaultUserNewValue.Split(",") -Type MultiString
    Set-DefaultNTUserDAT -Unload
} catch {
    Write-Log "Error Setting Default User Settings" -Type Error -Exception $_.Exception
    Set-ExitMessageRegistry -Scriptname $ScriptName -LogfileLocation $LogFilePath -ExitMessage "Error"
    exit 99003
}

#endregion

#region Finishing
########################################################
Set-ExitMessageRegistry -Scriptname $ScriptName -LogfileLocation $LogFilePath -ExitMessage "Success"
Write-Log "End Script $Scriptname"

#endregion