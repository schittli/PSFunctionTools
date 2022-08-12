

Function Get-PSFunctionTools-Tom {
    [cmdletbinding()]
    [outputtype("PSFunctionTool")]
    Param()
    Begin {
        Write-Verbose "[$((Get-Date).TimeofDay) BEGIN  ] Starting $($myinvocation.mycommand)"

    } #begin

    Process {
        Write-Verbose "[$((Get-Date).TimeofDay) PROCESS] Getting commands from the PSFunctionTools-Tom module"
        $cmds = Get-Command -Module PSFunctionTools-Tom -CommandType Function | where-object { Test-FunctionName $_.name -Quiet }
        Write-Verbose "[$((Get-Date).TimeofDay) PROCESS] Found $($cmds.count) commands"
        foreach ($cmd in $cmds) {
            [pscustomobject]@{
                PSTypeName    = "PSFunctionTool"
                Name          = $cmd.Name
                Alias         = ($n = Get-Alias -Definition $cmd.name -ErrorAction SilentlyContinue) ? $n.name : $null
                Synopsis      = (Get-Help $cmd.name).Synopsis
                Module        = "PSFunctionTools-Tom"
                ModuleVersion = $cmd.version
            }
        }
    } #process

    End {
        Write-Verbose "[$((Get-Date).TimeofDay) END    ] Ending $($myinvocation.mycommand)"

    } #end

} #close Get-PSFunctionTools-Tom