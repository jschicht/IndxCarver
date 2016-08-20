#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=..\..\..\Program Files (x86)\autoit-v3.3.14.2\Icons\au3.ico
#AutoIt3Wrapper_UseUpx=y
#AutoIt3Wrapper_Change2CUI=y
#AutoIt3Wrapper_Res_Comment=Extracts raw INDX records
#AutoIt3Wrapper_Res_Description=Extracts raw INDX records
#AutoIt3Wrapper_Res_Fileversion=1.0.0.5
#AutoIt3Wrapper_Res_requestedExecutionLevel=asInvoker
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#Include <WinAPIEx.au3>

Global Const $FILEsig = "46494c45"
Global Const $INDXsig = "494E4458"
Global Const $RCRDsig = "52435244"
Global Const $INDX_Size = 4096
Global $File,$OutputPath,$PageSize=4096
Global $ExtendedNameCheckChar=1, $ExtendedNameCheckWindows=1, $ExtendedNameCheckAll=1, $ExtendedTimestampCheck=1, $TimestampErrorVal = "0000-00-00 00:00:00", $PrecisionSeparator=".", $PrecisionSeparator2="",$DateTimeFormat, $TimestampPrecision
Global $_COMMON_KERNEL32DLL=DllOpen("kernel32.dll")
Global $tDelta = _WinTime_GetUTCToLocalFileTimeDelta()

ConsoleWrite("IndxCarver v1.0.0.5" & @CRLF)

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
$BigBuffSize = 512 * 1000
$rBufferBig = DllStructCreate("byte ["&$BigBuffSize&"]")

$NextOffset = 0
$FalsePositivesCounter = 0
$RecordsWithFixupsCounter = 0
$RecordsWithoutFixupsCounter = 0
$nBytes = ""
$Timerstart = TimerInit()
Do
	If IsInt(Mod(($NextOffset),$FileSize)/1000000) Then ConsoleWrite(Round((($NextOffset)/$FileSize)*100,2) & " %" & @CRLF)
	If Not _WinAPI_SetFilePointerEx($hFile, $NextOffset, $FILE_BEGIN) Then
		_DebugOut("SetFilePointerEx error on offset " & $NextOffset & @CRLF)
		Exit
	EndIf
	If Not _WinAPI_ReadFile($hFile, DllStructGetPtr($rBufferBig), $BigBuffSize, $nBytes) Then
		_DebugOut("ReadFile error on offset " & $NextOffset & @CRLF)
		Exit
	EndIf
	$DataChunkBig = DllStructGetData($rBufferBig, 1)

	$OffsetTest = StringInStr($DataChunkBig,$INDXsig)


	If Not $OffsetTest Then
		$NextOffset += $BigBuffSize
		ContinueLoop
	EndIf
	If $NextOffset > 0 Then
		If Mod($OffsetTest,2)=0 Then
			;We can only consider bytes, not nibbles
			$NextOffset += $NextOffset/2
			ContinueLoop
		EndIf
		If $OffsetTest >= ($NextOffset*2) - ($PageSize*2) Then
			$NextOffset += (($OffsetTest-3)/2)
			ContinueLoop
		EndIf
	EndIf

	$INDXOffset = (($OffsetTest-3)/2)
	If Not _WinAPI_SetFilePointerEx($hFile, $INDXOffset+$NextOffset, $FILE_BEGIN) Then
		_DebugOut("SetFilePointerEx error on offset " & $INDXOffset+$NextOffset & @CRLF)
		Exit
	EndIf
	If Not _WinAPI_ReadFile($hFile, DllStructGetPtr($rBuffer), $INDX_Size, $nBytes) Then
		_DebugOut("ReadFile error on offset " & $INDXOffset+$NextOffset & @CRLF)
		Exit
	EndIf
	$DataChunk = DllStructGetData($rBuffer, 1)

	If StringMid($DataChunk,3,8) <> $INDXsig Then
		_DebugOut("Error: This should not happen" & @CRLF)
		_DebugOut("Look up 0x" & Hex(Int($INDXOffset+$NextOffset)) & @CRLF)
		_DebugOut(_HexEncode($DataChunk) & @CRLF)
		$NextOffset += 1
		ContinueLoop
	EndIf

	If Not _ValidateIndxStructureWithFixups($DataChunk) Then ; Test failed. Trying to validate INDX structure without caring for fixups
		If Not _ValidateIndxStructureWithoutFixups($DataChunk) Then ; INDX structure seems bad. False positive
			$ErrorCode = @error
			_DebugOut("False positive at 0x" & Hex(Int($INDXOffset+$NextOffset)) & " ErrorCode: " & $ErrorCode)
			$FalsePositivesCounter+=1
			$NextOffset += $INDXOffset + 1
			$Written = _WinAPI_WriteFile($hFileOutFalsePositives, DllStructGetPtr($rBuffer), $INDX_Size, $nBytes)
			If $Written = 0 Then _DebugOut("WriteFile error on " & $OutFileFalsePositives & " : " & _WinAPI_GetLastErrorMessage() & @CRLF)
			ContinueLoop
		Else ; INDX structure could be validated, although fixups failed. This record may be from memory dump.
			$Written = _WinAPI_WriteFile($hFileOutWithoutFixups, DllStructGetPtr($rBuffer), $INDX_Size, $nBytes)
			If $Written = 0 Then _DebugOut("WriteFile error on " & $OutFileWithoutFixups & " : " & _WinAPI_GetLastErrorMessage() & @CRLF)
			$RecordsWithoutFixupsCounter+=1
		EndIf
	Else ; Fixups successfully verified and INDX structure seems fine.
		$Written = _WinAPI_WriteFile($hFileOutWithFixups, DllStructGetPtr($rBuffer), $INDX_Size, $nBytes)
		If $Written = 0 Then _DebugOut("WriteFile error on " & $OutFileWithFixups & " : " & _WinAPI_GetLastErrorMessage() & @CRLF)
		$RecordsWithFixupsCounter+=1
	EndIf

	$NextOffset += $INDXOffset + $INDX_Size
