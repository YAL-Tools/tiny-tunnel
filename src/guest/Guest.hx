package guest;

import shared.SocketWrap;
import js.node.Buffer;
import js.node.Net;
import js.html.Console;
import shared.CliTools;
import js.node.net.Socket;
using shared.BytesTools;

class Guest {
	public static var relay:GuestRelaySkt = null;
	public static var socket:Socket = null;
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
		var listener = Net.createServer(SocketWrap.createServerOptions(), (skt:Socket) -> {
			Console.log('Local socket connected: (${skt.remoteFamily}, "${skt.remoteAddress}", ${skt.remotePort})');
			if (socket != null) {
				Console.warn("But we already have a socket! Re-binding");
			}
			socket = skt;
			relay.sendSimple(CreateClient);
			skt.on("data", (data:Any) -> {
				var buf:Buffer;
				if (data is String) {
					buf = Buffer.from(data);
				} else buf = data;
				//
				var bytes = buf.hxToBytes();
				var b = relay.start(Data, bytes.length + 1);
				b.writeBytes(bytes, 0, bytes.length);
				relay.send(b);
			});
			skt.on("error", (e) -> {
				Console.warn("Socket error:", e);
				try {
					skt.destroy();
				} catch (x:Dynamic) {
					Console.warn("Destroy error:", e);
				}
				if (socket == skt) {
					relay.sendSimple(DestroyClient);
					socket = null;
				}
			});
			skt.on("close", (e) -> {
				Console.warn("Socket closed:", e);
				if (socket == skt) {
					relay.sendSimple(DestroyClient);
					socket = null;
				}
			});
		});
		listener.listen(serverPort);
	}
	public static function main() {
		main_1(Sys.args());
	}
}