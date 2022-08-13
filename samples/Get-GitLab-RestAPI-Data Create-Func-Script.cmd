@Echo off
:: Quick visual guide
:: 1. PS1 Source  : Get-GitLab-RestAPI-Data.ps1
:: 2. CMD Filename: Get-GitLab-RestAPI-Data Create-Func-Script.cmd
:: 3. CMD creates : Get-GitLab-RestAPI-Data-Func.ps1
:: 
:: Explanation 
:: Takes from the name of this script all the characters up to the space 
:: and then searches for the ps1 file with that name.
:: Then PowerShell 7 is started 
:: and Convert-ScriptToFunction is called 
:: to create the variant as a function with the -Func suffix from the ps1 file found.
:: 
:: 
:: 001, 220813, tom@jig.ch

:: Verbose: 0 oder 1
SET Verbose=0
SET PowerShellVerbose=0
:: Ex: Call :Verbose "Verbose ist aktiv!"

SET SearchMode=SucheUngenau

:: WaitOnEnd: 0 oder 1
SET WaitOnEnd=0

Echo.
SET "ScriptDir=%~dp0"
SET "ScriptFilename=%~n0"
SET "PSScript_ps1=%~n0.ps1"
SET "PSScript_lnk=%~n0.lnk"
REM Echo %ScriptDir%
REM Echo %ScriptFilename%
REM Echo %PSScript_ps1%
REM Echo %PSScript_lnk%

Rem Vom ScriptFilename den ersten Teil bis zum Space berechnen
Call :SplitSpaceGetn "%ScriptFilename%" 1 ScriptFilenamePart1
REM Echo Res Part1: %ScriptFilenamePart1%

SET DstScriptFilename=%ScriptFilenamePart1%
REM Echo DstScriptFilename: %DstScriptFilename%


IF /I (%SearchMode%) == (SucheUngenau) (
	:: Nur der Start des PowerShell-Script-Dateinamens muss übereinstimmen
	Call :Verbose "Ungenaue Suche nach dem PS1-Script"
	Call :Process_ScriptNameStartOnly FoundPs1Script
) Else (
	:: Der PowerShell-Script-Dateinamen muss übereinstimmen
	Call :Verbose "Exakte Suche nach dem PS1-Script"
	Call :Process_ScriptNameExact FoundPs1Script
)

Rem Umgebende " entfernen
Call :DeQuote FoundPs1Script
Echo FoundPs1Script: %FoundPs1Script%

Echo.
Echo Starte PowerShell 7, Convert-ScriptToFunction
Echo.
SET ScriptFile=\%FoundPs1Script%
REM Debug
REM Cmd /c pwsh -c Set-Location -PSPath '%CD%'; $Path=(Get-Location).Path; Set-Location ~;Write-Host """Path: $Path"""; $Src="""$($Path)%ScriptFile%"""; Write-Host "Src: $Src"; Convert-ScriptToFunction -Path $Src -Name GitLab-RestAPI -OutputFile '-Func'; Start-Sleep -MilliS 1200;
Cmd /c pwsh -c Set-Location -PSPath '%CD%'; $Path=(Get-Location).Path; Set-Location ~; $Src="""$($Path)%ScriptFile%"""; Write-Host "Create -Func.ps1 for:`n$Src" -fore yel; Convert-ScriptToFunction -Path $Src -Name GitLab-RestAPI -OutputFile '-Func'; Start-Sleep -MilliS 1200;

Echo done.
Echo.

If (%WaitOnEnd%) == (1) (
	Goto :Pause
) Else (
	Goto :Ende
)



:Process_ScriptNameStartOnly
:: =========================================================================
:Process_ScriptNameStartOnly_ps1
:: Suche nach einer ps1-Datei
Call :FindStartMatchingFileName "%DstScriptFilename%" ".ps1"
Rem Resultat übernehmen
Set FoundFileName=%ResFindPSFilename%

IF (%FoundFileName%) EQU () (
	Call :Verbose "PS1-Datei nicht gefunden"
	SET %~1=
	Exit /b
)

Call :Verbose "PS1-Datei gefunden: %FoundFileName%"
SET %~1=%FoundFileName%

Rem Call :StartPS %FoundFileName%
Exit /b

:: =========================================================================



