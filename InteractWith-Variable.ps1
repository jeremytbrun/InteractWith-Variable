<#
.SYNOPSIS
Adds a basic console menu system for interacting with a variable that has one or many (array) simple values.

.DESCRIPTION
Adds a basic console menu system for interacting with a variable that has one or many (array) simple values. It does so
by detecting the type of the variable and displaying a generic menu system that allows interaction with
that variable type.

.PARAMETER InputObject
Single or multi (array) primitive data type.

.PARAMETER InformationalHeader
Custom informational header for menu system.

.PARAMETER ValidatePattern
Regex pattern to validate input with.

.PARAMETER ValidateScript
Script block to validate input with.

.EXAMPLE
$FinalResults = InteractWith-Variable -InputObject @("Data1","Data2","Data3") -InformationalHeader "Data List"

.EXAMPLE
$FinalResults = InteractWith-Variable -InputObject @("user1@domain.com","user2@domain.com","user3@domain.com") -InformationalHeader "User Emails" -ValidatePattern '^\w+@domain\.com$'

.EXAMPLE
$ValidationScript = {
    Get-ADUser $_.Split('@')[0]
}

$FinalResults = InteractWith-Variable -InputObject @() -InformationalHeader "User Emails" -ValidatePattern '^\w+@domain\.com$' -ValidateScript $ValidationScript

