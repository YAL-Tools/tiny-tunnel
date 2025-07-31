import host.Host;
import relay.Relay;
import guest.Guest;

class Multi {
	public static function main() {
		var args = Sys.args();
		var mode = args.shift();
		switch (mode) {
			case "--relay": Relay.main_1(args);
			case "--guest": Guest.main_1(args);
			case "--host": Host.main_1(args);
			default: {
				Sys.println('Unknown mode $mode');
			}
		}
	}
}