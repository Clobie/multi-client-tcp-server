#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.8.1
 Author:         Caleb41610

 Script Function:
	Constant variables for my Multiple Connection TCP Server.

#ce ----------------------------------------------------------------------------

; Example packet structure for a message.  This applies to all packet types.
;
;
; 				Define packet type	       Verify Integrity						 Options				   Actual Data
;
;				|````````````````||``````````````````````````````||````````````||````````||````````````||````````````````||``````````|
;				|     Prefix	 ||		        Hash	  		 ||   Divider  ||  Data1 ||   Divider  ||      Data2     ||  Suffix	 |
;				|................||..............................||............||........||............||................||..........|
; Example:		[PACKET_TYPE_0001]395b22232b33b983c54856c8781351c0[PACKET_SPLIT]MessageBox[PACKET_SPLIT]This is a message![PACKET_END]



; Example for sending packets



; Packet Prefixes
Global Const $PacketSystem 			= "[PACKET_TYPE_0001]" ; System messages (Close, Restart, etc)
Global Const $PacketMessage 		= "[PACKET_TYPE_0002]" ; Direct raw messages
Global Const $PacketBroadcast 		= "[PACKET_TYPE_0003]" ; Broadcasted raw messages
Global Const $PacketRequest 		= "[PACKET_TYPE_0004]" ; Requests (ex: request screenshot, request idletime, request uptime, request sys info, etc.)
Global Const $PacketClientName 		= "[PACKET_TYPE_0005]" ; Username
Global Const $PacketLogin 			= "[PACKET_TYPE_0006]" ; Login
Global Const $PacketBinaryUpdate 	= "[PACKET_TYPE_0007]" ; Update (Base64 of exe binary)
Global Const $PacketURLUpdate 		= "[PACKET_TYPE_0008]" ; Update (URL)
Global Const $PacketJPG 			= "[PACKET_TYPE_0009]" ; Base64 of JPG binary (screenshot)
Global Const $PacketTest 			= "[PACKET_TYPE_0010]" ; Listview test. System info.

; Packet Section Split
Global Const $PacketDivider = "[PACKET_SPLIT]" ; Defines where to split sections of a packet

; Packet Suffix
Global Const $PacketEND = "[PACKET_END]" ; Defines the end of a packet