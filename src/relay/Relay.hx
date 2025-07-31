package relay;

import js.node.Net;
import js.node.net.Socket;
import js.html.Console;
import shared.*;

class Relay {
	public static var host:RelayHostSkt = null;
	public static var guest:RelayGuestSkt = null;
	public static var password:String = "";
	public static function main_1(args:Array<String>) {
		var hostPort:Null<Int> = null;
		var guestPort:Null<Int> = null;
		CliTools.parseArgs(args, (name, params) -> {
			switch (name) {
				case "--host-port": {
					hostPort = Std.parseInt(params[0]);
					return 1;
				};
				case "--guest-port": {
					guestPort = Std.parseInt(params[0]);
					return 1;
				};
				default: return -1;
			}
		});
		if (hostPort == null || guestPort == null) {
			Console.error("--host-port and --guest-port are required!");
			Sys.exit(1);
		}
		var hostListener = NetTools.createServer((skt) -> {
			var wrap = new RelayHostSkt();
			wrap.bind(skt);
			Console.log("Host connected: " + wrap);
		});
		hostListener.listen(hostPort);
		//
		var guestListener = NetTools.createServer((skt) -> {
			var wrap = new RelayGuestSkt();
			wrap.bind(skt);
			Console.log("Guest connected: " + wrap);
		});
		guestListener.listen(guestPort);
		Console.log('Listening on ports $hostPort/$guestPort!');
	}
	public static function main() {
		main_1(Sys.args());
	}
}