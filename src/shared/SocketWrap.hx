package shared;

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
		dumpSendLog();
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
	static inline var continueFlag = (1 << 30);
	static var MTU = 32000;
	//
	var receivePairs = [];
	var receiveLog = [];
	function dumpReceiveLog() {
		Console.error("Dumping... " + receiveLog.length + ", " + receivePairs.length);
		DumpTools.ensureDirectory("dump");
		var dir = "dump/" + Type.getClassName(Type.getClass(this));
		if (FileSystem.exists(dir)) {
			for (rel in FileSystem.readDirectory(dir)) {
				var full = '$dir/$rel';
				FileSystem.deleteFile(full);
			}
		} else FileSystem.createDirectory(dir);
		var now = Date.now().toString();
		now = ~/[^\w]+/g.replace(now, "-");
		File.saveContent('$dir/__$now.txt', receiveLog.join("\r\n"));
		for (i => q in receivePairs) {
			inline function saveBuffer(b, name) {
				File.saveBytes('$dir/$i-$name.bin', b);
			}
			inline function saveBufferIf(b, name) {
				if (b != null) saveBuffer(b, name);
			}
			saveBuffer(q.bytes, 'bytes');
			saveBufferIf(q.leftovers, 'leftovers');
			saveBufferIf(q.combined, 'combined');
			for (k => b in q.acc) saveBuffer(b, 'acc-$k');
		}
	}
	function firstBytes(b:Bytes, ?n:Int, offset:Int = 0) {
		n ??= b.length;
		n -= offset;
		if (n == 0) return "";
		if (n > 4) n = 4;
		//
		var r = StringTools.hex(b.get(0), 2);
		for (i in 1 ... n) {
			r += " " + StringTools.hex(b.get(offset + i), 2);
		}
		return r;
	}
	private function readData(data:EitherType<String, Buffer>) {
		if (socket == null) return;
		var buf:Buffer;
		if (data is String) {
			buf = Buffer.from((data:String));
		} else buf = (data:Buffer);
		var pos = 0;
		var len = buf.length;
		var bytes = buf.hxToBytes();
		var acc = packetAcc;
		var leftovers = packetLeftovers;
		var leftoverSize = leftovers.pos;
		//
		var logIndex = receivePairs.length;
		inline function log(text:String) {
			Console.log(logIndex, text);
			receiveLog.push('$logIndex\t$text');
		}
		log('$len bytes!');
		var rcv = {
			bytes: bytes.sub(0, len),
			leftovers: leftoverSize > 0 ? leftovers.buf.sub(0, leftoverSize) : null,
			combined: null,
			acc: [],
		};
		receivePairs.push(rcv);
		//
		if (leftoverSize > 0) {
			log('Have $leftoverSize bytes of leftovers! ' + firstBytes(leftovers.buf, leftoverSize));
			bytes = leftovers.buf.concatExt(0, leftoverSize, bytes, 0, len);
			len = bytes.length;
			log('Combined size is $len!' + firstBytes(bytes, len));
			rcv.combined = bytes.sub(0, len);
			leftovers.clear();
		}
		inline function stashLeftovers() {
			leftovers.set(bytes, pos, len - pos);
			log('Stored leftovers ${leftovers.pos} ... $len!' + firstBytes(leftovers.buf, leftovers.pos));
		}
		//trace("data", print(bytes));
		while (pos < len) {
			if (pos + headerSize > len) {
				stashLeftovers();
				break;
			}
			//
			var head = bytes.getUInt16(pos); pos += 2;
			if (head != header) {
				//trace("leftoverSize", leftoverSize);
				//trace("orig", print(origBytes));
				//trace("data", PacketHelper.print(bytes));
				log('Trouble at pos $pos');
				dumpReceiveLog();
				throw "Unexpected header " + StringTools.hex(head, 4) + " at pos " + pos;
			}
			var packetSize = bytes.getInt32(pos); pos += 4;
			inline function theseBytes() return firstBytes(bytes, packetSize, pos);
			
			var isContinue = (packetSize & continueFlag) != 0;
			if (isContinue) packetSize &= ~continueFlag;
			
			var end = pos + packetSize;
			if (end > len) {
				pos -= headerSize;
				leftovers.set(bytes, pos, len - pos);
				log('Packet spans $pos ... $end, but size is $len. Stashed '
					+ firstBytes(leftovers.buf, len - pos)
				);
				break;
			}
			//trace(packetSize, isContinue, acc.pos);
			if (packetSize == 0 && !isContinue && acc.pos == 0) continue;
			
			if (!isContinue && acc.pos == 0) {
				var p:PacketID = bytes.get(pos);
				log('Packet: ${p.getName()} at $pos ... $end, ${theseBytes()}');
				var reader = new BytesInputEx(bytes, pos, packetSize);
				onPacket(reader, packetSize);
			} else {
				acc.add(bytes, pos, packetSize);
				log('Added bytes $pos ... $end (${theseBytes()}) to acc, now at ${acc.pos}');
				if (!isContinue) {
					//trace(acc.buf.sub(0, acc.pos).toString());
					var p:PacketID = acc.buf.get(0);
					log('AccPacket: ${p.getName()} at 0 ... ${acc.pos}, '
						+ firstBytes(acc.buf, acc.pos, 0)
					);
					var reader = acc.getInput();
					rcv.acc.push(acc.buf.sub(0, acc.pos));
					onPacket(reader, acc.pos);
					acc.clear();
				}
			}
			pos += packetSize;
		}
	}
	//
	var sent = [];
	public function dumpSendLog() {
		DumpTools.ensureDirectory("dump");
		var dir = "dump/" + Type.getClassName(Type.getClass(this)) + "-send";
		DumpTools.ensureEmptyDirectory(dir);
		for (i => b in sent) {
			File.saveBytes('$dir/$i.bin', b);
		}
	}
	//
	public function send(buf:BytesOutput) {
		var size = buf.length;
		var bytes = buf.getBytes();
		//trace(print(bytes, -1, size));
		// small enough?
		if (size <= MTU) try {
			var size = buf.length;
			bytes.setInt32(2, size - headerSize);
			sent.push(bytes.sub(0, size));
			var arrayBuffer = bytes.getData();
			var nativeBuffer = Buffer.from(arrayBuffer, 0, size);
			socket.write(nativeBuffer);
			return true;
		} catch (x:Dynamic) {
			return false;
		}
		//
		static var tmp:Bytes = null;
		if (tmp == null || tmp.length < MTU) {
			tmp = Bytes.alloc(MTU);
			tmp.setUInt16(0, header);
		}
		//
		var offset = headerSize;
		var left = size - offset;
		var maxSubSize = MTU - headerSize;
		do {
			var subSize = left;
			if (subSize > maxSubSize) subSize = maxSubSize;
			var isContinue = subSize < left;
			tmp.setInt32(2, subSize | (isContinue ? continueFlag : 0));
			tmp.blit(headerSize, bytes, offset, subSize);
			Console.log('Frame pos=$offset size=$subSize total=$size left=$left cont=$isContinue');
			offset += subSize;
			left -= subSize;
			//
			var arrayBuffer = tmp.getData();
			var nativeBuffer = Buffer.from(arrayBuffer, 0, subSize + headerSize);
			sent.push(tmp.sub(0, subSize + headerSize));
			try {
				socket.write(nativeBuffer);
			} catch (x:Dynamic) {
				return false;
			}
		} while (left > 0);
		return true;
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