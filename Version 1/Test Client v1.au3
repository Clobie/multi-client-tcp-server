#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.8.1
 Author:         myName

 Script Function:
	Template AutoIt script.

#ce ----------------------------------------------------------------------------

; Script Start - Add your code below here

#include <GUIConstantsEx.au3>
#include <EditConstants.au3>
#include <GuiEdit.au3>
#include <WindowsConstants.au3>

$clientname = @UserName & "@" & @ComputerName
$ip = @IPAddress1
$port = 1337
$packet_end = "_PACKET_END__PACKET_SPLIT_"
TCPStartup()
$socket = TCPConnect($ip, $port)
Global $PacketEND = "[PACKET_END]" ; Defines the end of a packet
Global $PacketMSG = "[PACKET_TYPE_0001]" ; Defines the beginning of a packet (Raw message)
Sleep(1000)
For $i = 1 To 5
	TCPSend($socket, $PacketMSG & "Test" & $i & $PacketEND)
Next


$gui = GUICreate("test client", 300, 250)
$msgbox = GUICtrlCreateEdit("", 5, 5, 290, 130, $ES_READONLY + $WS_VSCROLL)
$textbox = GUICtrlCreateEdit("", 5, 140, 290, 50)
$button = GUICtrlCreateButton("Send", 5, 195, 290, 40)
GUISetState(@SW_SHOW, $gui)

While 1
	$msg = GUIGetMsg()
	If $msg = $GUI_EVENT_CLOSE Then
		Exit
	EndIf
	If $msg = $button Then
		_Send()
	EndIf
	$recv = TCPRecv($socket, 256)
	If StringLeft($recv, 8) = "TEXT_MSG" Then
		_GUICtrlEdit_AppendText($msgbox, "Server: " & StringTrimLeft($recv, 8) & @CRLF)
	EndIf
	If $recv = "CLOSING_CLIENT_SOCKET" Then
		MsgBox(0, "Info", "The server has disconnected you.")
		TCPCloseSocket($socket)
		TCPShutdown()
		Exit
	EndIf
	If $recv = "MAX_CONNECTIONS_REACHED" Then
		MsgBox(16, "Error", "The server has reached the maximum connections possibly.  Try again another time.")
		TCPCloseSocket($socket)
		TCPShutdown()
		Exit
	EndIf
WEnd

Func _Send()
	$message = GUICtrlRead($textbox)
	TCPSend($socket, $PacketMSG & $message & $PacketEND)
	If NOT @error Then
		GUICtrlSetData($textbox, "")
		_GUICtrlEdit_AppendText($msgbox, "You: " & $message & @CRLF)
	Else
		MsgBox(16, "Error", "Could not send message.  Check your connection!")
	EndIf
EndFunc