Until $NextOffset >= $FileSize


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
	$LocalOffset = 3
	$IndxLsn = Dec(_SwapEndian(StringMid($Entry,$LocalOffset+16,16)),2)
;	ConsoleWrite("$IndxLsn: " & $IndxLsn & @crlf)
;	If $IndxLsn = 0 Then Return SetError(1,0,0)

	$IndxHeaderSize = Dec(_SwapEndian(StringMid($Entry,$LocalOffset+48,8)),2)
;	ConsoleWrite("$IndxHeaderSize: " & $IndxHeaderSize & @crlf)
	If $IndxHeaderSize = 0 Then Return SetError(2,0,0)
	If Mod($IndxHeaderSize,8) Then Return SetError(2,0,0)

	$IndxRecordSize = Dec(_SwapEndian(StringMid($Entry,$LocalOffset+56,8)),2)
;	ConsoleWrite("$IndxRecordSize: " & $IndxRecordSize & @crlf)
	If $IndxRecordSize = 0 Then Return SetError(3,0,0)
	If Mod($IndxRecordSize,8) Then Return SetError(3,0,0)

	$IndxAllocatedSize = Dec(_SwapEndian(StringMid($Entry,$LocalOffset+64,8)),2)
;	ConsoleWrite("$IndxAllocatedSize: " & $IndxAllocatedSize & @crlf)
	If $IndxAllocatedSize = 0 Then Return SetError(4,0,0)
	If Mod($IndxAllocatedSize,8) Then Return SetError(4,0,0)

	$IsNotLeafNode = Dec(StringMid($Entry,$LocalOffset+72,2))
	If $IsNotLeafNode > 1 Then Return SetError(5,0,0)

	Return 1

	;This last code is not activated yet

	If _ScanModeI30DecodeEntry(StringMid($Entry,3+48+($IndxHeaderSize*2),1024)) Then
		Return 1
	Else
		$ErrorCode = @error
		Return SetError($ErrorCode,0,0)
	EndIf

EndFunc

Func _ValidateIndxStructureWithoutFixups($Entry)
	Local $MaxLoops=100, $LocalCounter=0

	$LocalOffset = 3
	$IndxLsn = Dec(_SwapEndian(StringMid($Entry,$LocalOffset+16,16)),2)
;	ConsoleWrite("$IndxLsn: " & $IndxLsn & @crlf)
;	If $IndxLsn = 0 Then Return SetError(1,0,0)

	$IndxHeaderSize = Dec(_SwapEndian(StringMid($Entry,$LocalOffset+48,8)),2)
