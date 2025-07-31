package shared;

import js.node.Net;
import haxe.io.BytesOutput;
import js.html.Console;
import haxe.CallStack;
import haxe.io.BytesInput;
import js.node.net.Socket;
using shared.BytesTools;

abstract class SocketWrap<P:Int> {
	public static function createServerOptions() {
		var r:NetCreateServerOptions = {};
		(cast r).highWaterMark = 1024 * 1024 * 64;
		return r;
	}
	
	public var debug = false;
	public var sockFamily:SocketAdressFamily = null;
	public var sockAddr:String = null;
	public var sockPort = -1;
	public var version:Int = 0;
	public var socket:Socket = null;
	public var connected(get, never):Bool;
	inline function get_connected() {
		return socket != null;
	}
	//
	function destroyPre() {
		if (socket == null) {
			//Debug.warn("Already destroyed!");
			return true;
		}
		Console.info("Removing", this.toString());
		return false;
	}
	public function getKicker():P {
		throw "TODO!getKicker";
	}
	public function handleKicker(reader:BytesInputEx) {
		var code:ErrorCode = reader.readUInt16();
		var custom = code == Custom ? reader.readCString() : "";
		Console.error('We got disconnected - ${code.getName()}/"$custom"');
		destroy();
	}
	public function destroy(?code:ErrorCode, ?reason:String) {
		if (code != null) try {
			var b = start(getKicker());
			b.writeUInt16(code);
			b.writeCString(reason ?? "");
			send(b);
		} catch (x:Dynamic) {
			Console.warn('Last send error:', x);
		}
		//
		try {
			socket.destroy();
		} catch (x:Dynamic) {
			Console.warn('Destroy error:', x);
		}
		socket = null;
	}
	//
	public function bind(skt:Socket) {
		socket = skt;
		sockFamily = skt.remoteFamily;
		sockAddr = skt.remoteAddress;
		sockPort = skt.remotePort;
		skt.on("data", (data) -> {
			onData(data);
		});
		skt.on("error", (e) -> {
			onError(e);
		});
		skt.on("close", (e) -> {
			onClose(e);
		});
	}
	//
	public function onPacket(reader:BytesInputEx, size:Int):Void {
		throw "TODO!onPacket";
	}
	private var packetAcc = new PacketAcc();
	private var packetLeftovers = new PacketAcc();
	public function onData(data:Any) {
		try {
			PacketHelper.read(data, packetAcc, packetLeftovers, (reader, size:Int) -> {
				onPacket(reader, size);
			});
		} catch (x:Dynamic) {
			Console.warn('$this Read error', x);
			Console.warn(CallStack.toString(CallStack.exceptionStack()));
			destroy(Custom, "Read error: " + x);
		}
	}
	public function onError(e) {
		Console.warn('Network error in $this:', e);
		destroy();
	}
	public function onClose(e) {
		Console.warn('Socket closed for $this:', e);
		destroy();
	}
	//
	public inline function start(kind:P, expect:Int = 0) {
		return PacketHelper.start(kind, expect);
	}
	public function send(buf:BytesOutput) {
		PacketHelper.send(socket, buf);
	}
	public inline function sendSimple(kind:P) {
		send(start(kind));
	}
	//
	@:keep public function toString() {
		return Type.getClassName(Type.getClass(this)) + '($sockFamily, "$sockAddr", $sockPort)';
	}
}