package shared;

/**
	Relay<->Guest communication
**/
@:build(shared.AutoEnum.build())
enum abstract PacketID(Int) from Int to Int {
	/** H->R (password) **/
	var AmHost = 0x10;
	/** G->R (password) **/
	var AmGuest = 0x11;
	/** R->HG **/
	var HelloYes = 0x12;
	
	/** G->H **/
	var CreateClient = 0x20;
	/** G->H **/
	var DestroyClient = 0x21;
	
	/** H->G **/
	var DisconnectedFromServerOnHost = 0x22;
	
	/** H<->G **/
	var Data = 0x70;
	
	/** R->HG **/
	var Bye = 0xFF;
	
	@:keep public function getName() {
		return "PacketID(0x" + StringTools.hex(this, 2) + ")";
	}
}