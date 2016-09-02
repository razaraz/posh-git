
<#
# TODO: Does not work for some commands still like: git log --decorate[=...] and git log -L <n,m:file>
#>
function ParseGitCommandHelpMessage($Command)
{
    Begin
    {
        $AliasRegex = "(-(?<Alias>[a-zA-Z]),? )"
        $ParameterNameRegex = "(--(?<ParameterName>[^\[\s]+))"
        $ArgumentRegex = "(<(?<Argument>.+)>)"
        $AssignedArgRegex = "(?<AssignedArg>\[=$ArgumentRegex\])"
        $DescriptionRegex = "(\s+(?<Description>[^-\s].*))"
        $ParameterRegex = [regex]"^\s*($($AliasRegex)?$($ParameterNameRegex)?)+($AssignedArgRegex| $($ArgumentRegex))?$($DescriptionRegex)?$"
        $MultiLineDescriptionRegex = [regex]"^$DescriptionRegex$"
    }

    Process
    {
        $HelpMessage = git ($Command -split ' ') -h 2| Write-Output
        $Parameters = @()
        $MatchedFirstParam = $false

        foreach($l in $HelpMessage)
        {
            # If we already started matching parameters, check for a possible
            # multi-line description
            if($MatchedFirstParam -and $l -match $MultiLineDescriptionRegex)
            {
                $Parameters[-1].Description = $Matches['Description']
                Write-Debug "Matched multi-line description: $($Matches['Description'])"
            }
            elseif($l -match $ParameterRegex -and ($Matches.Keys -contains 'Alias' -or $Matches.Keys -contains 'ParameterName'))
            {
                Write-Debug "Matched parameter with line: $l"
                $Parameters += New-Object PSObject -Property `
                    @{
                        Alias = $Matches['Alias'];
                        Argument = $Matches['Argument'];
                        ParameterName = $Matches['ParameterName'];
                        Description = $Matches['Description'];
                        AssignedArg = $Matches.Keys -contains 'AssignedArg'
                    } 
                $MatchedFirstParam = $true
            }
        }
        
        $Parameters | Select-Object Alias, ParameterName, AssignedArg, Argument, Description | Write-Output
    }
}

