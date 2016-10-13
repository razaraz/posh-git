
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

function ParseGitParametersAndCommands
{
    Begin
    {
        $PrefixRegex = "^(?:usage: git|         )"
        $ArgumentRegex = "(?:<(?<Argument>[^>]+)>)"

        $ParamOpenRegex = "(?:\[|\()"
        $ParamCloseRegex = "(?:\]|\))"
        $ParameterRegex = "(?:$ParamOpenRegex(?<Parameters>[^\]\)]+)$ParamCloseRegex)"

        $Regex = [regex]"$PrefixRegex(?: (?:$SubCommandRegex|$ParameterRegex|$ArgumentRegex))+$"
    }
}

<#
# TODO: Assumes that parameters are in brackets, and subcommands are not.
#   Should change for having a difference between mandatory parameters,
#   and subcommands. an example is git remote set-url
#>
function ParseGitCommandSubCommands($Command)
{
    Begin
    {
        $PrefixRegex = "^(?:usage:|   or:) git $Command"
        $SubCommandRegex = "(?<SubCommand>[a-z][a-z\-]+)"
        $ArgumentRegex = "(<(?<Argument>[^>]+)>)"

        $ParamOpenRegex = "(?:\[|\()"
        $ParamCloseRegex = "(?:\]|\))"
        $ParameterRegex = "(?:$ParamOpenRegex(?<Parameters>[^\]\)]+)$ParamCloseRegex)"

        $Regex = [regex]"$PrefixRegex(?: (?:$SubCommandRegex|$ParameterRegex|$ArgumentRegex))+"
    }

    Process
    {
        $HelpMessage = git $Command -h 2| Write-Output
        $SubCommands = @()

        foreach($l in $HelpMessage)
        {
            $m = $Regex.Match($l)
            if($m.Success)
            {
                Write-Debug "Found a success with line: $l"
                if($m.Groups['SubCommand'].Success)
                {
                    $SubCommand = $m.Groups['SubCommand'].Value
                    Write-Debug "Found subcommand:$SubCommand"
                    $SubCommands += New-Object PSObject -Property `
                        @{
                            Subcommand = $SubCommand;
                            Arguments = $m.Groups['Argument'].Captures | Select-Object -Expand Value;
                            Parameters = $m.Groups['Parameters'].Captures | Select-Object -Expand Value;
                        }
                }
            }
            else
            {
                Write-Debug "Stopped matching with line: $l"
                break;
            }
        }

        Write-Output $SubCommands
    }
}

