package shared;

import js.node.net.Socket;
import js.node.Net;

class NetTools {
	public static function createServer(cb:Socket->Void) {
		var opt:NetCreateServerOptions = {};
		(cast opt).highWaterMark = 1024 * 1024 * 64;
		(cast opt).noDelay = true;
		return Net.createServer(opt, cb);
	}
	public static function printLocalAddress(skt:Socket) {
		var addr = skt.address();
		return '(${addr.family}, "${addr.address}", ${addr.port})';
	}
	public static function printRemoteAddress(skt:Socket) {
		return '(${skt.remoteFamily}, "${skt.remoteAddress}", ${skt.remotePort})';
	}
}