package host;

import shared.NetTools;
import shared.BytesTools;
import js.html.Console;
import js.node.Buffer;
import haxe.io.Bytes;
import js.node.Net;
import js.node.net.Socket;

/**
	The one that connects to the local server!
**/
class HostSocket {
	public final clientID:Int;
	private var socket:Socket;
	public var ready = false;
	public var sendOnReady:Array<Bytes> = [];
	public function new(id:Int) {
		clientID = id;
		socket = Net.createConnection(Host.connectPort, Host.connectIP, () -> {
			ready = true;
			for (b in sendOnReady) send(b);
			sendOnReady.resize(0);
		});
		socket.on("data", (data:Any) -> {
			var bytes = BytesTools.dataToBytes(data);
			var relay = Host.relay;
			var out = relay.start(Data, bytes.length + 4);
			out.writeInt32(clientID);
			out.writeBytes(bytes, 0, bytes.length);
			relay.send(out);
		});
		socket.on("error", (e) -> {
			Console.warn('Error on socket $clientID:', e);
			destroy();
		});
		socket.on("close", (e) -> {
			Console.warn('Socket $clientID closed:', e);
			destroy();
		});
	}
	public function destroy() {
		if (socket == null) return;
		try {
			socket.destroy();
		} catch (x:Dynamic) {
			Console.warn("Destroy error:", x);
		}
		if (Host.clients.has(clientID)) {
			var out = Host.relay.start(DisconnectedFromServerOnHost);
			out.writeInt32(clientID);
			Host.relay.send(out);
			Host.clients.delete(clientID);
		}
		socket = null;
	}
	public function send(bytes:Bytes) {
		if (!ready) {
			sendOnReady.push(bytes);
			return;
		}
		var arrayBuffer = bytes.getData();
		var nativeBuffer = Buffer.from(arrayBuffer, 0, bytes.length);
		socket.write(nativeBuffer);
	}
	@:keep public function toString() {
		return NetTools.printLocalAddress(socket);
	}
}