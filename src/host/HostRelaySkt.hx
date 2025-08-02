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
				var clientID = reader.readInt32();
				var skt = new HostSocket(clientID);
				Console.log('Created socket $clientID ${skt.toString()}');
				Host.clients.set(clientID, skt);
			};
			case DestroyClient: {
				var clientID = reader.readInt32();
				var skt = Host.clients.get(clientID);
				if (skt != null) {
					Console.log('Destroyed socket $clientID ${skt.toString()}');
					skt.destroy();
					Host.clients.delete(clientID);
				} else {
					Console.warn('Asked to destroy nonexistent socket $clientID');
				}
			};
			case Data: {
				var clientID = reader.readInt32();
				var skt = Host.clients.get(clientID);
				if (skt == null) {
					Console.warn('Got ${size - 5} bytes of data for nonexistent socket $clientID');
					return;
				}
				var dataSize = size - 5;
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
		//PacketHelper.print(buf.getBytes());
		return super.send(buf);
	}
}