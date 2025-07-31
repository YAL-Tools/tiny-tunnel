package guest;

import js.node.Buffer;
import haxe.io.Bytes;
import js.html.Console;
import shared.SocketWrap;
import shared.*;

class GuestRelaySkt extends SocketWrap<PacketID> {
	public function new() {
		//
	}
	override function destroy(?code:ErrorCode, ?reason:String) {
		if (destroyPre()) return;
		super.destroy(code, reason);
		Console.error("Disconnected from relay!");
		Sys.exit(1);
	}
	override function getKicker():PacketID {
		return Bye;
	}
	override function onPacket(reader:BytesInputEx, size:Int) {
		var pid:PacketID = reader.readByte();
		if (debug) Console.info("Relay:", pid.getName());
		switch (pid) {
			case HelloYes: {
				Console.log("Relay connection confirmed.");
			};
			case Data: {
				var skt = Guest.socket;
				if (skt == null) return;
				var dataSize = size - 1;
				var bytes = Bytes.alloc(dataSize);
				reader.readBytes(bytes, 0, dataSize);
				var arrayBuffer = bytes.getData();
				var nativeBuffer = Buffer.from(arrayBuffer, 0, dataSize);
				skt.write(nativeBuffer);
			};
			case DisconnectedFromServerOnHost: {
				var skt = Guest.socket;
				if (skt == null) return;
				Console.warn("Socket destroyed on host side");
				try {
					skt.destroy();
				} catch (x:Dynamic) {
					//
				}
				Guest.socket = null;
			};
			case Bye: handleKicker(reader);
			default: {
				throw "Unknown packet type " + pid;
			};
		}
	}
}