:Process_ScriptNameExact
:: =========================================================================
Rem 1: Existiert eine ps1-Datei?
Rem  : » hat Vorrang vor der lnk-Datei, damit sie überschrieben werden kann
Rem Echo Teste: %PSScript_ps1%
If Exist "%PSScript_ps1%" (
	Rem SET "PSScript=%ScriptDir%%PSScript_ps1%"
	Call :Verbose "PS1-Datei gefunden: %PSScript_ps1%"
	Call :StartPS "%PSScript_ps1%"
	Exit /b
) Else (
	Call :Verbose "PS1-Datei: nicht gefunden"
)

Rem 2: Existiert eine lnk-Datei?
Rem Echo Teste: %PSScript_lnk%
If Exist "%PSScript_lnk%" (
	Rem SET "PSScript=%ScriptDir%%PSScript_lnk%"
	Call :Verbose "Lnk-Datei: gefunden"
	Call :StartPSLnk "%PSScript_lnk%"
	Exit /b
) Else (
	Call :Verbose "Lnk-Datei: nicht gefunden"
)

Exit /b

:: =========================================================================


:FindStartMatchingFileName
Rem Sucht eine Datei, die gleich wie %1 beginnt und die Erweiterung %2 hat
Rem Ex
Rem 	SET "SearchFileName=%~n0"
Rem 	Call :FindStartMatchingFileName "%SearchFileName%" ".lnk"
Rem 	Rem Resultat übernehmen
Rem 	Set FoundFileName=%ResFindPSFilename%
Rem 	IF "%FoundFileName%" NEQ "" (
Rem 		Call :Verbose "Datei gefunden: %FoundFileName%"
Rem 	)
Rem 
Rem 
Rem Arg 1: Ausgangs-Dateinamen, von dem schrittweise am Ende Zeichen entfernt werden
Rem Arg 2: gesuchte Dateinamen-Erweiterung

SET TestFileName=%1
SET Extension=%2
Rem Die " entfernen
SET TestFileName=%TestFileName:"=%
SET Extension=%Extension:"=%

:FindPSFilename_Loop
SET FullFileName="%TestFileName%%Extension%"
Rem Call :Verbose "Teste: "%FullFileName%""
Rem Echo Teste: %FullFileName%

IF EXIST %FullFileName% (
	SET ResFindPSFilename=%FullFileName%
	Exit /b
)


:FindPSFilename_Fehlt
Rem Neuer Versuch mit einem Zeichen weniger am Ende des Dateinamens
Rem Letztes Zeichen entfernen
Call :RemoveLastChar "%TestFileName%"
Rem Resultat übernehmen
SET TestFileName=%ResRemoveLastChar%
IF "%TestFileName%" == "" (
	Rem Zeichenlänge = 0
	Rem Call :Verbose "Datei nicht gefunden"
	SET ResFindPSFilename=
	Exit /b
)

:: Loop
Goto :FindPSFilename_Loop


:RemoveLastChar
Rem Vom String in %1 wird der letzte Character entfernt
Rem und das Resultat in die Variable gespeichert: ResRemoveLastChar
SET TmpRemoveLastChar=%1
Rem Die " entfernen
SET TmpRemoveLastChar=%TmpRemoveLastChar:"=%
Rem Das letzte Zeichen löschen und das Resultat zurückgeben
SET ResRemoveLastChar=%TmpRemoveLastChar:~0,-1%
Exit /b


:SplitSpaceGetn
:: (%1.Split(' '))[%2]
:: %1 = String mit Leerzeichen
:: %2 = Der Index des zurückzugebenden Teils
:: %3 = Die Variable, die mit dem Resultat gesetzt werden soll
Rem Umgebende " entfernen
SET InStr=%~1
REM Echo 1: %InStr%
REM Echo 2: %2
REM Echo 3: %3
For /f "tokens=%2" %%G IN ("%InStr%") DO SET %~3=%%G
Exit /b


:DeQuote
Rem Umgebende " entfernen
REM Ändert direkt die Variable in %1!
REM Aufruf ohne %.%!
REM Also:
REM Call :DeQuote FoundPs1Script
For /f "delims=" %%A IN ('echo %%%1%%') DO SET %1=%%~A
Exit /b


:Verbose
:: Wenn die Variable Verbose definiert ist, wird %1 ausgegeben
Rem Umgebende " entfernen
SET Message=%~1
Rem Doppelte " entfernen
SET Message=%Message:"=%
If (%Verbose%) == (1) Echo %Message%
Exit /b


:Pause
Echo.
Pause

:Ende

