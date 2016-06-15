#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=..\..\..\Program Files (x86)\autoit-v3.3.14.2\Icons\au3.ico
#AutoIt3Wrapper_UseUpx=y
#AutoIt3Wrapper_Change2CUI=y
#AutoIt3Wrapper_Res_Comment=Extracts raw INDX records
#AutoIt3Wrapper_Res_Description=Extracts raw INDX records
#AutoIt3Wrapper_Res_Fileversion=1.0.0.3
#AutoIt3Wrapper_Res_requestedExecutionLevel=asInvoker
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#Include <WinAPIEx.au3>

Global Const $FILEsig = "46494c45"
Global Const $INDXsig = "494E4458"
Global Const $INDX_Size = 4096
Global $File,$OutputPath

ConsoleWrite("IndxCarver v1.0.0.3" & @CRLF)

_GetInputParams()

$TimestampStart = @YEAR & "-" & @MON & "-" & @MDAY & "_" & @HOUR & "-" & @MIN & "-" & @SEC
$logfilename = $OutputPath & "\Carver_Indx_" & $TimestampStart & ".log"
$logfile = FileOpen($logfilename,2+32)
If @error Then
	ConsoleWrite("Error creating: " & $logfilename & @CRLF)
	Exit
EndIf

$OutFileWithFixups = $OutputPath & "\Carver_Indx_" & $TimestampStart & ".wfixups.INDX"
If FileExists($OutFileWithFixups) Then
	_DebugOut("Error outfile exist: " & $OutFileWithFixups)
	Exit
EndIf
$OutFileWithoutFixups = $OutputPath & "\Carver_Indx_" & $TimestampStart & ".wofixups.INDX"
If FileExists($OutFileWithoutFixups) Then
	_DebugOut("Error outfile exist: " & $OutFileWithoutFixups)
	Exit
EndIf
$OutFileFalsePositives = $OutputPath & "\Carver_Indx_" & $TimestampStart & ".false.positive.INDX"
If FileExists($OutFileFalsePositives) Then
	_DebugOut("Error outfile exist: " & $OutFileFalsePositives)
	Exit
EndIf

$FileSize = FileGetSize($File)
If $FileSize = 0 Then
	ConsoleWrite("Error retrieving file size" & @CRLF)
	Exit
EndIf

_DebugOut("Input: " & $File)
_DebugOut("Input filesize: " & $FileSize & " bytes")
_DebugOut("OutFileWithFixups: " & $OutFileWithFixups)
_DebugOut("OutFileWithoutFixups: " & $OutFileWithoutFixups)
_DebugOut("OutFileFalsePositives: " & $OutFileFalsePositives)
_DebugOut("INDX size configuration: " & $INDX_Size)

