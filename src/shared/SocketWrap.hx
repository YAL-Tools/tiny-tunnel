package shared;

import haxe.io.BytesInput;
import sys.io.File;
import sys.FileSystem;
import haxe.extern.EitherType;
import js.node.Buffer;
import haxe.io.Bytes;
import js.Node;
import haxe.io.BytesOutput;
import js.html.Console;
import haxe.CallStack;
import js.node.net.Socket;
using shared.BytesTools;

abstract class SocketWrap<P:Int> {
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
	public function getKicker():PacketID {
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
			var skt = socket;
			Node.setTimeout(() -> {
				skt.destroy();
			}, 100);
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
			readData(data);
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
	static inline var headerSize = 6;
	static inline var header:Int = 'T'.code + ('L'.code << 8);
	//
	private var leftovers:Bytes = null;
	private function readData(data:EitherType<String, Buffer>) {
		if (socket == null) return;
		var bytes = BytesTools.dataToBytes(data);
		if (leftovers != null) {
			bytes = leftovers.concat(bytes);
			leftovers = null;
		}
		//
		var len = bytes.length;
		var pos = 0;
		inline function stash() {
			leftovers = bytes.sub(pos, len - pos);
		}
		//
		while (pos < len) {
			if (pos + headerSize > len) {
				stash();
				break;
			}
			//
			var head = bytes.getUInt16(pos);
			if (head != header) {
				throw "Unexpected header " + StringTools.hex(head, 4) + " at pos " + pos;
			}
			//
			var pktSize = bytes.getInt32(pos + 2);
			var pktTill = pos + headerSize + pktSize;
			if (pktTill > len) {
				stash();
				break;
			}
			//
			pos += headerSize;
			var reader = new BytesInputEx(bytes, pos, pktSize);
			onPacket(reader, pktSize);
			pos += pktSize;
		}
	}
	//
	public function send(buf:BytesOutput) {
		try {
			var bytes = buf.getBytes();
			var size = buf.length;
			bytes.setInt32(2, size - headerSize);
			var arrayBuffer = bytes.getData();
			var nativeBuffer = Buffer.from(arrayBuffer, 0, size);
			socket.write(nativeBuffer);
			return true;
		} catch (x:Dynamic) {
			return false;
		}
	}
	//
	public inline function start(kind:PacketID, expect:Int = 0) {
		var buf = new BytesOutput();
		buf.prepare(7 + expect);
		buf.writeUInt16(header);
		buf.writeInt32(0);
		buf.writeByte(kind);
		return buf;
	}
	public inline function sendSimple(kind:PacketID) {
		send(start(kind));
	}
	//
	@:keep public function toString() {
		return Type.getClassName(Type.getClass(this)) + '($sockFamily, "$sockAddr", $sockPort)';
	}
}