;	ConsoleWrite("$IndxHeaderSize: " & $IndxHeaderSize & @crlf)
	If $IndxHeaderSize = 0 Then Return SetError(2,0,0)
	If Mod($IndxHeaderSize,8) Then Return SetError(2,0,0)

	$IndxRecordSize = Dec(_SwapEndian(StringMid($Entry,$LocalOffset+56,8)),2)
;	ConsoleWrite("$IndxRecordSize: " & $IndxRecordSize & @crlf)
	If $IndxRecordSize = 0 Then Return SetError(3,0,0)
	If Mod($IndxRecordSize,8) Then Return SetError(3,0,0)

	$IndxAllocatedSize = Dec(_SwapEndian(StringMid($Entry,$LocalOffset+64,8)),2)
;	ConsoleWrite("$IndxAllocatedSize: " & $IndxAllocatedSize & @crlf)
	If $IndxAllocatedSize = 0 Then Return SetError(4,0,0)
	If Mod($IndxAllocatedSize,8) Then Return SetError(4,0,0)

	$IsNotLeafNode = Dec(StringMid($Entry,$LocalOffset+72,2))
	If $IsNotLeafNode > 1 Then Return SetError(5,0,0)

	Return 1

	;This last code is not activated yet

	If _ScanModeI30DecodeEntry(StringMid($Entry,3+48+($IndxHeaderSize*2),1024)) Then
		Return 1
	Else
		$ErrorCode = @error
		_DebugOut("Error in _ScanModeI30DecodeEntry()")
		Return SetError($ErrorCode,0,0)
	EndIf

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

