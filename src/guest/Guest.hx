package guest;

import shared.NetTools;
import shared.SocketWrap;
import js.node.Buffer;
import js.node.Net;
import js.html.Console;
import shared.CliTools;
import js.node.net.Socket;
import js.lib.Map;
using shared.BytesTools;

class Guest {
	public static var relay:GuestRelaySkt = null;
	public static var clients:Map<Int, Socket> = new Map();
	static var nextClientID = 0;
	public static var password:String = "";
	public static function main_1(args:Array<String>) {
		var relayIP:String = null;
		var relayPort:Int = null;
		var serverPort:Int = null;
		CliTools.parseArgs(args, (name, params) -> {
			switch (name) {
				case "--relay-ip": {
					relayIP = params[0];
					return 1;
				};
				case "--relay-port": {
					relayPort = Std.parseInt(params[0]);
					return 1;
				};
				case "--server-port": {
					serverPort = Std.parseInt(params[0]);
					return 1;
				};
				default: return -1;
			}
		});
		//
		CliTools.requireArg(relayIP, "--relay-ip");
		CliTools.requireArg(relayPort, "--relay-port");
		var relaySocket = null;
		relaySocket = Net.createConnection(relayPort, relayIP, () -> {
			relay = new GuestRelaySkt();
			relay.bind(relaySocket);
			var out = relay.start(AmGuest);
			out.writeCString(password);
			relay.send(out);
		});
		relaySocket.on("error", (e) -> {
			Console.error("Relay connection error:", e);
			Sys.exit(1);
		});
		//
		var listener = NetTools.createServer((skt:Socket) -> {
			var clientID = nextClientID++;
			Console.log('Local socket connected: ' + NetTools.printRemoteAddress(skt) + ', id $clientID');
			clients.set(clientID, skt);
			{
				var out = relay.start(CreateClient);
				out.writeInt32(clientID);
				relay.send(out);
			};
			inline function destroy() {
				if (clients.has(clientID)) {
					var out = relay.start(DestroyClient);
					out.writeInt32(clientID);
					relay.send(out);
					clients.delete(clientID);
				}
			}
			skt.on("data", (data:Any) -> {
				var buf:Buffer;
				if (data is String) {
					buf = Buffer.from(data);
				} else buf = data;
				//
				var bytes = buf.hxToBytes();
				var b = relay.start(Data, bytes.length + 4);
				b.writeInt32(clientID);
				b.writeBytes(bytes, 0, bytes.length);
				relay.send(b);
			});
			skt.on("error", (e) -> {
				Console.warn('Error on socket $clientID:', e);
				try {
					skt.destroy();
				} catch (x:Dynamic) {
					Console.warn("Destroy error:", e);
				}
				destroy();
			});
			skt.on("close", (e) -> {
				Console.warn('Socket $clientID closed:', e);
				destroy();
			});
		});
		listener.listen(serverPort);
		Console.log('Listening on port $serverPort');
	}
	public static function main() {
		main_1(Sys.args());
	}
}