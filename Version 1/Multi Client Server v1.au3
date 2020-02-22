#cs ----------------------------------------------------------------------------

	AutoIt Version: 3.3.8.1
	Author:         Caleb41610

	Script Function:
	* Server supporting multiple connecting clients
#ce ----------------------------------------------------------------------------

;Includes / Opt / Exit

SplashTextOn( "Loading", "Loading...")

#region ; ---------------------------------------------------------------------------------------------------------------------------------------------------
#include <GUIConstantsEx.au3>
#include <Array.au3>
#include <WindowsConstants.au3>
#include <GuiMenu.au3>
#include <Crypt.au3>
#include <GDIPlus.au3>
Opt("TCPTimeout", 0)
OnAutoitExitRegister("_ServerClose")
#endregion ; ------------------------------------------------------------------------------------------------------------------------------------------------



; Starts up TCP, Crypt and GDIPlus
#region ; ---------------------------------------------------------------------------------------------------------------------------------------------------
TCPStartup()
_GDIPlus_Startup()
_Crypt_Startup()
#endregion ; ------------------------------------------------------------------------------------------------------------------------------------------------


; Variables
#region ; ---------------------------------------------------------------------------------------------------------------------------------------------------
Global $ini = @ScriptDir & "\" & "Keys.ini"
Global $IP = "0.0.0.0"
Global $PORT = "1337"
Global $max_clients = 1000
Global $client_number_array = 5
Global $clients[$max_clients + 1][$client_number_array + 1]
Global $socket_listen = -1
Global $current_connections = 0
$clients[0][0] = 0
Global $bad_connection_timer = TimerInit()
Global Enum $message_client = 1020304001, $remove_client
Global $WS2_32 = DllOpen("Ws2_32.dll")

Global $number_of_packet_types = 50
Global $packet[$number_of_packet_types + 1]

$packet[0] = "_PACKET_SPLIT_"
$packet[1] = "_PACKET_END_"
For $i = 2 To $number_of_packet_types
	Select
		Case $i <= 9
			$packet[$i] = "_PACKET_TYPE_000" & $i & "_"
		Case $i <= 99
			$packet[$i] = "_PACKET_TYPE_00" & $i & "_"
		Case $i <= 999
			$packet[$i] = "_PACKET_TYPE_0" & $i & "_"
	EndSelect
Next

; Example for packet type usage.  Here are some example packet rules:
; (only examples. you have to code packet rules in to the _PacketProcessor() function.)
; _PACKET_TYPE_0005_ is a plain-text message.
; _PACKET_TYPE_0006_ is a client name.
; _PACKET_TYPE_0007_ is user credentials

; Now here is an example packet.
; _PACKET_TYPE_0005_This is a message_PACKET_SPLIT__PACKET_TYPE_0006_Caleb_PACKET_SPLIT__PACKET_TYPE_0007_USER:CALEB|PASS:TEST_PACKET_SPLIT_

; By our packet handler, this would be split in to 3 packets:
; _PACKET_TYPE_0005_This is a message
; _PACKET_TYPE_0006_Caleb
; _PACKET_TYPE_0007_USER:CALEB|PASS:TEST

; Then the packets are checked against their type, and handled according to our _PacketProcessor() function.
; Message	This is a message
; Name		Caleb
; Login		USER:CALEB|PASS:TEST

; Clients[$i][0] = Socket number
; Clients[$i][1] = ListView handle
; Clients[$i][2] = complete packets
; Clients[$i][3] = incomplete packets
; Clients[$i][4] = Timeout (not added yet)

#endregion ; ------------------------------------------------------------------------------------------------------------------------------------------------