Func _ScanModeI30DecodeEntry($Record)

	$MFTReference = StringMid($Record,1,12)
	If $MFTReference = "FFFFFFFFFFFF" Then Return SetError(1,0,0)
	$MFTReference = Dec(_SwapEndian($MFTReference),2)
	If $MFTReference = 0 Then Return SetError(1,0,0)
	$MFTReferenceSeqNo = StringMid($Record,13,4)
	$MFTReferenceSeqNo = Dec(_SwapEndian($MFTReferenceSeqNo),2)
	If $MFTReferenceSeqNo = 0 Then Return SetError(2,0,0)
	$IndexEntryLength = StringMid($Record,17,4)
	$IndexEntryLength = Dec(_SwapEndian($IndexEntryLength),2)
	If ($IndexEntryLength = 0) Or ($IndexEntryLength = 0xFFFF) Then Return SetError(3,0,0)
	;$OffsetToFileName = StringMid($Record,21,4)
	;$OffsetToFileName = Dec(_SwapEndian($OffsetToFileName),2)
	;If $OffsetToFileName <> 82 Then Return SetError(4,0,0)
	$IndexFlags = StringMid($Record,25,4)
	$IndexFlags = Dec(_SwapEndian($IndexFlags),2)
	If $IndexFlags > 2 Then Return SetError(5,0,0)

	$Padding = StringMid($Record,29,4)
	If $Padding <> "0000" Then Return SetError(6,0,0)
	$MFTReferenceOfParent = StringMid($Record,33,12)
	$MFTReferenceOfParent = Dec(_SwapEndian($MFTReferenceOfParent),2)
	If $MFTReferenceOfParent < 5 Then Return SetError(7,0,0)
	$MFTReferenceOfParentSeqNo = StringMid($Record,45,4)
	$MFTReferenceOfParentSeqNo = Dec(_SwapEndian($MFTReferenceOfParentSeqNo),2)
	If $MFTReferenceOfParentSeqNo = 0 Then Return SetError(8,0,0)
	Return 1
	$CTime_Timestamp = StringMid($Record,49,16)
	If $ExtendedTimestampCheck Then
		$CTime_TimestampTmp = Dec(_SwapEndian($CTime_Timestamp),2)
		If $CTime_TimestampTmp < 112589990684262400 Or $CTime_TimestampTmp > 139611588448485376 Then Return SetError(9,0,0) ;14 oktober 1957 - 31 mai 2043
	EndIf
	$CTime_Timestamp = _DecodeTimestamp($CTime_Timestamp)
	If $CTime_Timestamp = $TimestampErrorVal Then Return SetError(10,0,0)
	$ATime_Timestamp = StringMid($Record,65,16)
	If $ExtendedTimestampCheck Then
		$ATime_TimestampTmp = Dec(_SwapEndian($ATime_Timestamp),2)
		If $ATime_TimestampTmp < 112589990684262400 Or $ATime_TimestampTmp > 139611588448485376 Then Return SetError(11,0,0) ;14 oktober 1957 - 31 mai 2043
	EndIf
	$ATime_Timestamp = _DecodeTimestamp($ATime_Timestamp)
	If $ATime_Timestamp = $TimestampErrorVal Then Return SetError(12,0,0)
	$MTime_Timestamp = StringMid($Record,81,16)
	If $ExtendedTimestampCheck Then
		$MTime_TimestampTmp = Dec(_SwapEndian($MTime_Timestamp),2)
		;If $MTime_TimestampTmp < 112589990684262400 Or $MTime_TimestampTmp > 139611588448485376 Then Return SetError(13,0,0) ;14 oktober 1957 - 31 mai 2043
	EndIf
	$MTime_Timestamp = _DecodeTimestamp($MTime_Timestamp)
	;-----------------------
	;If $MTime_Timestamp = $TimestampErrorVal Then Return SetError(14,0,0)
	;--------------------------
	$RTime_Timestamp = StringMid($Record,97,16)
	If $ExtendedTimestampCheck Then
		$RTime_TimestampTmp = Dec(_SwapEndian($RTime_Timestamp),2)
		If $RTime_TimestampTmp < 112589990684262400 Or $RTime_TimestampTmp > 139611588448485376 Then Return SetError(15,0,0) ;14 oktober 1957 - 31 mai 2043
	EndIf
	$RTime_Timestamp = _DecodeTimestamp($RTime_Timestamp)
	If $RTime_Timestamp = $TimestampErrorVal Then Return SetError(16,0,0)
	$Indx_AllocSize = StringMid($Record,113,16)
	$Indx_AllocSize = Dec(_SwapEndian($Indx_AllocSize),2)
	If $Indx_AllocSize > 281474976710655 Then ;0xFFFFFFFFFFFF
		Return SetError(17,0,0)
	EndIf
	If $Indx_AllocSize > 0 And Mod($Indx_AllocSize,8) Then
		Return SetError(17,0,0)
	EndIf
	$Indx_RealSize = StringMid($Record,129,16)
	$Indx_RealSize = Dec(_SwapEndian($Indx_RealSize),2)
	If $Indx_RealSize > 281474976710655 Then ;0xFFFFFFFFFFFF
		Return SetError(18,0,0)
	EndIf
	If $Indx_RealSize > $Indx_AllocSize Then Return SetError(18,0,0)

	$Indx_File_Flags = StringMid($Record,145,8)
	$Indx_File_Flags = _SwapEndian($Indx_File_Flags)

	If BitAND("0x" & $Indx_File_Flags, 0x40000) Then
		$DoReparseTag=0
		$DoEaSize=1
	Else
		$DoReparseTag=1
		$DoEaSize=0
	EndIf
	$Indx_File_Flags = _File_Attributes("0x" & $Indx_File_Flags)

	Select
		Case $DoReparseTag
			$Indx_EaSize = ""
			$Indx_ReparseTag = StringMid($Record,153,8)
			$Indx_ReparseTag = _SwapEndian($Indx_ReparseTag)
			$Indx_ReparseTag = _GetReparseType("0x"&$Indx_ReparseTag)
			If StringInStr($Indx_ReparseTag,"UNKNOWN") Then Return SetError(19,0,0)
		Case $DoEaSize
			$Indx_ReparseTag = ""
			$Indx_EaSize = StringMid($Record,153,8)
			$Indx_EaSize = Dec(_SwapEndian($Indx_EaSize),2)
			If $Indx_EaSize < 8 Then Return SetError(19,0,0)
	EndSelect

	$Indx_NameLength = StringMid($Record,161,2)
	$Indx_NameLength = Dec($Indx_NameLength)
	If $Indx_NameLength = 0 Then Return SetError(20,0,0)
	$Indx_NameSpace = StringMid($Record,163,2)
	Select
		Case $Indx_NameSpace = "00"	;POSIX
			$Indx_NameSpace = "POSIX"
		Case $Indx_NameSpace = "01"	;WIN32
			$Indx_NameSpace = "WIN32"
		Case $Indx_NameSpace = "02"	;DOS
			$Indx_NameSpace = "DOS"
		Case $Indx_NameSpace = "03"	;DOS+WIN32
			$Indx_NameSpace = "DOS+WIN32"
		Case Else
			$Indx_NameSpace = "Unknown"
	EndSelect
	If $Indx_NameSpace = "Unknown" Then Return SetError(21,0,0)
	$Indx_FileName = StringMid($Record,165,$Indx_NameLength*4)
	$NameTest = 1
	Select
		Case $ExtendedNameCheckAll
