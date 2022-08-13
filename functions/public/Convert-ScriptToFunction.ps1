# Original from Jeff Hicks / jdhitsolutions
# https://github.com/jdhitsolutions/PSScriptTools

# Modified by TomTom
# based on: PSFunctionTools_v1.0.0 / 28. Feb. 2022
#	
# 220812
# Added:
#	• -OutputFileOrSuffix 'filename'
#		The generated content will be written in UTF8 *with* BOM to OutputFileOrSuffix
#		Example:
#			Convert-ScriptToFunction -Path 'c:\Temp\Source.ps1'-name GitLab-RestAPI -OutputFile 'c:\Temp\Source-Func.ps1' -Verbose
#			# Creates: c:\Temp\Source-Func.ps1
#
#	• -OutputFileOrSuffix 'suffix'
#		The generated content will be written in UTF8 *with* BOM
#		Example:
#			Convert-ScriptToFunction -Path 'c:\Temp\Source.ps1'-name GitLab-RestAPI -OutputFile '-Func' -Verbose
#			# Creates: c:\Temp\Source-Func.ps1
# 
# 220813 TomTom
# Fixed:
#	This Exception must be a warning:
# 		Convert-ScriptToFunction: 
#		Cannot validate argument on parameter 'Name'. 
#		Your function name should have a Verb-Noun naming convention
# 

# Sehr schnell, optional mit der expliziten Codierung
# Write Text for a File
# 220812: Neu: -WriteBOM
Function Write-Content-Fast() {
	Param (
		[Parameter(Position = 0, Mandatory)]
		$LiteralPath,
		[Parameter(Position = 1, Mandatory, ValueFromPipeline)]
		$Content,
		[Parameter(Position = 2)]
		[Text.Encoding]$Encoding,
		[Switch]$WriteBOM,
		[Switch]$Overwrite = $True
	)

	Begin {
		If (Test-Path -LiteralPath $LiteralPath) {
			If ($Overwrite) {
				Remove-Item -Force -LiteralPath $LiteralPath
			} Else {
				Return
			}
		}
	}

	Process {
		If ($Encoding -eq [Text.Encoding]::UTF8) {
			If ($WriteBOM) {
				$Encoding = [System.Text.UTF8Encoding]::new($true)
			} Else {
				$Encoding = [System.Text.UTF8Encoding]::new($false)
			}
		}
		
		Switch ($Content.GetType()) {
			([Object[]]) {
				If ($Encoding) {
					[System.IO.File]::WriteAllLines($LiteralPath, $Content, $Encoding)
				} Else {
					[System.IO.File]::WriteAllLines($LiteralPath, $Content)
				}
			}
			([String]) {
				If ($Encoding) {
					[System.IO.File]::WriteAllText($LiteralPath, $Content, $Encoding)
				} Else {
					[System.IO.File]::WriteAllText($LiteralPath, $Content)
				}
			}
		}
	}

	End {}
}


# Ergänzt einen Dateinamen mit einem Suffix
Function Filename-Add-Suffix($FileName, $Suffix) {
	[IO.Path]::Combine( `
		[IO.Path]::GetDirectoryName($FileName), `
		[IO.Path]::GetFileNameWithoutExtension($FileName) + $Suffix + [IO.path]::GetExtension($FileName)
	)
}


