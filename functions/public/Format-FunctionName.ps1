# Original from Jeff Hicks / jdhitsolutions
# https://github.com/jdhitsolutions/PSScriptTools

# Modified by TomTom
# based on: PSFunctionTools_v1.0.0 / 28. Feb. 2022

# 220813 TomTom
# Fixed:
#	This Exception must be a warning:
# 		Convert-ScriptToFunction: 
#		Cannot validate argument on parameter 'Name'. 
#		Your function name should have a Verb-Noun naming convention
# 
# Fixed
# 	This Function thinks to know it better and limits the Function Name to two Words, Verb-Noun
# 	Limiting to two words doesn't always work (Powershell itself has many examples)
# 	and paternalism is childish
# 
Function Format-FunctionName {
	[cmdletbinding()]
	[alias("ffn")]
	[Outputtype("String")]
	Param (
		[parameter(Position = 0, Mandatory, ValueFromPipeline,
			HelpMessage = 'What is the name of your function? It should follow the Verb-Noun naming convention.')]
		[ValidateScript( {
			if ($_ -match "^\w+-\w+$") {
				$true
			} else {
				# 220813 TomTom
				# Throw "Your function name should have a Verb-Noun naming convention"
				# Assure that this warning is displayed only once
				If ((Get-Variable -Scope Global -Name VerbNounWarning -EA SilentlyContinue).Value -ne $True) {
					Set-Variable -Scope Global -Name VerbNounWarning -Value $True
					Write-Host "`nWarning!" -ForegroundColor Red
					Write-Host 'Your function name should have a Verb-Noun naming convention' -ForegroundColor Yellow
				}
				$True
			}
		})]
		[string]$Name
	)

	Begin {
		Write-Verbose "[$((Get-Date).TimeofDay) BEGIN] Starting $($myinvocation.mycommand)"
	}
	
	Process {
		Write-Verbose "[$((Get-Date).TimeofDay) PROCESS] Processing $name"
		# 220813 TomTom
		# $split = $name -split "-"
		# "{0}{1}-{2}{3}" -f $split[0][0].ToString().ToUpper(), $split[0].Substring(1).Tolower(), $split[1][0].ToString().ToUpper(), $split[1].Substring(1).ToLower()
		(Get-Culture).TextInfo.ToTitleCase( $Name )
	}

	End {
		Write-Verbose "[$((Get-Date).TimeofDay) END    ] Ending $($myinvocation.mycommand)"
	}
}
