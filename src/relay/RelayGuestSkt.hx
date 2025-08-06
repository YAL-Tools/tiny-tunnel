package relay;

import js.html.Console;
import js.Node;
import js.node.net.Socket;
import shared.SocketWrap;
import shared.*;
using shared.BytesTools;

class RelayGuestSkt extends SocketWrap<PacketID> {
	public var ready = false;
	public function new() {
		//
	}
	override function destroy(?code:ErrorCode, ?reason:String) {
		if (destroyPre()) return;
		super.destroy(code, reason);
		if (Relay.guest == this) Relay.guest = null;
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
			if (pid != AmGuest) {
				destroy(WantHello);
				return;
			}
			if (reader.readCString() != Relay.password) {
				destroy(WrongPass);
				return;
			}
			ready = true;
			Console.log("Guest confirmed:", this.toString());
			Relay.guest = this;
			sendSimple(HelloYes);
			return;
		}
		inline function forward(show:Bool = true) {
			var host = Relay.host;
			if (host != null) {
				if (show) Console.log("Guest->Host: " + pid.getName());
				var n = size - 1;
				var out = host.start(pid, n);
				out.writeBytesInput(reader, n);
				host.send(out);
			} else {
				if (show) Console.log("Guest->Void: " + pid.getName());
			}
		}
		if (debug) Console.info("Guest:", pid.getName());
		switch (pid) {
			case Data: forward(false);
			case CreateClient: forward();
			case DestroyClient: forward();
			case Bye: handleKicker(reader);
			default: throw "Unknown guest packet type " + pid;
		}
	}
}