Function Convert-ScriptToFunction {
	[cmdletbinding()]
	[Outputtype("System.String")]
	[alias('csf')]
	Param(
		[Parameter(Position = 0, Mandatory, ValueFromPipelineByPropertyName,
		 HelpMessage = "Enter the path to your PowerShell script file.")]
		[ValidateScript({Test-Path $_ })]
		[ValidatePattern("\.ps1$")]
		[string]$Path,

		[Parameter(Position = 1, Mandatory, ValueFromPipelineByPropertyName,
		HelpMessage = "What is the name of your new function?")]
		[ValidateScript({
		if ($_ -match "^\w+-\w+$") {
			$True
		} else {
			# 220813 TomTom
			# Throw "Your function name should have a Verb-Noun naming convention"
			# Assure that this warning is displayed only once
			If ((Get-Variable -Scope Global -Name VerbNounWarning -EA SilentlyContinue).Value -ne $True) {
				Set-Variable -Scope Global -Name VerbNounWarning -Value $True
				Write-Host "`nWarning!" -ForegroundColor Red
				Write-Host 'Your function name should have a Verb-Noun naming convention' -ForegroundColor Yellow
				Start-Sleep -MilliS 2500
			}
			$True
		}
		})]
		[string]$Name,

		[Parameter(ValueFromPipelineByPropertyName,
			HelpMessage = "Specify an optional alias for your new function. You can define multiple aliases separated by commas.")]
		[ValidateNotNullOrEmpty()]
		[string[]]$Alias,
		
		[String]$OutputFileOrSuffix
	)
   
	DynamicParam {
		<# If running this function in the PowerShell ISE or VS Code,
			define a ToEditor switch parameter
		#>
		If ($host.name -match "ISE|Code") {
			$paramDictionary = New-Object -Type System.Management.Automation.RuntimeDefinedParameterDictionary

			# Defining parameter attributes
			$attributeCollection = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute]
			$attributes = New-Object System.Management.Automation.ParameterAttribute
			$attributes.ParameterSetName = '__AllParameterSets'
			$attributeCollection.Add($attributes)

			# Defining the runtime parameter
			$dynParam1 = New-Object -Type System.Management.Automation.RuntimeDefinedParameter('ToEditor', [Switch], $attributeCollection)
			$paramDictionary.Add('ToEditor', $dynParam1)
			return $paramDictionary
		}
	}
   
	Begin {
		Write-Verbose "Starting $($MyInvocation.MyCommand)"
		Write-Verbose "Initializing"
		$new = [System.Collections.Generic.list[string]]::new()
	}
   
	Process {
		#normalize
		$Path = Convert-Path $path
		$Name = Format-FunctionName $Name

		Write-Verbose "Processing $path"
		$AST = _getAST $path

		if ($ast.extent) {
			Write-Verbose "Getting any comment based help"
			$ch = $astTokens | Where-Object { $_.kind -eq 'comment' -AND $_.text -match '\.synopsis' }

			if ($ast.ScriptRequirements) {
				Write-Verbose "Adding script requirements"
				if($ast.ScriptRequirements.RequiredPSVersion) {
					$new.Add("#requires -version $($ast.ScriptRequirements.RequiredPSVersion.ToString())")
				}
				if ($ast.ScriptRequirements.RequiredModules) {
					Foreach ($m in $ast.ScriptRequirements.RequiredModules) {
						#test for version requirements
						$ver = $m.psobject.properties.where({$_.name -match 'version' -AND $_.value})
						if ($ver) {
							$new.Add("#requires -module @{ModuleName = '$($m.name)';$($ver.Name) = '$($ver.value)'}")
						} else {
							$new.add("#requires -module $($m.Name)")
						}
					}
				}
				if ($ast.ScriptRequirements.IsElevationRequired) {
					$new.Add("#requires -RunAsAdministrator")
				}
				If ($ast.ScriptRequirements.requiredPSEditions) {
					$new.add("#requires -PSEdition $($ast.ScriptRequirements.requiredPSEditions)")
				}
				$new.Add("`n")
			} else {
				Write-Verbose "No script requirements found"
			}

			$head = @"
# Function exported from $Path

Function $Name {

"@
			
			$new.add($head)

			if ($ch) {
				$new.Add($ch.text)
				$new.Add("`n")
			} else {
				Write-Verbose "Generating new comment based help from parameters"
				if ($ast.ParamBlock) {
					New-CommentHelp -ParamBlock $ast.ParamBlock | Foreach-Object { $new.Add("$_")}
				} else {
					New-CommentHelp -templateonly |Foreach-Object { $new.Add("$_")}
				}
				$new.Add("`n")
			}

			[regex]$rx = "\[cmdletbinding\(.*\)\]"
			if ($rx.Ismatch($ast.Extent.text)) {
				Write-Verbose "Using existing cmdletbinding"
				#use the first match
				$cb = $rx.match($ast.extent.text).Value
				$new.Add("`t$cb")
			} else {
				Write-Verbose "Adding [cmdletbinding()]"
				$new.Add("`t[cmdletbinding()]")
			}

			if ($alias) {
				Write-Verbose "Adding function alias definition $($alias -join ',')"
				$new.Add("`t[Alias('$($alias -join "','")')]")
			}
			if ($ast.ParamBlock) {
				Write-Verbose "Adding defined Param() block"
				[void]($ast.ParamBlock.tostring().split("`n").Foreach({$new.add("`t$_")}) -join "`n")
				$new.Add("`n")
			} else {
				Write-Verbose "Adding Param() block"
				$new.add("`tParam()")
			}
			if ($ast.DynamicParamBlock) {
				#assumes no more than 1 dynamic parameter
				Write-Verbose "Adding dynamic parameters"
				[void]($ast.DynamicParamBlock.tostring().split("`n").Foreach({$new.Add($_)}) -join "`n")
			}

			if ($ast.BeginBlock.Extent.text) {
				Write-Verbose "Adding defined Begin block"
				[void]($ast.BeginBlock.Extent.toString().split("`n").Foreach({$new.Add($_)}) -join "`n")
				$UseBPE = $True
			}

			if ($ast.ProcessBlock.Extent.text) {
				Write-Verbose "Adding defined Process block"
				[void]($ast.ProcessBlock.Extent.ToString().split("`n").Foreach({$new.add($_) }) -join "`n")
			}

			if ($ast.EndBlock.Extent.text) {
				if ($UseBPE) {
					Write-Verbose "Adding opening End{} block"
					$new.Add("`tEnd {")
				}
				Write-Verbose "Adding the remaining code or defined endblock"
				[void]($ast.Endblock.Statements.foreach({ $_.tostring() }).Foreach({ $new.Add($_)}))
				if ($UseBPE) {
					Write-Verbose "Adding closing End {} block"
					$new.Add("`t}")
				} 
			} else {
				$new.Add("End { }")
			}
			
			Write-Verbose "Closing the function"
			$new.Add( "`n} #close $name")

			if ($PSBoundParameters.ContainsKey("ToEditor")) {
				Write-Verbose "Opening result in editor"
				if ($host.name -match "ISE") {
					$newfile = $psise.CurrentPowerShellTab.Files.add()
					$newfile.Editor.InsertText(($new -join "`n"))
					$newfile.editor.select(1,1,1,1)
				} elseif ($host.name -match "Code") {
					$pseditor.Workspace.NewFile()
					$ctx = $pseditor.GetEditorContext()
					$ctx.CurrentFile.InsertText($new -join "`n")
				} else {
					$new -join "`n" | Set-Clipboard
					Write-Warning "Can't detect the PowerShell ISE or VS Code. Output has been copied to the clipboard."
				}
			} elseIf ([String]::IsNullOrWhiteSpace($OutputFileOrSuffix)) {
				Write-Verbose "Writing output [$($new.count) lines] to the pipeline"
				$new -join "`n"
			} Else {
				
				# If OutputFileOrSuffix has no File Extension, then it is handled as a suffix
				If ([IO.Path]::GetExtension($OutputFileOrSuffix).Length -eq 0) {
					$OutputFileOrSuffix = Filename-Add-Suffix $Path $OutputFileOrSuffix
				}
				
				Write-Verbose "Writing output [$($new.count) lines] to: $OutputFileOrSuffix"
				Write-Content-Fast -LiteralPath $OutputFileOrSuffix -Content ($new -join "`n") -Encoding ([Text.Encoding]::UTF8) -WriteBom -Overwrite
				
				# Validate
				If (Test-Path -LiteralPath $OutputFileOrSuffix) {
					$BytesWritten = (Get-Item $OutputFileOrSuffix).Length
					Write-Verbose "$((Get-Item $OutputFileOrSuffix).Length) Bytes written"
				} Else {
					Write-Error 'Coud not write File!'
				}
			}
		} #if ast found
		else {
			Write-Warning "Failed to find a script body to convert to a function."
		}

	} #process
	
	End {
		Write-Verbose "Ending $($MyInvocation.mycommand)"
	}
}
