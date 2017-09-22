<#
.SYNOPSIS
    Adds a basic console menu system for interacting with a variable that has one or many (array) simple values.
.DESCRIPTION
    Adds a basic console menu system for interacting with a variable that has one or many (array) simple values. It does so
    by detecting the type of the variable and displaying a generic menu system that allows interaction with
    that variable type.    
.EXAMPLE
    InteractWith-Variable -InputObject $(Get-Process).Name -Label "Local Processes"
.EXAMPLE
    InteractWith-Variable -InputObject $(Get-Process)[0].Name -Label "Local Processes"
.INPUTS
    Variable to be interacted with.
.OUTPUTS
    Resulting modified variable.
#>
function InteractWith-Variable {
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

        # Input variable description/label
        [Parameter(Mandatory = $false,
            Position = 1,
            ValueFromPipeline = $false,
            ValueFromPipelineByPropertyName = $false,
            ValueFromRemainingArguments = $false)]
        [string]
        $InformationalHeader
    )
    
    begin {
        Write-Debug "Input Object Type: [$($InputObject.GetType())]`n"
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
                    $Lines = (($InnerObject | Select-Object @{N = "Line"; E = {"($($InnerObject.IndexOf($_) + 1))"}}, @{N = "Data"; E = {$_}} | Sort-Object {$_.Line.Trim('()')} | Format-Table | Out-String) -replace "`r", "" -split "`n") | Where-Object {$_.Trim() -ne ""}

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
                    Write-Host "      $InnerObject" -ForegroundColor Cyan
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
            if ($InnerObject -is [Object[]]) {
                $EditOptions = @"
   Add a new data item:   'Add newdatavalue'
         Example: Add SomethingElse
   Replace a data item:   'Replace itemnumber newdatavalue'
         Example: Replace 2 SomethingNew
    Delete a data item:   'Delete itemnumber'
         Example: Delete 2
"@

                Write-Host "You have the following options to edit:" -ForegroundColor DarkYellow
                Write-Host $EditOptions -ForegroundColor DarkYellow

                do {
                    Write-Host "`rEnter Edit selection from options above: " -NoNewLine -ForegroundColor Yellow
                    $EditSelection = Read-Host
                } while ($EditSelection -notmatch '^(A|Add) \w+$' -and $EditSelection -notmatch '^(R|Replace) \d{1,3} \w+$' -and $EditSelection -notmatch '^(D|Delete) \d{1,3}$')
            }
            else {
                Write-Host "`rEnter new data value: " -NoNewLine -ForegroundColor Yellow
                $EditSelection = Read-Host
                $EditSelection = "Overwrite $EditSelection"
            }

            switch -regex ($EditSelection) {
                '^a' {
                    Write-Debug "Action: Add; New Data: $($EditSelection.Split(' ')[1])"
                    $InnerObject += $EditSelection.Split(' ')[1]
                    break
                }
                '^r' {
                    Write-Debug "Action: Replace; Old Data $($InnerObject[$EditSelection.Split(' ')[1] - 1]); New Data: $($EditSelection.Split(' ')[2])"
                    $InnerObject[$EditSelection.Split(' ')[1] - 1] = $EditSelection.Split(' ')[2]
                    break
                }
                '^d' {
                    Write-Debug "Action: Delete; Old Data: $($InnerObject[$EditSelection.Split(' ')[1] - 1])"
                    $InnerObject = @($InnerObject | Where-Object {$_ -ne $InnerObject[$EditSelection.Split(' ')[1] - 1]})
                    break
                }
                '^o' {
                    Write-Debug "Action: Overwrite; Old Data: $InnerObject; New Data: $($EditSelection.Split(' ')[1])"
                    $InnerObject = $EditSelection.Split(' ')[1]
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