;			_DumpOutput("$ExtendedNameCheckAll: " & $ExtendedNameCheckAll & @CRLF)
			$NameTest = _ValidateCharacterAndWindowsFileName($Indx_FileName)
		Case $ExtendedNameCheckChar
;			_DumpOutput("$ExtendedNameCheckChar: " & $ExtendedNameCheckChar & @CRLF)
			$NameTest = _ValidateCharacter($Indx_FileName)
		Case $ExtendedNameCheckWindows
;			_DumpOutput("$ExtendedNameCheckWindows: " & $ExtendedNameCheckWindows & @CRLF)
			$NameTest = _ValidateWindowsFileName($Indx_FileName)
	EndSelect
	If Not $NameTest Then Return SetError(22,0,0)
	$Indx_FileName = BinaryToString("0x"&$Indx_FileName,2)

	If @error Or $Indx_FileName = "" Then Return SetError(23,0,0)
	Return 1
EndFunc

Func _DecodeTimestamp($StampDecode)
	$StampDecode = _SwapEndian($StampDecode)
	$StampDecode_tmp = _WinTime_UTCFileTimeToLocalFileTime("0x" & $StampDecode)
	$StampDecode = _WinTime_UTCFileTimeFormat(Dec($StampDecode,2) - $tDelta, $DateTimeFormat, $TimestampPrecision)
	If @error Then
		$StampDecode = $TimestampErrorVal
	ElseIf $TimestampPrecision = 3 Then
		$StampDecode = $StampDecode & $PrecisionSeparator2 & _FillZero(StringRight($StampDecode_tmp, 4))
	EndIf
	Return $StampDecode
EndFunc

Func _GetReparseType($ReparseType)
	;http://msdn.microsoft.com/en-us/library/dd541667(v=prot.10).aspx
	;http://msdn.microsoft.com/en-us/library/windows/desktop/aa365740(v=vs.85).aspx
	Select
		Case $ReparseType = '0x00000000'
			Return 'ZERO'
		Case $ReparseType = '0x80000005'
			Return 'DRIVER_EXTENDER'
		Case $ReparseType = '0x80000006'
			Return 'HSM2'
		Case $ReparseType = '0x80000007'
			Return 'SIS'
		Case $ReparseType = '0x80000008'
			Return 'WIM'
		Case $ReparseType = '0x80000009'
			Return 'CSV'
		Case $ReparseType = '0x8000000A'
			Return 'DFS'
		Case $ReparseType = '0x8000000B'
			Return 'FILTER_MANAGER'
		Case $ReparseType = '0x80000012'
			Return 'DFSR'
		Case $ReparseType = '0x80000013'
			Return 'DEDUP'
		Case $ReparseType = '0x80000014'
			Return 'NFS'
		Case $ReparseType = '0xA0000003'
			Return 'MOUNT_POINT'
		Case $ReparseType = '0xA000000C'
			Return 'SYMLINK'
		Case $ReparseType = '0xC0000004'
			Return 'HSM'
		Case $ReparseType = '0x80000015'
			Return 'FILE_PLACEHOLDER'
		Case $ReparseType = '0x80000017'
			Return 'WOF'
		Case Else
			Return 'UNKNOWN(' & $ReparseType & ')'
	EndSelect
EndFunc

; start: by Ascend4nt -----------------------------
Func _WinTime_GetUTCToLocalFileTimeDelta()
	Local $iUTCFileTime=864000000000		; exactly 24 hours from the origin (although 12 hours would be more appropriate (max variance = 12))
	$iLocalFileTime=_WinTime_UTCFileTimeToLocalFileTime($iUTCFileTime)
	If @error Then Return SetError(@error,@extended,-1)
	Return $iLocalFileTime-$iUTCFileTime	; /36000000000 = # hours delta (effectively giving the offset in hours from UTC/GMT)
EndFunc

Func _WinTime_UTCFileTimeToLocalFileTime($iUTCFileTime)
	If $iUTCFileTime<0 Then Return SetError(1,0,-1)
	Local $aRet=DllCall($_COMMON_KERNEL32DLL,"bool","FileTimeToLocalFileTime","uint64*",$iUTCFileTime,"uint64*",0)
	If @error Then Return SetError(2,@error,-1)
	If Not $aRet[0] Then Return SetError(3,0,-1)
	Return $aRet[2]
