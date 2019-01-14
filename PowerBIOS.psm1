##PowerBIOS - v1.0.0
function Get-PowerBIOSConfigFile {
    <#
    .SYNOPSIS
    Retrieves the PowerBIOS config file path.
    
    .DESCRIPTION
    Joins the LOCALAPPDATA varible together with child path to encapsulate the final resting place of the config file.
    
    .EXAMPLE
    $pathToConfigFile = Get-PowerBIOSConfigFile
    
    .NOTES
    Contact information:
    https://github.com/BradyDonovan/
    #>
    process {
        Join-Path -Path $env:LOCALAPPDATA -ChildPath \PowerBIOS\config.xml
    }
}
function Get-PowerBIOSSettings {
    <#
    .SYNOPSIS
    Retrieves the value stored within the config.xml file.
    
    .DESCRIPTION
    Retrieves the value stored within the config.xml file.
    
    .EXAMPLE
    $settings = Get-PowerBIOSSettings

    .NOTES
    Contact information:
    https://github.com/BradyDonovan/
    #>
    (Import-Clixml (Get-PowerBIOSConfigFile))
}

function Set-PowerBIOSSettings {
    <#
    .SYNOPSIS
    Sets the default backend database server, database name, network library, and SCCM server used to interface with PowerBIOS.
    
    .DESCRIPTION
    Sets the default backend database server, database name, network library, and SCCM server used to interface with PowerBIOS. It will drop a configuraton file to disk in %LOCALAPPDATA%\PowerBIOS\config.xml that will contain all settings.
    
    .EXAMPLE
    Set-PowerBIOSSettings -Server 192.168.0.1 -Database BIOS_Database -NetworkLibrary dbmssocn -SCCMServer 192.168.0.2
    
    .EXAMPLE
    Set-PowerBIOSSettings -DatabaseServer "hostname.of.db.server.domain" -DBName "BIOS_Database" -NetworkLibrary dbmssocn -SiteServer "hostname.of.sccm.server.domain"

    .NOTES
    Contact information:
    https://github.com/BradyDonovan/
    #>
    [Cmdletbinding()]
    param (
        [alias("ServerName")]
        [alias("DatabaseServer")]
        [alias("System")]
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $false, HelpMessage = "Enter either the direct IP or hostname of the database server.")]
        [ValidateNotNullOrEmpty()]
        [string]$Server,
        [alias("DBName")]
        [alias("DatabaseName")]
        [Parameter(Position = 1, Mandatory = $true, ValueFromPipeline = $false, HelpMessage = "Enter the name of the database where your BIOS information is held.")]
        [ValidateNotNullOrEmpty()]
        [string]$Database,
        [Parameter(Position = 2, Mandatory = $true, ValueFromPipeline = $false, HelpMessage = "Enter the type of network libary you would like to use in your connection string.")]
        [ValidateNotNullOrEmpty()]
        [string]$NetworkLibrary,
        [alias("SiteServer")]
        [alias("SMSProvider")]
        [Parameter(Position = 3, Mandatory = $true, ValueFromPipeline = $false, HelpMessage = "Enter the name of the SCCM server that hosts your SMS provider. The SMS Provider is installed on the site (main) server by default.")]
        [ValidateNotNullOrEmpty()]
        [string]$SCCMServer,
        [Parameter(Position = 4, Mandatory = $true, ValueFromPipeline = $false, HelpMessage = "Enter the Site Code associated with the SCCM server entered.")]
        [ValidateNotNullOrEmpty()]
        [string]$SCCMSiteCode

    )
    process {
        IF ((Test-Path -Path (Join-Path -Path $env:LOCALAPPDATA -ChildPath \PowerBIOS\)) -eq $false) {
            Try {
                New-Item -Path (Join-Path -Path $env:LOCALAPPDATA -ChildPath \PowerBIOS\) -ItemType Directory | Out-Null
                $PowerBIOSConfigInfo = @{}
                $PowerBIOSConfigInfo.Add('DatabaseServer', $Server)
                $PowerBIOSConfigInfo.Add('Database', $Database)
                $PowerBIOSConfigInfo.Add('NetworkLibrary', $NetworkLibrary)
                $PowerBIOSConfigInfo.Add('SCCMServer', $SCCMServer)
                $PowerBIOSConfigInfo.Add('SCCMSiteCode', $SCCMSiteCode)
                $PowerBIOSConfigInfo | Export-CliXml (Get-PowerBIOSConfigFile)
            }
            Catch {
                Write-Warning "Could not create PowerBIOS config directory in %localappdata%\PowerBIOS. Check permissions on this directory."
                Return
            }
        }
    }
}
function Remove-PowerBIOSSettings {
    <#
    .SYNOPSIS
    Removes PowerBIOS settings.
    
    .DESCRIPTION
    Removes config.xml at %localappdata%\PowerBIOS\config.xml.
    
    .EXAMPLE
    Remove-PowerBIOSSettings

    .NOTES
    Contact information:
    https://github.com/BradyDonovan/
    #>

    process {
        Remove-Item -Path (Get-PowerBIOSConfigFile) -Force
    }
}
function New-SQLConnection {
    <#
    .SYNOPSIS
    Helper function for creating connections to SQL.

    .DESCRIPTION
    Part of the function set that enables connections to SQL, which then enables the script's ability to perform actions against a SQL database.
    
    .EXAMPLE
    $commandText = "SELECT * FROM dbo.Table"
    $sqlConnection = New-SQLConnection
    $sqlCommand = New-SQLCommand -Connection $sqlConnection -CommandText $commandText
    
    .NOTES
    This is a helper function, and typically won't be interacted with on its own.

    Contact information:
    https://github.com/BradyDonovan/
    #>
    
    process {
        try {
            $connectionSettings = Get-PowerBIOSSettings
            $Server = $connectionSettings.DatabaseServer
            $Database = $connectionSettings.Database
            $NetworkLibrary = $connectionSettings.NetworkLibrary
            $Connection = New-Object System.Data.SQLClient.SQLConnection
            $Connection.ConnectionString = "server='$Server';database='$Database';trusted_connection=true;net='$NetworkLibrary'" 
            $Connection.Open()
            Return $Connection
        }
        catch [System.Data.SqlClient.SqlException] {
            throw "Unable to create connection. Reason: $($_.Exception)"
        }
        catch {
            throw "Non-SQL related error. Reason: $($_.Exception)"
        }
    }
}
function New-SQLCommand {
    <#
    .SYNOPSIS
    Helper function for building System.Data.SQLClient.SQLCommand objects.
    
    .DESCRIPTION
    Builds a System.Data.SQLClient.SQLCommand object, which itself carries the T-SQL of whatever interaction you are running.
    
    .PARAMETER Connection
    Connection object from $connection = New-SQLConnection.
    
    .PARAMETER CommandText
    The T-SQL used in your interaction, e.g. 'INSERT', 'SELECT', 'UPDATE', 'REMOVE'.
    
    .EXAMPLE
    $commandText = "SELECT * FROM dbo.Table"
    $sqlConnection = New-SQLConnection
    $sqlCommand = New-SQLCommand -Connection $sqlConnection -CommandText $commandText
    
    .NOTES
    This is a helper function, and typically won't be interacted with on its own.

    Contact information:
    https://github.com/BradyDonovan/
    #>
    
    param (
        [System.Data.SqlClient.SqlConnection]$Connection,
        [string]$CommandText
    )
    process {
        try {
            $Command = New-Object System.Data.SQLClient.SQLCommand
            $Command.CommandText = $CommandText
            $Command.Connection = $Connection
            Return $Command
        }
        catch {
            throw "Unable to create new SQL command. Reason: $($_.Exception.InnerException.Errors.Message)"
        }
    }
}
function Invoke-SQLInteraction {
    <#
    .SYNOPSIS
    The primary engine that executes all queries against the database.
    
    .DESCRIPTION
    Switches between different execution methods depending on the .CommandText.StartsWith property of a given query. Queries themselves enter as System.Data.SQLClient.SQLCommand objects through the SQLCommand parameter.
    
    .PARAMETER SQLCommand
    System.Data.SQLClient.SQLCommand object that is built via New-SQLCommand.
    
    .EXAMPLE
    $commandReturn = Invoke-SQLInteraction -SQLCommand $sqlCommand
    
    .NOTES
    This is a helper function, and typically won't be interacted with on its own.

    Contact information:
    https://github.com/BradyDonovan/
    #>
    
    param (
        [System.Data.SQLClient.SQLCommand]$SQLCommand
    )
    process {
        IF ($SQLCommand.CommandText.StartsWith('INSERT')) {
            try {
                Return $SQLCommand.ExecuteScalar()
            }
            catch {
                throw "Unable to run SQL statement. Reason: $_"
            }
        }
        IF ($SQLCommand.CommandText.StartsWith('SELECT')) {
            try {
                $Adapter = New-Object System.Data.SqlClient.SqlDataAdapter $SQLCommand
                $Dataset = New-Object System.Data.DataSet
                $Adapter.Fill($Dataset) | Out-Null
                $SQLCommand.Connection.Close()
                $returnTable = [PSCustomObject]@{
                    ID           = $Dataset.Tables.Rows.ID
                    Make         = $Dataset.Tables.Rows.Make
                    Model        = $Dataset.Tables.Rows.Model
                    BIOSPACKAGE  = $Dataset.Tables.Rows.BIOSPACKAGE
                    FLASHBIOSCMD = $Dataset.Tables.Rows.FLASHBIOSCMD
                }
                Return $returnTable
            }
            catch {
                throw "Unable to run $($SQLCommand.CommandText) query. Reason: $_"
            }
        }
        IF ($SQLCommand.CommandText.StartsWith('UPDATE')) {
            try {
                $SQLCommand.ExecuteNonQuery()
                $SQLCommand.Connection.Close()
            }
            catch {
                throw "Unable to run SQL statement. Reason: $_"
            }
        }
        IF ($SQLCommand.CommandText.Contains('DELETE')) {
            try {
                $SQLCommand.ExecuteNonQuery()
                $SQLCommand.Connection.Close()
            }
            catch {
                throw "Unable to run SQL statement. Reason: $_"
            }
        }
    }
}
function New-BIOSCMPackage {
    <#
    .SYNOPSIS
    Creates a new BIOS package in ConfigMgr.
    
    .DESCRIPTION
    Creates a new classic package in ConfigMgr, pointed to BIOS binaries on a fileshare.
    
    .PARAMETER SourcePath
    UNC path specifying where your BIOS update files are. This is PkgSourcePath of SMS_Package. 
    
    .PARAMETER Version
    Version of the BIOS binaries. This is Version of SMS_Package.
    
    .PARAMETER Name
    Name of the package in ConfigMgr. This is Name of SMS_Package.
    
    .EXAMPLE
    $newpackageID = New-BIOSCMPackage -SourcePath $BIOSContentPath -Version $Version
    
    .NOTES
    This is a helper function for New-BIOSPackage.
    SMS_Package server WMI class documentaton here: (https://docs.microsoft.com/en-us/sccm/develop/reference/core/servers/configure/sms_package-server-wmi-class)

    Contact information:
    https://github.com/BradyDonovan/
    #>
    
    param (
        [String]$SourcePath,
        [String]$Version,
        [String]$Name,
        [String]$Manufacturer
    )
    process {
        # Grab connection properties from PowerBIOS config file
        $connectionSettings = Get-PowerBIOSSettings
        $SCCMServer = $connectionSettings.SCCMServer
        $SiteCode = $connectionSettings.SCCMSiteCode

        # Build properties object for SMS_Package object creation
        $objProperties = @{
            Name          = $Name
            PkgSourcePath = $SourcePath
            Version       = $Version
            Manufacturer  = $Manufacturer
        }

        Try {
            # Connect to the SMS Provider
            $cimSession = New-CimSession -ComputerName $SCCMServer -ErrorAction Stop

            Try {
                # Create SMS_Package instance
                $newPackage = New-CimInstance -CimSession $cimSession -Namespace "root\SMS\site_$SiteCode" -ClassName SMS_Package -Property $objProperties -ErrorAction Stop
            }
            Catch {
                # Switch to CM Module if classic package creation via New-CimInstance failed
                Write-Warning "Unable to create new classic package on site server. Reason: $_"
                throw
            }
            Finally {
                # Clean up CimSessions
                Get-CimSession | Remove-CimSession
            }
        }
        Catch {
            IF ($_.Exception.Message -match 'Access is denied.') {
                Write-Warning "Unable to connect to site server via CIM Session. Reason: $_"
            }
            
            Write-Host "INFO: Switching to ConfigMgr PS Module for package creation." -ForegroundColor Cyan

            # Grab current dir to return to
            $currentLocation = Get-Location
            
            Try {
                IF ($null -eq (Get-Module ConfigurationManager)) {
                    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"
                }
            }
            Catch {
                throw "Unable to import ConfigMgr PS Module. Quitting. Error: $_"
            }
            Try {
                IF ($null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
                    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $SCCMServer
                }
            }
            Catch {
                throw "Unable to create PS Drive to $SiteCode."
            }
            Set-Location "$($SiteCode):\"
            $newPackage = New-CMPackage -Name $Name -Version $Version -Path $SourcePath -Manufacturer $Manufacturer
            Set-Location $currentLocation
        }

        # Return the PackageID of the new package
        Return $newPackage.PackageID
    }
}
function New-BIOSPackage {
    <#
    .SYNOPSIS
    Create a new dynamic BIOS package.
    
    .DESCRIPTION
    Interface with both SQL and ConfigMgr to create a new dynamic BIOS update package.
    
    .PARAMETER Make
    Make of the target system.
    
    .PARAMETER Model
    Model of the target system.
    
    .PARAMETER TARGETBIOSDATE
    Enter the target date for the system to reference. If the BIOS date on system is behind what is specified here, the system will update. Enter 'today' (no quotes) to autopopulate with today's date.
    
    .PARAMETER FLASHBIOSCMD
    The command to run to flash the BIOS. This ultimately is used a Run Command line step in the Task Sequence, so specify syntax that will play appropriately with that.
    
    .PARAMETER BIOSContentPath
    A path to where the content for the BIOS package is held. ConfigMgr will use this as the data source on the classic package, so be certain you are specifying something ConfigMgr can access.

    .PARAMETER Version
    A version to specify along for properties of the classic package. Not required.
    
    .EXAMPLE
    New-BIOSPackage -Make Dell -Model "Latitude 7280" -TARGETBIOSDATE "20181115" -FLASHBIOSCMD "FlashBios.cmd" -BIOSContentPath \\path\to\classic\package\source\ -Version "1-10-0"
    
    .NOTES
    Contact info:
    https://github.com/BradyDonovan/
    #>
    param (
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $false, HelpMessage = "Enter the Make of the target system.")]
        [ValidateNotNullOrEmpty()]
        [String]$Make,
        [Parameter(Position = 1, Mandatory = $true, ValueFromPipeline = $false, HelpMessage = "Enter the Model of the target system.")]
        [ValidateNotNullOrEmpty()]
        [String]$Model,
        [Parameter(Position = 2, Mandatory = $true, ValueFromPipeline = $false, HelpMessage = "Enter the target date for the system to reference. If the BIOS date on system is behind what is specified here, the system will update. Enter 'today' (no quotes) to autopopulate with today's date.")]
        [ValidateNotNullOrEmpty()]
        [String]$TARGETBIOSDATE,
        [Parameter(Position = 3, Mandatory = $true, ValueFromPipeline = $false, HelpMessage = "The command to run to flash the BIOS. This ultimately is used a Run Command line step in the Task Sequence, so specify syntax that will play appropriately with that.")]
        [ValidateNotNullOrEmpty()]      
        [String]$FLASHBIOSCMD,
        [Parameter(Position = 4, Mandatory = $true, ValueFromPipeline = $false, HelpMessage = "A path to where the content for the BIOS package is held. ConfigMgr will use this as the data source on the classic package, so be certain you are specifying something ConfigMgr can access.")]
        [ValidateNotNullOrEmpty()]
        [String]$BIOSContentPath,
        [Parameter(Position = 5, Mandatory = $false, ValueFromPipeline = $false, HelpMessage = "A version to specify along for properties of the classic package. Not required.")]
        [ValidateNotNullOrEmpty()]
        [String]$Version
    )

    process {
        # Adding today shortcut for $TARGETBIOSDATE input
        IF ($TARGETBIOSDATE -like 'Today') {
            $TARGETBIOSDATE = Get-Date -Format yyyyMMdd
        }

        # Create new classic package in SCCM & get the package ID returned.
        $nameString = "BIOS UPDATE - $Make $Model"
        $newpackageID = New-BIOSCMPackage -SourcePath $BIOSContentPath -Version $Version -Name $nameString -Manufacturer $Make

        # Build settings hashtable from user input.
        $settings = @{
            TARGETBIOSDATE = $TARGETBIOSDATE
            FLASHBIOSCMD   = $FLASHBIOSCMD
            BIOSPACKAGE    = $newPackageID
        }
        $settingsColumns = $settings.Keys -join ","
        $settingsValues = $settings.Values -join "','"

        Write-Host "`nNew BIOS Package Settings
--------------------------" -ForegroundColor Yellow
        Write-Host "Make: $Make" -ForegroundColor Cyan
        Write-Host "Model: $Model" -ForegroundColor Cyan
        Write-Host "Target BIOS Date: $TARGETBIOSDATE" -ForegroundColor Cyan
        Write-Host "Flash BIOS Cmd: $FLASHBIOSCMD" -ForegroundColor Cyan
        Write-Host "BIOS Content Path: $BIOSContentPath" -ForegroundColor Cyan
        Write-Host "BIOS Version: $Version" -ForegroundColor Cyan
        Write-Host "CM Package ID: $newPackageID" -ForegroundColor Cyan

        #build Y/N prompt
        $message = ""
        $question = "`nProceed with package creation?"
        $choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
        $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes', "Create the BIOS package with the settings listed above."))
        $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No', "Don't create the package, and exit the script."))
        
        #execute prompt
        $decision = $Host.UI.PromptForChoice($message, $question, $choices, 1)

        #if 'y' was entered at prompt, execute INSERT statement
        IF ($decision -eq 0) {
            # Insert a new role row and get the identity result in $identityValue
            $commandText = "INSERT INTO MakeModelIdentity (Make, Model) VALUES ('$Make', '$Model') SELECT @@IDENTITY"
            $sqlConnection = New-SQLConnection
            $sqlCommand = New-SQLCommand -Connection $sqlConnection -CommandText $commandText
            $identityValue = Invoke-SQLInteraction -SQLCommand $sqlCommand

            # Insert the settings row, adding the values as specified in the settings table defined above.
            $commandText = "INSERT INTO Settings (Type, ID, $settingsColumns) VALUES ('M', '$identityValue', '$settingsValues')"
            $sqlConnection = New-SQLConnection
            $sqlCommand = New-SQLCommand -Connection $sqlConnection -CommandText $commandText
            $null = Invoke-SQLInteraction -SQLCommand $sqlCommand # $null = to whatever will prevent output. This might look weird, but the command still runs.    
        }
        #otherwise, quit for 'n'
        ELSE {
            Write-Warning "Action cancelled. Quitting."
            Return
        }
    }
}
function Get-BIOSPackage {
    <#
    .SYNOPSIS
    Gets the details of a dynamic BIOS package.
    
    .DESCRIPTION
    Queries both ConfigMgr and SQL for the details of a BIOS package.

    .PARAMETER packageID
    Specify the packageID of the BIOS package you would like to get details of.
    
    .EXAMPLE
    Get-BIOSPackage -packageID CM000000
    
    .NOTES
    Contact info:
    https://github.com/BradyDonovan/
    #>
    param (
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $false, HelpMessage = "Specify the packageID of the BIOS package you would like to get details of.")]
        [ValidateNotNullOrEmpty()]
        [String]$packageID
    )

    process {
        $commandText = 'SELECT [ID],[Make],[Model],[TARGETBIOSDATE],[FLASHBIOSCMD],[BIOSPACKAGE] FROM dbo.MakeModelSettings WHERE BIOSPACKAGE = @BIOSPACKAGE'
        $sqlConnection = New-SQLConnection
        $sqlCommand = New-SQLCommand -Connection $sqlConnection -CommandText $commandText
        $sqlCommand.Parameters.AddWithValue('@BIOSPACKAGE', $packageID) | Out-Null
        $commandReturn = Invoke-SQLInteraction -SQLCommand $sqlCommand
        Return $commandReturn
    }
}
function Update-BIOSPackage {
    <#
    .SYNOPSIS
    Update a BIOS package.
    
    .DESCRIPTION
    Update a BIOS package and properties underneath in SQL.
    
    .PARAMETER packageID
    Target packageID of the BIOS package to update.
    
    .PARAMETER newPackageID
    New packageID to update to.
    
    .PARAMETER newFlashBiosCMD
    New FlashBiosCmd to set.
    
    .PARAMETER newTargetBiosDate
    New TargetBiosDate to set.
    
    .EXAMPLE
    Update-BIOSPackage -packageID CM000000 -newPackageID CM000001 -newFlashBiosCMD 'powershell.exe FlashBios.ps1' -newTargetBiosDate '20181211'
    
    .NOTES
    Contact information:
    https://github.com/BradyDonovan/
    #>
    
    param (
        [Parameter(Position = 0, Mandatory = $false, ValueFromPipeline = $false, HelpMessage = "Specify the packageID of the BIOS package you would like to target.")]
        [ValidateNotNullOrEmpty()]
        [String]$packageID,
        [Parameter(Position = 0, Mandatory = $false, ValueFromPipeline = $false, HelpMessage = "Specify the packageID of the BIOS package you would like to update.")]
        [String]$newPackageID,
        [Parameter(Position = 0, Mandatory = $false, ValueFromPipeline = $false, HelpMessage = "Specify the new FlashBiosCmd you would like to set.")]
        [String]$newFlashBiosCMD,
        [Parameter(Position = 0, Mandatory = $false, ValueFromPipeline = $false, HelpMessage = "Specify the new TargetBiosDate you would like to set.")]
        [String]$newTargetBiosDate
    )

    process {
        #holding the queries here
        $newBiosPackageQuery = 
        'UPDATE [dbo].[Settings]
        SET [BIOSPACKAGE] = CASE
                                WHEN @NEWBIOSPACKAGE IS NOT NULL THEN @NEWBIOSPACKAGE
                            END
        WHERE (BIOSPACKAGE = @BIOSPACKAGE)'
        
        $newFlashBiosCMDQuery = 
        'UPDATE [dbo].[Settings]
        SET [FLASHBIOSCMD] = CASE
                                WHEN @NEWFLASHBIOSCMD IS NOT NULL THEN @NEWFLASHBIOSCMD
                            END
        WHERE (BIOSPACKAGE = @BIOSPACKAGE)'
        
        $newTargetBiosDateQuery = 
        'UPDATE [dbo].[Settings]
        SET [TARGETBIOSDATE] = CASE
                                WHEN @NEWTARGETBIOSDATE IS NOT NULL THEN @NEWTARGETBIOSDATE
                            END
        WHERE (BIOSPACKAGE = @BIOSPACKAGE)'

        #build queries depending on parameters specified
        IF ($newPackageID -or $newFlashBiosCMD -or $newTargetBiosDate) {
            IF ($newPackageID) {
                $commandText = $newBiosPackageQuery
                $sqlConnection = New-SQLConnection
                $sqlCommand = New-SQLCommand -Connection $sqlConnection -CommandText $commandText
                $sqlCommand.Parameters.AddWithValue('@BIOSPACKAGE', $packageID) | Out-Null
                $sqlCommand.Parameters.AddWithValue('@NEWBIOSPACKAGE', $newPackageID) | Out-Null
            }
            IF ($newFlashBiosCMD) {
                $commandText = $newFlashBiosCMDQuery
                $sqlConnection = New-SQLConnection
                $sqlCommand = New-SQLCommand -Connection $sqlConnection -CommandText $commandText
                $sqlCommand.Parameters.AddWithValue('@BIOSPACKAGE', $packageID) | Out-Null
                $sqlCommand.Parameters.AddWithValue('@FLASHBIOSCMD', $newFlashBiosCMD) | Out-Null
            }
            IF ($newTargetBiosDate) {
                $commandText = $newTargetBiosDateQuery
                $sqlConnection = New-SQLConnection
                $sqlCommand = New-SQLCommand -Connection $sqlConnection -CommandText $commandText
                $sqlCommand.Parameters.AddWithValue('@BIOSPACKAGE', $packageID) | Out-Null
                $sqlCommand.Parameters.AddWithValue('@TARGETBIOSDATE', $newTargetBiosDate) | Out-Null
            }
        }
        ELSE {
            Write-Warning "You didn't specify any parameters. Quitting."
            throw
        }

        #notify of updated BIOS package settings
        Write-Host "`nUpdating $packageID with the following information:
----------------------------------------------------" -ForegroundColor Yellow
        Write-Host "New BIOSPACKAGE: $newPackageID" -ForegroundColor Cyan
        Write-Host "New FLASHBIOSCMD: $Model" -ForegroundColor Cyan
        Write-Host "New TARGETBIOSDATE: $TARGETBIOSDATE" -ForegroundColor Cyan

        #build Y/N prompt
        $message = ""
        $question = "`nProceed with package update?"
        $choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
        $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes', "Update the BIOS package with the settings listed above."))
        $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No', "Don't update the package, and exit the script."))
        
        #execute prompt
        $decision = $Host.UI.PromptForChoice($message, $question, $choices, 1)

        #if 'y' was entered at prompt, execute UPDATE statement(s)
        IF ($decision -eq 0) {
            $commandReturn = Invoke-SQLInteraction -SQLCommand $sqlCommand
            Write-Host "Total # of rows affected: $commandReturn" -ForegroundColor Yellow
        }
        #otherwise, quit for 'n'
        ELSE {
            Write-Warning "Action cancelled. Quitting."
            Return
        }
    }
}
function Remove-BIOSPackage {
    <#
    .SYNOPSIS
    Remove a BIOS package.
    
    .DESCRIPTION
    Remove a BIOS package and all related properties in the database. DOES NOT delete the package from ConfigMgr. Supports targeting by both ConfigMgr package ID and Make & Model.
    
    .PARAMETER packageID
    PackageID to remove. Cannot be used with -Make or -Model.
    
    .PARAMETER Make
    Make to remove. Model needs to be specified. Cannot be used with -packageID.
    
    .PARAMETER Model
    Model to remove. Make needs to be specified. Cannot be used with -packageID.
    
    .EXAMPLE
    Remove-BIOSPackage -packageID 'CM000000'
    Remove-BIOSPackage -Make 'Dell Inc.' -Model 'Precision 5520'
    
    .NOTES
    Contact information:
    https://github.com/BradyDonovan/
    #>
    
    param (
        [Parameter(Position = 0, Mandatory = $false, ValueFromPipeline = $false, HelpMessage = "Specify the packageID of the BIOS package to delete.", ParameterSetName = 'packageID')]
        [ValidateNotNullOrEmpty()]
        [String]$packageID,
        [Parameter(Position = 0, Mandatory = $false, ValueFromPipeline = $false, HelpMessage = "Specify the Make of the BIOS package to delete.", ParameterSetName = 'makeModel')]
        [ValidateNotNullOrEmpty()]
        [String]$Make,
        [Parameter(Position = 1, Mandatory = $false, ValueFromPipeline = $false, HelpMessage = "Specify the Model of the BIOS package to delete.", ParameterSetName = 'makeModel')]
        [ValidateNotNullOrEmpty()]
        [String]$Model
    )

    process {
        IF ($packageID -or ($Make -and $Model)) {
            #declare SQL needed to delete by ConfigMgr packageID
            IF ($packageID) {
                $commandText = 
                'DECLARE @ID AS NVARCHAR(50)
            SET @ID = (SELECT ID FROM [dbo].[Settings] WHERE BIOSPACKAGE = @BIOSPACKAGE)
        
            DELETE FROM [dbo].[Settings]
            WHERE ID = @ID
        
            DELETE FROM [dbo].[MakeModelIdentity]
            WHERE ID = @ID'
                $sqlConnection = New-SQLConnection
                $sqlCommand = New-SQLCommand -Connection $sqlConnection -CommandText $commandText
                $sqlCommand.Parameters.AddWithValue('@BIOSPACKAGE', $packageID) | Out-Null

                #write warning message for confirmation prompt below
                Write-Host "`nRemoving $packageID BIOS package and related entries.
----------------------------------------------------" -ForegroundColor Yellow
            }

            #declare SQL needed to delete by Make & Model
            IF ($Model -or $Make) {
                $commandText = 
                'DECLARE @ID AS NVARCHAR(50)
            SET @ID = (SELECT ID FROM [dbo].[MakeModelIdentity] WHERE Make = @Make AND Model = @Model)

            DELETE FROM [dbo].[Settings]
            WHERE ID = @ID
        
            DELETE FROM [dbo].[MakeModelIdentity]
            WHERE ID = @ID'
                $sqlConnection = New-SQLConnection
                $sqlCommand = New-SQLCommand -Connection $sqlConnection -CommandText $commandText
                $sqlCommand.Parameters.AddWithValue('@Make', $Make) | Out-Null
                $sqlCommand.Parameters.AddWithValue('@Model', $Model) | Out-Null

                #write warning message for confirmation prompt below
                Write-Host "`nRemoving $Make $Model BIOS package and related entries.
----------------------------------------------------" -ForegroundColor Yellow
            }
        }
        ELSE {
            Write-Warning "You didn't specify any parameters. Quitting."
            throw
        }

        #build Y/N prompt
        $message = ""
        $question = "`nProceed with package deletion?"
        $choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
        $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes', "Delete the BIOS package with the settings listed above."))
        $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No', "Don't delete the package, and exit the script."))
        
        #execute prompt
        $decision = $Host.UI.PromptForChoice($message, $question, $choices, 1)

        #if 'y' was entered at prompt, execute DELETE statement(s)
        IF ($decision -eq 0) {
            $commandReturn = Invoke-SQLInteraction -SQLCommand $sqlCommand
            Write-Host "Total # of rows affected: $commandReturn" -ForegroundColor Cyan
        }
        #otherwise, quit for 'n'
        ELSE {
            Write-Warning "Action cancelled. Quitting."
            Return
        }
    }
}
