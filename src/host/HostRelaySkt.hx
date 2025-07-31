package host;

import haxe.io.BytesOutput;
import js.node.Buffer;
import haxe.io.Bytes;
import js.html.Console;
import shared.SocketWrap;
import shared.*;

class HostRelaySkt extends SocketWrap<PacketID> {
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
			case CreateClient: {
				if (Host.socket != null) {
					Console.warn("Asked to re-create a client..?");
					Host.socket.destroy();
				}
				Host.socket = new HostSocket();
			};
			case DestroyClient: {
				if (Host.socket != null) {
					Host.socket.destroy();
				}
			};
			case Data: {
				var skt = Host.socket;
				if (skt == null) return;
				var dataSize = size - 1;
				var bytes = Bytes.alloc(dataSize);
				reader.readBytes(bytes, 0, dataSize);
				skt.send(bytes);
			};
			case Bye: handleKicker(reader);
			default: {
				throw "Unknown packet type " + pid;
			};
		}
	}
	override function send(buf:BytesOutput) {
		PacketHelper.print(buf.getBytes());
		super.send(buf);
	}
}