EndFunc

Func _WinTime_UTCFileTimeFormat($iUTCFileTime,$iFormat=4,$iPrecision=0,$bAMPMConversion=False)
;~ 	If $iUTCFileTime<0 Then Return SetError(1,0,"")	; checked in below call

	; First convert file time (UTC-based file time) to 'local file time'
	Local $iLocalFileTime=_WinTime_UTCFileTimeToLocalFileTime($iUTCFileTime)
	If @error Then Return SetError(@error,@extended,"")
	; Rare occassion: a filetime near the origin (January 1, 1601!!) is used,
	;	causing a negative result (for some timezones). Return as invalid param.
	If $iLocalFileTime<0 Then Return SetError(1,0,"")

	; Then convert file time to a system time array & format & return it
	Local $vReturn=_WinTime_LocalFileTimeFormat($iLocalFileTime,$iFormat,$iPrecision,$bAMPMConversion)
	Return SetError(@error,@extended,$vReturn)
EndFunc

Func _WinTime_LocalFileTimeFormat($iLocalFileTime,$iFormat=4,$iPrecision=0,$bAMPMConversion=False)
;~ 	If $iLocalFileTime<0 Then Return SetError(1,0,"")	; checked in below call

	; Convert file time to a system time array & return result
	Local $aSysTime=_WinTime_LocalFileTimeToSystemTime($iLocalFileTime)
	If @error Then Return SetError(@error,@extended,"")

	; Return only the SystemTime array?
	If $iFormat=0 Then Return $aSysTime

	Local $vReturn=_WinTime_FormatTime($aSysTime[0],$aSysTime[1],$aSysTime[2],$aSysTime[3], _
		$aSysTime[4],$aSysTime[5],$aSysTime[6],$aSysTime[7],$iFormat,$iPrecision,$bAMPMConversion)
	Return SetError(@error,@extended,$vReturn)
EndFunc

Func _WinTime_LocalFileTimeToSystemTime($iLocalFileTime)
	Local $aRet,$stSysTime,$aSysTime[8]=[-1,-1,-1,-1,-1,-1,-1,-1]

	; Negative values unacceptable
	If $iLocalFileTime<0 Then Return SetError(1,0,$aSysTime)

	; SYSTEMTIME structure [Year,Month,DayOfWeek,Day,Hour,Min,Sec,Milliseconds]
	$stSysTime=DllStructCreate("ushort[8]")

	$aRet=DllCall($_COMMON_KERNEL32DLL,"bool","FileTimeToSystemTime","uint64*",$iLocalFileTime,"ptr",DllStructGetPtr($stSysTime))
	If @error Then Return SetError(2,@error,$aSysTime)
	If Not $aRet[0] Then Return SetError(3,0,$aSysTime)
	Dim $aSysTime[8]=[DllStructGetData($stSysTime,1,1),DllStructGetData($stSysTime,1,2),DllStructGetData($stSysTime,1,4),DllStructGetData($stSysTime,1,5), _
		DllStructGetData($stSysTime,1,6),DllStructGetData($stSysTime,1,7),DllStructGetData($stSysTime,1,8),DllStructGetData($stSysTime,1,3)]
	Return $aSysTime
EndFunc