$hFile = _WinAPI_CreateFile("\\.\" & $File,2,2,7)
If $hFile = 0 Then
	_DebugOut("CreateFile error on " & $File & " : " & _WinAPI_GetLastErrorMessage() & @CRLF)
	Exit
EndIf
$hFileOutWithFixups = _WinAPI_CreateFile("\\.\" & $OutFileWithFixups,3,6,7)
If $hFileOutWithFixups = 0 Then
	_DebugOut("CreateFile error on " & $OutFileWithFixups & " : " & _WinAPI_GetLastErrorMessage() & @CRLF)
	Exit
EndIf
$hFileOutWithoutFixups = _WinAPI_CreateFile("\\.\" & $OutFileWithoutFixups,3,6,7)
If $hFileOutWithoutFixups = 0 Then
	_DebugOut("CreateFile error on " & $OutFileWithoutFixups & " : " & _WinAPI_GetLastErrorMessage() & @CRLF)
	Exit
EndIf
$hFileOutFalsePositives = _WinAPI_CreateFile("\\.\" & $OutFileFalsePositives,3,6,7)
If $hFileOutFalsePositives = 0 Then
	_DebugOut("CreateFile error on " & $OutFileFalsePositives & " : " & _WinAPI_GetLastErrorMessage() & @CRLF)
	Exit
EndIf

$rBuffer = DllStructCreate("byte ["&$INDX_Size&"]")
$JumpSize = 512
$SectorSize = $INDX_Size
$JumpForward = $INDX_Size/$JumpSize
$NextOffset = 0
$FalsePositivesCounter = 0
$RecordsWithFixupsCounter = 0
$RecordsWithoutFixupsCounter = 0
$nBytes = ""
$Timerstart = TimerInit()
Do
	If IsInt(Mod(($NextOffset * $JumpSize),$FileSize)/1000000) Then ConsoleWrite(Round((($NextOffset * $JumpSize)/$FileSize)*100,2) & " %" & @CRLF)
	_WinAPI_SetFilePointerEx($hFile, $NextOffset*$JumpSize, $FILE_BEGIN)
	_WinAPI_ReadFile($hFile, DllStructGetPtr($rBuffer), $SectorSize, $nBytes)
	$DataChunk = DllStructGetData($rBuffer, 1)
;	ConsoleWrite("Record: " & $NextOffset & @CRLF)
	If StringMid($DataChunk,3,8) <> $INDXsig Then
		$NextOffset+=1
		ContinueLoop
	EndIf

	If Not _ValidateIndxStructureWithFixups($DataChunk) Then ; Test failed. Trying to validate INDX structure without caring for fixups
		If Not _ValidateIndxStructureWithoutFixups($DataChunk) Then ; INDX structure seems bad. False positive
			_DebugOut("False positive at 0x" & Hex(Int($NextOffset*$JumpSize)))
			$FalsePositivesCounter+=1
			$NextOffset+=1
			$Written = _WinAPI_WriteFile($hFileOutFalsePositives, DllStructGetPtr($rBuffer), $SectorSize, $nBytes)
			If $Written = 0 Then _DebugOut("WriteFile error on " & $OutFileFalsePositives & " : " & _WinAPI_GetLastErrorMessage() & @CRLF)
			ContinueLoop
		Else ; INDX structure could be validated, although fixups failed. This record may be from memory dump.
			$Written = _WinAPI_WriteFile($hFileOutWithoutFixups, DllStructGetPtr($rBuffer), $SectorSize, $nBytes)
			If $Written = 0 Then _DebugOut("WriteFile error on " & $OutFileWithoutFixups & " : " & _WinAPI_GetLastErrorMessage() & @CRLF)
			$RecordsWithoutFixupsCounter+=1
		EndIf
	Else ; Fixups successfully verified and INDX structure seems fine.
		$Written = _WinAPI_WriteFile($hFileOutWithFixups, DllStructGetPtr($rBuffer), $SectorSize, $nBytes)
		If $Written = 0 Then _DebugOut("WriteFile error on " & $OutFileWithFixups & " : " & _WinAPI_GetLastErrorMessage() & @CRLF)
		$RecordsWithFixupsCounter+=1
	EndIf

	$NextOffset+=$JumpForward
Until $NextOffset * $JumpSize >= $FileSize

_DebugOut("Job took " & _WinAPI_StrFromTimeInterval(TimerDiff($Timerstart)))
_DebugOut("Found records with fixups applied: " & $RecordsWithFixupsCounter)
_DebugOut("Found records where fixups failed: " & $RecordsWithoutFixupsCounter)
_DebugOut("False positives: " & $FalsePositivesCounter)

_WinAPI_CloseHandle($hFile)
_WinAPI_CloseHandle($hFileOutWithFixups)
_WinAPI_CloseHandle($hFileOutWithoutFixups)
_WinAPI_CloseHandle($hFileOutFalsePositives)

FileClose($logfile)
If FileGetSize($OutFileWithFixups) = 0 Then FileDelete($OutFileWithFixups)
If FileGetSize($OutFileWithoutFixups) = 0 Then FileDelete($OutFileWithoutFixups)
If FileGetSize($OutFileFalsePositives) = 0 Then FileDelete($OutFileFalsePositives)
Exit

Func _SwapEndian($iHex)
	Return StringMid(Binary(Dec($iHex,2)),3, StringLen($iHex))
EndFunc

Func _HexEncode($bInput)
    Local $tInput = DllStructCreate("byte[" & BinaryLen($bInput) & "]")
    DllStructSetData($tInput, 1, $bInput)
    Local $a_iCall = DllCall("crypt32.dll", "int", "CryptBinaryToString", _
            "ptr", DllStructGetPtr($tInput), _
            "dword", DllStructGetSize($tInput), _
            "dword", 11, _
            "ptr", 0, _
            "dword*", 0)

    If @error Or Not $a_iCall[0] Then
        Return SetError(1, 0, "")
    EndIf
    Local $iSize = $a_iCall[5]
    Local $tOut = DllStructCreate("char[" & $iSize & "]")
    $a_iCall = DllCall("crypt32.dll", "int", "CryptBinaryToString", _
            "ptr", DllStructGetPtr($tInput), _
            "dword", DllStructGetSize($tInput), _
            "dword", 11, _
            "ptr", DllStructGetPtr($tOut), _
            "dword*", $iSize)
    If @error Or Not $a_iCall[0] Then
        Return SetError(2, 0, "")
    EndIf
    Return SetError(0, 0, DllStructGetData($tOut, 1))
EndFunc  ;==>_HexEncode

Func _DebugOut($text, $var="")
   If $var Then $var = _HexEncode($var) & @CRLF
   $text &= @CRLF & $var
   ConsoleWrite($text)
   If $logfile Then FileWrite($logfile, $text)
EndFunc

Func _ValidateIndxStructureWithFixups($Entry)
	Local $MaxLoops=100, $LocalCounter=0
	$UpdSeqArrOffset = ""
	$UpdSeqArrSize = ""
	$UpdSeqArrOffset = StringMid($Entry, 11, 4)
	$UpdSeqArrOffset = Dec(_SwapEndian($UpdSeqArrOffset),2)
	If $UpdSeqArrOffset <> 40 Then Return 0
	$UpdSeqArrSize = StringMid($Entry, 15, 4)
	$UpdSeqArrSize = Dec(_SwapEndian($UpdSeqArrSize),2)
	$UpdSeqArr = StringMid($Entry, 3 + ($UpdSeqArrOffset * 2), $UpdSeqArrSize * 2 * 2)
	If $INDX_Size = 4096 Then
		Local $UpdSeqArrPart0 = StringMid($UpdSeqArr,1,4)
		Local $UpdSeqArrPart1 = StringMid($UpdSeqArr,5,4)
		Local $UpdSeqArrPart2 = StringMid($UpdSeqArr,9,4)
		Local $UpdSeqArrPart3 = StringMid($UpdSeqArr,13,4)
		Local $UpdSeqArrPart4 = StringMid($UpdSeqArr,17,4)
		Local $UpdSeqArrPart5 = StringMid($UpdSeqArr,21,4)
		Local $UpdSeqArrPart6 = StringMid($UpdSeqArr,25,4)
		Local $UpdSeqArrPart7 = StringMid($UpdSeqArr,29,4)
		Local $UpdSeqArrPart8 = StringMid($UpdSeqArr,33,4)
		Local $RecordEnd1 = StringMid($Entry,1023,4)
		Local $RecordEnd2 = StringMid($Entry,2047,4)
		Local $RecordEnd3 = StringMid($Entry,3071,4)
		Local $RecordEnd4 = StringMid($Entry,4095,4)
		Local $RecordEnd5 = StringMid($Entry,5119,4)
		Local $RecordEnd6 = StringMid($Entry,6143,4)
		Local $RecordEnd7 = StringMid($Entry,7167,4)
		Local $RecordEnd8 = StringMid($Entry,8191,4)
		If $UpdSeqArrPart0 <> $RecordEnd1 OR $UpdSeqArrPart0 <> $RecordEnd2 OR $UpdSeqArrPart0 <> $RecordEnd3 OR $UpdSeqArrPart0 <> $RecordEnd4 OR $UpdSeqArrPart0 <> $RecordEnd5 OR $UpdSeqArrPart0 <> $RecordEnd6 OR $UpdSeqArrPart0 <> $RecordEnd7 OR $UpdSeqArrPart0 <> $RecordEnd8 Then
			Return 0
		EndIf
		$Entry =  StringMid($Entry,1,1022) & $UpdSeqArrPart1 & StringMid($Entry,1027,1020) & $UpdSeqArrPart2 & StringMid($Entry,2051,1020) & $UpdSeqArrPart3 & StringMid($Entry,3075,1020) & $UpdSeqArrPart4 & StringMid($Entry,4099,1020) & $UpdSeqArrPart5 & StringMid($Entry,5123,1020) & $UpdSeqArrPart6 & StringMid($Entry,6147,1020) & $UpdSeqArrPart7 & StringMid($Entry,7171,1020) & $UpdSeqArrPart8
	EndIf
	$LocalOffset = 1
	$IndxLsn = Dec(_SwapEndian(StringMid($Entry,$LocalOffset+16,16)),2)
;	ConsoleWrite("$IndxLsn: " & $IndxLsn & @crlf)
	If $IndxLsn = 0 Then Return 0

	$IndxHeaderSize = Dec(_SwapEndian(StringMid($Entry,$LocalOffset+48,8)),2)
;	ConsoleWrite("$IndxHeaderSize: " & $IndxHeaderSize & @crlf)
	If $IndxHeaderSize = 0 Then Return 0
	If Mod($IndxHeaderSize,8) Then Return 0

	$IndxRecordSize = Dec(_SwapEndian(StringMid($Entry,$LocalOffset+56,8)),2)
;	ConsoleWrite("$IndxRecordSize: " & $IndxRecordSize & @crlf)
	If $IndxRecordSize = 0 Then Return 0
	If Mod($IndxRecordSize,8) Then Return 0

	$IndxAllocatedSize = Dec(_SwapEndian(StringMid($Entry,$LocalOffset+64,8)),2)
;	ConsoleWrite("$IndxAllocatedSize: " & $IndxAllocatedSize & @crlf)
	If $IndxAllocatedSize = 0 Then Return 0
	If Mod($IndxAllocatedSize,8) Then Return 0

	$IsNotLeafNode = Dec(StringMid($Entry,$LocalOffset+72,2))
	If $IsNotLeafNode > 1 Then Return 0

	Return 1
EndFunc

Func _ValidateIndxStructureWithoutFixups($Entry)
	Local $MaxLoops=100, $LocalCounter=0

	$UpdSeqArrOffset = ""
	$UpdSeqArrSize = ""
	$UpdSeqArrOffset = StringMid($Entry, 11, 4)
	$UpdSeqArrOffset = Dec(_SwapEndian($UpdSeqArrOffset),2)
	If $UpdSeqArrOffset <> 40 Then Return 0
	$UpdSeqArrSize = StringMid($Entry, 15, 4)
	$UpdSeqArrSize = Dec(_SwapEndian($UpdSeqArrSize),2)
	$UpdSeqArr = StringMid($Entry, 3 + ($UpdSeqArrOffset * 2), $UpdSeqArrSize * 2 * 2)
	If $INDX_Size = 4096 Then
		Local $UpdSeqArrPart0 = StringMid($UpdSeqArr,1,4)
		Local $UpdSeqArrPart1 = StringMid($UpdSeqArr,5,4)
		Local $UpdSeqArrPart2 = StringMid($UpdSeqArr,9,4)
		Local $UpdSeqArrPart3 = StringMid($UpdSeqArr,13,4)
		Local $UpdSeqArrPart4 = StringMid($UpdSeqArr,17,4)
		Local $UpdSeqArrPart5 = StringMid($UpdSeqArr,21,4)
		Local $UpdSeqArrPart6 = StringMid($UpdSeqArr,25,4)
		Local $UpdSeqArrPart7 = StringMid($UpdSeqArr,29,4)
		Local $UpdSeqArrPart8 = StringMid($UpdSeqArr,33,4)
		Local $RecordEnd1 = StringMid($Entry,1023,4)
		Local $RecordEnd2 = StringMid($Entry,2047,4)
		Local $RecordEnd3 = StringMid($Entry,3071,4)
		Local $RecordEnd4 = StringMid($Entry,4095,4)
		Local $RecordEnd5 = StringMid($Entry,5119,4)
		Local $RecordEnd6 = StringMid($Entry,6143,4)
		Local $RecordEnd7 = StringMid($Entry,7167,4)
		Local $RecordEnd8 = StringMid($Entry,8191,4)
;		If $UpdSeqArrPart1 <> $RecordEnd1 OR $UpdSeqArrPart2 <> $RecordEnd2 OR $UpdSeqArrPart3 <> $RecordEnd3 OR $UpdSeqArrPart4 <> $RecordEnd4 OR $UpdSeqArrPart5 <> $RecordEnd5 OR $UpdSeqArrPart6 <> $RecordEnd6 OR $UpdSeqArrPart7 <> $RecordEnd7 OR $UpdSeqArrPart8 <> $RecordEnd8 Then
		If $UpdSeqArrPart1 <> $RecordEnd1 Then
			Return 0
		EndIf
	EndIf

	$LocalOffset = 1
	$IndxLsn = Dec(_SwapEndian(StringMid($Entry,$LocalOffset+16,16)),2)
;	ConsoleWrite("$IndxLsn: " & $IndxLsn & @crlf)
	If $IndxLsn = 0 Then Return 0

	$IndxHeaderSize = Dec(_SwapEndian(StringMid($Entry,$LocalOffset+48,8)),2)
;	ConsoleWrite("$IndxHeaderSize: " & $IndxHeaderSize & @crlf)
	If $IndxHeaderSize = 0 Then Return 0
	If Mod($IndxHeaderSize,8) Then Return 0

	$IndxRecordSize = Dec(_SwapEndian(StringMid($Entry,$LocalOffset+56,8)),2)
;	ConsoleWrite("$IndxRecordSize: " & $IndxRecordSize & @crlf)
	If $IndxRecordSize = 0 Then Return 0
	If Mod($IndxRecordSize,8) Then Return 0

	$IndxAllocatedSize = Dec(_SwapEndian(StringMid($Entry,$LocalOffset+64,8)),2)
;	ConsoleWrite("$IndxAllocatedSize: " & $IndxAllocatedSize & @crlf)
	If $IndxAllocatedSize = 0 Then Return 0
	If Mod($IndxAllocatedSize,8) Then Return 0

	$IsNotLeafNode = Dec(StringMid($Entry,$LocalOffset+72,2))
	If $IsNotLeafNode > 1 Then Return 0

	Return 1
EndFunc

Func _GetInputParams()

	For $i = 1 To $cmdline[0]
		;ConsoleWrite("Param " & $i & ": " & $cmdline[$i] & @CRLF)
		If StringLeft($cmdline[$i],11) = "/InputFile:" Then $File = StringMid($cmdline[$i],12)
		If StringLeft($cmdline[$i],12) = "/OutputPath:" Then $OutputPath = StringMid($cmdline[$i],13)
	Next

	If $File="" Then ;No InputFile parameter passed
		$File = FileOpenDialog("Select file",@ScriptDir,"All (*.*)")
		If @error Then Exit
	ElseIf FileExists($File) = 0 Then
		ConsoleWrite("Input file does not exist: " & $cmdline[1] & @CRLF)
		$File = FileOpenDialog("Select file",@ScriptDir,"All (*.*)")
		If @error Then Exit
	EndIf

	If StringLen($OutputPath) > 0 Then
		If Not FileExists($OutputPath) Then
			ConsoleWrite("Error input $OutputPath does not exist. Setting default to program directory." & @CRLF)
			$OutputPath = @ScriptDir
		EndIf
	Else
		$OutputPath = @ScriptDir
	EndIf

EndFunc