; GUI
#region ; ---------------------------------------------------------------------------------------------------------------------------------------------------
Global $gui = GUICreate("Not Listening", 300, 600)
Global $listview = GUICtrlCreateListView("#|Socket|IP|User@Computer", 5, 5, 290, 570)
Global $menu = GUICtrlCreateMenu("Listen")
Global $listen = GUICtrlCreateMenuItem("On", $menu, 2, 1)
Global $stoplisten = GUICtrlCreateMenuItem("Off", $menu, 3, 1)
GUISetState(@SW_SHOW)
Global $popup_menu = _GUICtrlMenu_CreatePopup()
_GUICtrlMenu_InsertMenuItem($popup_menu, 0, "Message", $message_client)
_GUICtrlMenu_InsertMenuItem($popup_menu, 1, "Disconnect", $remove_client)
GUIRegisterMsg($WM_COMMAND, "WM_COMMAND")
GUIRegisterMsg($WM_NOTIFY, "WM_NOTIFY")
#endregion ; ------------------------------------------------------------------------------------------------------------------------------------------------



; Start the scripts main function
SplashOff()
_Main()



; Core Script Functions
#region ; ---------------------------------------------------------------------------------------------------------------------------------------------------
Func _Main()
	While 1
		$msg = GUIGetMsg()
		If $msg = $GUI_EVENT_CLOSE Then
			_ServerClose()
		EndIf
		If $msg = $stoplisten Then
			_StopListen()
		EndIf
		If $msg = $listen Then
			_Listen()
		EndIf
		_CheckNewConnections()
		_CheckNewMessages()
	WEnd
EndFunc   ;==>_Main

Func _CheckNewConnections()
	Local $socket_accepted = TCPAccept($socket_listen)
	If $socket_accepted = -1 Then
		Return
	EndIf
	If $current_connections >= $max_clients Then
		TCPSend($socket_accepted, "MAX_CONNECTIONS_REACHED")
		TCPCloseSocket($socket_accepted)
	Else
		_AddClient($socket_accepted)
	EndIf
EndFunc   ;==>_CheckNewConnections

Func _CheckBadConnections()
	If $current_connections < 1 Then Return
	Local $new_current_connections = 0
	For $i = 1 To $current_connections
		TCPSend($clients[$i][0], "PING")
		If @error Then
			TCPCloseSocket($clients[$i][0])
			GUICtrlDelete($clients[$i][1])
			$clients[$i][0] = -1
			$clients[$i][1] = ""
			ContinueLoop
		Else
			$new_current_connections += 1
		EndIf
	Next
	If $new_current_connections < $current_connections Then
		TrayTip("Connection(s) Lost", $current_connections - $new_current_connections & " client(s) disconnected." & @CRLF & $new_current_connections & " total connection(s) still active.", 1, 1)
		_ClientArrayFix($new_current_connections)
	EndIf
EndFunc   ;==>_CheckBadConnections

Func _CheckNewMessages()
	If $current_connections < 1 Then Return
	For $i = 1 To $current_connections
		Local $received_message = TCPRecv($clients[$i][0], 512)
		If @error Then
			_CheckBadConnections()
			ExitLoop
		EndIf
		If $received_message <> "" Then
			$clients[$i][3] &= $received_message
			;_PacketHandler($received_message, $clients[$i][0], $i)
			$received_message = ""
		EndIf
	Next
EndFunc   ;==>_CheckNewMessages

Func _AddClient($client_socket)
	$current_connections += 1
	$clients[$current_connections][0] = $client_socket
	$clients[$current_connections][1] = GUICtrlCreateListViewItem($current_connections & "|" & $client_socket & "|" & SocketToIP($client_socket), $listview)
	TrayTip("New Connection", "IP: " & SocketToIP($client_socket) & @CRLF & "Socket: " & $client_socket & @CRLF & "Total Connections: " & $current_connections, 4, 1)
EndFunc   ;==>_AddClient

Func _ClientArrayFix($new_current_connections)
	If $new_current_connections < 1 Then
		$current_connections = $new_current_connections
		Return
	EndIf
	Local $new_number = 1
	Local $temp_array[$max_clients + 1][$client_number_array + 1]
	For $i = 1 To $max_clients
		If $clients[$i][0] = -1 Or $clients[$i][0] = "" Then ContinueLoop
		For $j = 0 To $client_number_array
			$temp_array[$new_number][$j] = $clients[$i][$j]
		Next
		$new_number += 1
	Next
	$current_connections = $new_current_connections
	$clients = $temp_array
	For $i = 1 To $current_connections
		GUICtrlSetData($clients[$i][1], $i)
	Next