.NOTES
None
#>
Function InteractWith-Variable {
    [CmdletBinding(SupportsShouldProcess = $true,
        ConfirmImpact = 'Low')]
    Param (
        # Input variable - any type
        [Parameter(Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $false,
            ValueFromPipelineByPropertyName = $false,
            ValueFromRemainingArguments = $false)]
        [ValidateNotNull()]
        [Object]
        $InputObject,

        # Menu description/label
        [Parameter(Mandatory = $false,
            Position = 1,
            ValueFromPipeline = $false,
            ValueFromPipelineByPropertyName = $false,
            ValueFromRemainingArguments = $false)]
        [string]
        $InformationalHeader,

        # Regex pattern for input validation
        [Parameter(Mandatory = $false,
            Position = 2,
            ValueFromPipeline = $false,
            ValueFromPipelineByPropertyName = $false,
            ValueFromRemainingArguments = $false)]
        [regex]
        $ValidatePattern,

        # Script block for input validation
        [Parameter(Mandatory = $false,
            Position = 2,
            ValueFromPipeline = $false,
            ValueFromPipelineByPropertyName = $false,
            ValueFromRemainingArguments = $false)]
        [scriptblock]
        $ValidateScript
    )
    
    begin {
        Write-Debug "Input Object Type: [$($InputObject.GetType())]`n"

        if (-not $ValidatePattern) {
            $ValidatePattern = '.*'
        }
        function ShowVariable ($InnerObject, [Switch]$Confirm) {
            Clear-Host

            if ([String]::IsNullOrWhiteSpace($InformationalHeader)) {
                Write-Host "Contents of [$($InnerObject.GetType())] variable" -ForegroundColor DarkCyan
            }
            else {
                Write-Host $InformationalHeader -ForegroundColor DarkCyan
            }
            
            if ($InnerObject -is [Object[]]) {
                if ($InnerObject.Count -gt 0) {
                    $Lines = (($InnerObject | Select-Object @{N = "Line"; E = {"($($InnerObject.IndexOf($_) + 1))"}}, @{N = "Data"; E = {"[$_]"}} | Sort-Object {$_.Line.Trim('()')} | Format-Table | Out-String) -replace "`r", "" -split "`n") | Where-Object {$_.Trim() -ne ""}

                    $Lines | ForEach-Object {
                        Write-Host "      $_" -ForegroundColor Cyan
                    }
                }
                else {
                    Write-Host "      ***NO DATA FOUND***" -ForegroundColor Cyan
                }
            }
            else {
                if (-not [String]::IsNullOrWhiteSpace($InnerObject)) {
                    Write-Host "      [$InnerObject]" -ForegroundColor Cyan
                }
                else {
                    Write-Host "      ***NO DATA FOUND***" -ForegroundColor Cyan
                }
            }

            if ($Confirm) {
                do {
                    Write-Host "`rEnter 'C' to Confirm, or 'E' to Edit contents: " -NoNewLine -ForegroundColor Yellow
                    $ConfirmSelection = Read-Host
                } while ($ConfirmSelection -notmatch '^(C|Confirm)$' -and $ConfirmSelection -notmatch '^(E|Edit)$')

                if ($ConfirmSelection -match '^(E|Edit)$') {
                    ShowVariable -InnerObject $InnerObject

                    if ($InnerObject -is [Object[]]) {
                        $InnerObject = @(EditVariable -InnerObject $InnerObject)
                    }
                    else {
                        $InnerObject = EditVariable -InnerObject $InnerObject
                    }

                    $InnerObject = ShowVariable -InnerObject $InnerObject -Confirm
                }
                else {
                    Write-Host "Finished" -ForegroundColor DarkGreen
                }

                return $InnerObject
            }
        }

        function EditVariable ($InnerObject, [Switch]$Confirm) {
            $ActionPattern = "^(((A|Add) )|((R|Replace) \d{1,3} )|((D|Delete) \d{1,3}$)|((E|Exit)))"
            
            if ($InnerObject -is [Object[]]) {
                $EditOptions = @"
   Add a new data item:   'Add newdatavalue'
         Example: Add SomethingElse
   Replace a data item:   'Replace itemnumber newdatavalue'
         Example: Replace 2 SomethingNew
    Delete a data item:   'Delete itemnumber'
         Example: Delete 3
           Exit editor:   'Exit'
"@

                Write-Host "You have the following options to edit:" -ForegroundColor DarkYellow
                Write-Host $EditOptions -ForegroundColor DarkYellow

                do {
                    Write-Host "`rEnter Edit selection from options above: " -NoNewLine -ForegroundColor Yellow
                    $EditSelection = Read-Host
                } while ($EditSelection -notmatch $ActionPattern)
            }
            else {
                Write-Host "`rEnter new data value: " -NoNewLine -ForegroundColor Yellow
                $EditSelection = Read-Host
                $EditSelection = "Overwrite $EditSelection"
            }

            switch -regex ($EditSelection) {
                '^a' {
                    $NewData = $EditSelection.SubString($EditSelection.IndexOf(' ') + 1)

                    if ($NewData -match $ValidatePattern) {
                        if (-not $ValidateScript -or ($ValidateScript -and ($NewData | Where-Object $ValidateScript))) {
                            if ($NewData -notin $InnerObject) {
                                Write-Debug "Action: Add; New Data: $NewData"
                                $InnerObject += $NewData
                            }
                            else {
                                Write-Debug "Object already contains data: $NewData"
                                Write-Host "Value is already present!" -ForegroundColor DarkCyan
                                Pause
                            }
                        }
                        else {
                            Write-Debug "`"$NewData`" does not pass validation script`n$ValidateScript"
                            Write-Host "`"$NewData`" does not pass validation script`n$ValidateScript" -ForegroundColor DarkCyan
                            Pause
                        }
                    }
                    else {
                        Write-Debug "`"$NewData`" does not match pattern `"$ValidatePattern`""
                        Write-Host "`"$NewData`" does not match pattern `"$ValidatePattern`"" -ForegroundColor DarkCyan
                        Pause
                    }
                    break
                }
                '^r' {
                    $OldData = $InnerObject[$EditSelection.Substring($EditSelection.IndexOf(' ') + 1, 1) - 1]
                    $NewData = $EditSelection.Substring($EditSelection.IndexOf(' ', $EditSelection.IndexOf(' ') + 1) + 1)

                    if ($NewData -match $ValidatePattern) {
                        if (-not $ValidateScript -or ($ValidateScript -and ($NewData | Where-Object $ValidateScript))) {
                            if ($NewData -notin $InnerObject) {
                                Write-Debug "Action: Replace; Old Data $OldData; New Data: $NewData"
                                $InnerObject[$EditSelection.Substring($EditSelection.IndexOf(' ') + 1, 1) - 1] = $NewData
                            }
                            else {
                                Write-Debug "Object already contains data: $NewData"
                                Write-Host "Value is already present!" -ForegroundColor DarkCyan
                                Pause
                            }
                        }
                        else {
                            Write-Debug "`"$NewData`" does not pass validation script`n$ValidateScript"
                            Write-Host "`"$NewData`" does not pass validation script`n$ValidateScript" -ForegroundColor DarkCyan
                            Pause
                        }
                    }
                    else {
                        Write-Debug "`"$NewData`" does not match required pattern `"$ValidatePattern`""
                        Write-Host "`"$NewData`" does not match required pattern `"$ValidatePattern`"" -ForegroundColor DarkCyan
                        Pause
                    }
                    break
                }
                '^d' {
                    $OldData = $InnerObject[$EditSelection.Substring($EditSelection.IndexOf(' ') + 1, 1) - 1]

                    Write-Debug "Action: Delete; Old Data: $OldData"
                    $InnerObject = @($InnerObject | Where-Object {$_ -ne $OldData})
                    break
                }
                '^o' {
                    $NewData = $EditSelection.Substring($EditSelection.IndexOf(' ') + 1)

                    if ($NewData -match $ValidatePattern) {
                        if (-not $ValidateScript -or ($ValidateScript -and ($NewData | Where-Object $ValidateScript))) {
                            Write-Debug "Action: Overwrite; Old Data: $InnerObject; New Data: $NewData"
                            $InnerObject = $NewData
                        }
                        else {
                            Write-Debug "`"$NewData`" does not pass validation script`n$ValidateScript"
                            Write-Host "`"$NewData`" does not pass validation script`n$ValidateScript" -ForegroundColor DarkCyan
                            Pause
                        }
                    }
                    else {
                        Write-Debug "`"$NewData`" does not match required pattern `"$ValidatePattern`""
                        Write-Host "`"$NewData`" does not match required pattern `"$ValidatePattern`"" -ForegroundColor DarkCyan
                        Pause
                    }
                    break
                }
                Default {}
            }

            return $InnerObject
        }
    }
    
    process {
        $FinalResult = ShowVariable -InnerObject $InputObject -Confirm
    }
    
    end {
        return $FinalResult
    }
}