Func _WinTime_FormatTime($iYear,$iMonth,$iDay,$iHour,$iMin,$iSec,$iMilSec,$iDayOfWeek,$iFormat=4,$iPrecision=0,$bAMPMConversion=False)
	Local Static $_WT_aMonths[12]=["January","February","March","April","May","June","July","August","September","October","November","December"]
	Local Static $_WT_aDays[7]=["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]

	If Not $iFormat Or $iMonth<1 Or $iMonth>12 Or $iDayOfWeek>6 Then Return SetError(1,0,"")

	; Pad MM,DD,HH,MM,SS,MSMSMSMS as necessary
	Local $sMM=StringRight(0&$iMonth,2),$sDD=StringRight(0&$iDay,2),$sMin=StringRight(0&$iMin,2)
	; $sYY = $iYear	; (no padding)
	;	[technically Year can be 1-x chars - but this is generally used for 4-digit years. And SystemTime only goes up to 30827/30828]
	Local $sHH,$sSS,$sMS,$sAMPM

	; 'Extra precision 1': +SS (Seconds)
	If $iPrecision Then
		$sSS=StringRight(0&$iSec,2)
		; 'Extra precision 2': +MSMSMSMS (Milliseconds)
		If $iPrecision>1 Then
;			$sMS=StringRight('000'&$iMilSec,4)
			$sMS=StringRight('000'&$iMilSec,3);Fixed an erronous 0 in front of the milliseconds
		Else
			$sMS=""
		EndIf
	Else
		$sSS=""
		$sMS=""
	EndIf
	If $bAMPMConversion Then
		If $iHour>11 Then
			$sAMPM=" PM"
			; 12 PM will cause 12-12 to equal 0, so avoid the calculation:
			If $iHour=12 Then
				$sHH="12"
			Else
				$sHH=StringRight(0&($iHour-12),2)
			EndIf
		Else
			$sAMPM=" AM"
			If $iHour Then
				$sHH=StringRight(0&$iHour,2)
			Else
			; 00 military = 12 AM
				$sHH="12"
			EndIf
		EndIf
	Else
		$sAMPM=""
		$sHH=StringRight(0 & $iHour,2)
	EndIf

	Local $sDateTimeStr,$aReturnArray[3]

	; Return an array? [formatted string + "Month" + "DayOfWeek"]
	If BitAND($iFormat,0x10) Then
		$aReturnArray[1]=$_WT_aMonths[$iMonth-1]
		If $iDayOfWeek>=0 Then
			$aReturnArray[2]=$_WT_aDays[$iDayOfWeek]
		Else
			$aReturnArray[2]=""
		EndIf
		; Strip the 'array' bit off (array[1] will now indicate if an array is to be returned)
		$iFormat=BitAND($iFormat,0xF)
	Else
		; Signal to below that the array isn't to be returned
		$aReturnArray[1]=""
	EndIf

	; Prefix with "DayOfWeek "?
	If BitAND($iFormat,8) Then
		If $iDayOfWeek<0 Then Return SetError(1,0,"")	; invalid
		$sDateTimeStr=$_WT_aDays[$iDayOfWeek]&', '
		; Strip the 'DayOfWeek' bit off
		$iFormat=BitAND($iFormat,0x7)
	Else
		$sDateTimeStr=""
	EndIf

	If $iFormat<2 Then
		; Basic String format: YYYYMMDDHHMM[SS[MSMSMSMS[ AM/PM]]]
		$sDateTimeStr&=$iYear&$sMM&$sDD&$sHH&$sMin&$sSS&$sMS&$sAMPM
	Else
		; one of 4 formats which ends with " HH:MM[:SS[:MSMSMSMS[ AM/PM]]]"
		Switch $iFormat
			; /, : Format - MM/DD/YYYY
			Case 2
				$sDateTimeStr&=$sMM&'/'&$sDD&'/'
			; /, : alt. Format - DD/MM/YYYY
			Case 3
				$sDateTimeStr&=$sDD&'/'&$sMM&'/'
			; "Month DD, YYYY" format
			Case 4
				$sDateTimeStr&=$_WT_aMonths[$iMonth-1]&' '&$sDD&', '
			; "DD Month YYYY" format
			Case 5
				$sDateTimeStr&=$sDD&' '&$_WT_aMonths[$iMonth-1]&' '
			Case 6
				$sDateTimeStr&=$iYear&'-'&$sMM&'-'&$sDD
				$iYear=''
			Case Else
				Return SetError(1,0,"")
		EndSwitch
		$sDateTimeStr&=$iYear&' '&$sHH&':'&$sMin
		If $iPrecision Then
			$sDateTimeStr&=':'&$sSS
;			If $iPrecision>1 Then $sDateTimeStr&=':'&$sMS
			If $iPrecision>1 Then $sDateTimeStr&=$PrecisionSeparator&$sMS
		EndIf
		$sDateTimeStr&=$sAMPM
	EndIf
	If $aReturnArray[1]<>"" Then
		$aReturnArray[0]=$sDateTimeStr
		Return $aReturnArray
	EndIf
	Return $sDateTimeStr
EndFunc
; end: by Ascend4nt ----------------------------

Func _FillZero($inp)
	Local $inplen, $out, $tmp = ""
	$inplen = StringLen($inp)
	For $i = 1 To 4 - $inplen
		$tmp &= "0"
	Next
	$out = $tmp & $inp
	Return $out
EndFunc

Func _File_Attributes($FAInput)
	Local $FAOutput = ""
	If BitAND($FAInput, 0x0001) Then $FAOutput &= 'read_only+'
	If BitAND($FAInput, 0x0002) Then $FAOutput &= 'hidden+'
	If BitAND($FAInput, 0x0004) Then $FAOutput &= 'system+'
	If BitAND($FAInput, 0x0010) Then $FAOutput &= 'directory1+'
	If BitAND($FAInput, 0x0020) Then $FAOutput &= 'archive+'
	If BitAND($FAInput, 0x0040) Then $FAOutput &= 'device+'
	If BitAND($FAInput, 0x0080) Then $FAOutput &= 'normal+'
	If BitAND($FAInput, 0x0100) Then $FAOutput &= 'temporary+'
	If BitAND($FAInput, 0x0200) Then $FAOutput &= 'sparse_file+'
	If BitAND($FAInput, 0x0400) Then $FAOutput &= 'reparse_point+'
	If BitAND($FAInput, 0x0800) Then $FAOutput &= 'compressed+'
	If BitAND($FAInput, 0x1000) Then $FAOutput &= 'offline+'
	If BitAND($FAInput, 0x2000) Then $FAOutput &= 'not_indexed+'
	If BitAND($FAInput, 0x4000) Then $FAOutput &= 'encrypted+'
	If BitAND($FAInput, 0x8000) Then $FAOutput &= 'integrity_stream+'
	If BitAND($FAInput, 0x10000) Then $FAOutput &= 'virtual+'
	If BitAND($FAInput, 0x20000) Then $FAOutput &= 'no_scrub_data+'
	If BitAND($FAInput, 0x40000) Then $FAOutput &= 'ea+'
	If BitAND($FAInput, 0x10000000) Then $FAOutput &= 'directory2+'
	If BitAND($FAInput, 0x20000000) Then $FAOutput &= 'index_view+'
	$FAOutput = StringTrimRight($FAOutput, 1)
	Return $FAOutput
EndFunc

Func _ValidateCharacter($InputString)
;ConsoleWrite("$InputString: " & $InputString & @CRLF)
	$StringLength = StringLen($InputString)
	For $i = 1 To $StringLength Step 4
		$TestChunk = StringMid($InputString,$i,4)
		$TestChunk = Dec(_SwapEndian($TestChunk),2)
		If ($TestChunk > 31 And $TestChunk < 256) Then
			ContinueLoop
		Else
			Return 0
		EndIf
	Next
	Return 1
EndFunc

Func _ValidateAnsiName($InputString)
;ConsoleWrite("$InputString: " & $InputString & @CRLF)
	$StringLength = StringLen($InputString)
	For $i = 1 To $StringLength Step 4
		$TestChunk = StringMid($InputString,$i,4)
		$TestChunk = Dec(_SwapEndian($TestChunk),2)
		If ($TestChunk >= 32 And $TestChunk < 127) Then
			ContinueLoop
		Else
			Return 0
		EndIf
	Next
	Return 1
EndFunc

Func _ValidateWindowsFileName($InputString)
	$StringLength = StringLen($InputString)
	For $i = 1 To $StringLength Step 4
		$TestChunk = StringMid($InputString,$i,4)
		$TestChunk = Dec(_SwapEndian($TestChunk),2)
		If ($TestChunk <> 47 And $TestChunk <> 92 And $TestChunk <> 58 And $TestChunk <> 42 And $TestChunk <> 63 And $TestChunk <> 34 And $TestChunk <> 60 And $TestChunk <> 62) Then
			ContinueLoop
		Else
			Return 0
		EndIf
	Next
	Return 1
EndFunc

Func _ValidateCharacterAndWindowsFileName($InputString)
;ConsoleWrite("$InputString: " & $InputString & @CRLF)
	$StringLength = StringLen($InputString)
	For $i = 1 To $StringLength Step 4
		$TestChunk = StringMid($InputString,$i,4)
		$TestChunk = Dec(_SwapEndian($TestChunk),2)
		If ($TestChunk > 31 And $TestChunk < 256) Then
			If ($TestChunk <> 47 And $TestChunk <> 92 And $TestChunk <> 58 And $TestChunk <> 42 And $TestChunk <> 63 And $TestChunk <> 34 And $TestChunk <> 60 And $TestChunk <> 62) Then
				ContinueLoop
			Else
				Return 0
			EndIf
			ContinueLoop
		Else
			Return 0
		EndIf
	Next
	Return 1
EndFunc