EndFunc   ;==>_ClientArrayFix

Func _Listen()
	If $socket_listen <> -1 Then
		MsgBox(16, "Error", "Socket already open.")
		Return
	EndIf
	$socket_listen = TCPListen($IP, $PORT, $max_clients)
	WinSetTitle("Not Listening", "", "Listening on " & $PORT)
	If $socket_listen = -1 Then
		MsgBox(16, "Error", "Unable to open socket.")
		Return
	EndIf
EndFunc   ;==>_Listen

Func _StopListen()
	If $socket_listen = -1 Then
		MsgBox(16, "Error", "Socket already closed.")
		Return
	EndIf
	TCPCloseSocket($socket_listen)
	$socket_listen = -1
	WinSetTitle("Listening on " & $PORT, "", "Not Listening")
EndFunc   ;==>_StopListen

Func SocketToIP($SHOCKET)
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
EndFunc   ;==>SocketToIP

Func _ServerClose()
	If $current_connections <= 1 Then
		For $i = 1 To $current_connections
			TCPSend($clients[$i][0], "SERVER_SHUTDOWN")
			TCPCloseSocket($clients[$i][0])
		Next
	EndIf
	TCPShutdown()
	_GDIPlus_Shutdown()
	_Crypt_Shutdown()
	Exit
EndFunc
#endregion ; ------------------------------------------------------------------------------------------------------------------------------------------------


; Menu functions
#region ; ---------------------------------------------------------------------------------------------------------------------------------------------------
Func _Message()
	Local $selected = GUICtrlRead(GUICtrlRead($listview))
	If Not $selected <> "" Then
		MsgBox(16, "Error", "Please select a server first.")
		Return
	EndIf
	Local $array = StringSplit($selected, "|", 1)
	$message = InputBox("", "Enter a message to send to the client.")
	If $message = "" Then
		MsgBox(16, "Error", "You did not enter a message to send.")
		Return
	EndIf
	TCPSend($clients[$array[1]][0], "TEXT_MSG" & $message)
EndFunc   ;==>_Message

Func _RemoveClient()
	Local $selected = GUICtrlRead(GUICtrlRead($listview))
	If Not $selected <> "" Then
		MsgBox(16, "Error", "Please select a server first.")
		Return
	EndIf
	Local $array = StringSplit($selected, "|", 1)
	TCPSend($clients[$array[1]][0], "CLOSING_CLIENT_SOCKET")
	TCPCloseSocket($clients[$array[1]][0])
	_CheckBadConnections()
EndFunc   ;==>_RemoveClient
#endregion ; ------------------------------------------------------------------------------------------------------------------------------------------------



; Menu functions
#region ; ---------------------------------------------------------------------------------------------------------------------------------------------------
Func WM_NOTIFY($hWnd, $iMsg, $iwParam, $ilParam)
	Local $iIDFrom, $iCode, $tNMHDR, $tInfo

	$tNMHDR = DllStructCreate($tagNMHDR, $ilParam)
	$iIDFrom = DllStructGetData($tNMHDR, "IDFrom")
	$iCode = DllStructGetData($tNMHDR, "Code")
	Switch $iIDFrom
		Case $listview
			Switch $iCode
				Case $NM_RCLICK
					$tInfo = DllStructCreate($tagNMLISTVIEW, $ilParam)
					If DllStructGetData($tInfo, "Item") > -1 Then
						_GUICtrlMenu_TrackPopupMenu($popup_menu, $gui)
					EndIf
			EndSwitch
	EndSwitch
	Return $GUI_RUNDEFMSG
EndFunc   ;==>WM_NOTIFY

Func WM_COMMAND($hWnd, $iMsg, $iwParam, $ilParam)
	Switch $iwParam
		Case $message_client
			_Message()
		Case $remove_client
			_RemoveClient()
	EndSwitch
EndFunc   ;==>WM_COMMAND
#endregion ; ------------------------------------------------------------------------------------------------------------------------------------------------
