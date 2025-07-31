package relay;
import js.html.Console;
import js.Node;
import js.node.net.Socket;
import shared.*;
import shared.SocketWrap;
using shared.BytesTools;

/**
	Connection to host on the relay
**/
class RelayHostSkt extends SocketWrap<PacketID> {
	public var ready = false;
	public function new() {
		//
	}
	override function destroy(?code:ErrorCode, ?reason:String) {
		if (destroyPre()) return;
		super.destroy(code, reason);
		if (Relay.host == this) Relay.host = null;
	}
	override function getKicker():PacketID {
		return Bye;
	}
	override function bind(skt:Socket) {
		super.bind(skt);
		Node.setTimeout(() -> {
			if (!ready) {
				destroy(SlowHello);
			}
		}, 3000);
	}
	override function onPacket(reader:BytesInputEx, size:Int) {
		var pid:PacketID = reader.readByte();
		if (!ready) {
			if (pid != AmHost) {
				destroy(WantHello);
				return;
			}
			if (reader.readCString() != Relay.password) {
				destroy(WrongPass);
				return;
			}
			ready = true;
			Console.log("Host confirmed:", this.toString());
			Relay.host = this;
			sendSimple(HelloYes);
			return;
		}
		inline function forward() {
			var guest = Relay.guest;
			if (guest != null) {
				var n = size - 1;
				var out = guest.start(pid, n);
				out.writeBytesInput(reader, n);
				guest.send(out);
			}
		}
		if (debug) Console.info("Host:", pid.getName());
		switch (pid) {
			case Data: forward();
			case DestroyClient: forward();
			case DisconnectedFromServerOnHost: forward();
			case Bye: handleKicker(reader);
			default: throw "Unknown host packet type " + pid;
		}
	}
}