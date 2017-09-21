<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    Example of how to use this cmdlet
.EXAMPLE
    Another example of how to use this cmdlet
.INPUTS
    Inputs to this cmdlet (if any)
.OUTPUTS
    Output from this cmdlet (if any)
.NOTES
    General notes
.COMPONENT
    The component this cmdlet belongs to
.ROLE
    The role this cmdlet belongs to
.FUNCTIONALITY
    The functionality that best describes this cmdlet
#>
function InteractWith-Variable {
    [CmdletBinding(SupportsShouldProcess = $true,
        ConfirmImpact = 'Low')]
    Param (
        # Input variable - any type
        [Parameter(Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
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
        $Label
    )
    
    begin {
        if ($CreateIfNotExists) {
            
        }

        Write-Debug "Input Object Type: [$($InputObject.GetType())]`n"

        function ShowVariable ($InnerObject, [Switch]$Confirm) {
            if ([String]::IsNullOrWhiteSpace($Label)) {
                Write-Host "Contents of: [$($InnerObject.GetType())] variable" -ForegroundColor DarkCyan
            }
            else {
                Write-Host "Contents of: $Label" -ForegroundColor DarkCyan
            }
            
            if ($InnerObject -is [Object[]]) {
                Write-Debug "Detected Object Array"

                if ($InnerObject.Count -gt 0) {
                    $Index = 1

                    $InnerObject | ForEach-Object {
                        Write-Host "      ($Index)   $_" -ForegroundColor Cyan
                        $Index++
                    }
                }
                else {
                    Write-Host "      ***NO DATA FOUND***" -ForegroundColor Cyan
                }
            }
            else {
                Write-Debug "Detected Object"

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
   `"Add newdatavalue`"                : Adds a new data item
         Example: Add SomethingElse
   `"Replace itemnumber newdatavalue`" : Replaces a data item
         Example: Replace 2 SomethingNew
   `"Delete itemnumber`"               : Deletes a data item
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