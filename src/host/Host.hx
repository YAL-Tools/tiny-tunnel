package host;

import js.node.Buffer;
import js.node.Net;
import js.html.Console;
import shared.CliTools;
import js.node.net.Socket;
import js.lib.Map;
using shared.BytesTools;

class Host {
	public static var relay:HostRelaySkt = null;
	public static var clients:Map<Int, HostSocket> = new Map();
	public static var password:String = "";
	public static var connectIP:String = "127.0.0.1";
	public static var connectPort:Int = null;
	public static function main_1(args:Array<String>) {
		var relayIP:String = null;
		var relayPort:Int = null;
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
				case "--connect-ip": {
					connectIP = params[0];
					return 1;
				};
				case "--connect-port": {
					connectPort = Std.parseInt(params[0]);
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
			relay = new HostRelaySkt();
			relay.bind(relaySocket);
			var out = relay.start(AmHost);
			out.writeCString(password);
			relay.send(out);
		});
		relaySocket.on("error", (e) -> {
			Console.error("Relay connection error:", e);
			Sys.exit(1);
		});
		Console.log('Will connect to $connectIP:$connectPort when asked.');
	}
	public static function main() {
		main_1(Sys.args());
	}
}