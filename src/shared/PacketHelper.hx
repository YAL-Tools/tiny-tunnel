package shared;

import js.html.Console;
import haxe.io.BytesOutput;
import js.node.net.Socket;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import js.node.Buffer;
import haxe.extern.EitherType;
using shared.BytesTools;

class PacketHelper {
	public static function print(bytes:Bytes, pos:Int = -1, ?size:Int) {
		// header:
		var perRow = 20;
		size ??= bytes.length;
		var out = new StringBuf();
		out.add('Bytes(size: $size');
		if (pos >= 0) out.add(', pos: $pos');
		out.add('):');
		
		var start = 0;
		inline function printChars(till:Int) {
			out.add(" | ");
			for (k in start ... till) {
				var c = bytes.get(k);
				if (c >= 32 && c < 128) {
					out.addChar(c);
				} else switch (c) {
					case 0: out.addChar("¦".code);
					default: out.addChar("·".code);
				}
			}
		}
		for (i in 0 ... size) {
			if (i % perRow == 0) {
				if (i > 0) printChars(i);
				out.add('\n');
				out.add(StringTools.lpad("" + i, ' ', 6));
				out.add(' |');
				start = i;
			}
			
			out.addChar(i == pos ? '>'.code : ' '.code);
			var c = bytes.get(i);
			var hex = c >> 4;
			out.addChar(hex >= 10 ? ('A'.code - 10 + hex) : '0'.code + hex);
			hex = c & 15;
			out.addChar(hex >= 10 ? ('A'.code - 10 + hex) : '0'.code + hex);
		}
		// last row padding:
		if (size % perRow != 0) {
			for (_ in 0 ... perRow - size % perRow) out.add('   ');
		}
		printChars(size);
		return out.toString();
	}
	public static inline var headerSize = 6;
	public static inline var header:Int = 'T'.code + ('L'.code << 8);
	public static inline var continueFlag = (1 << 30);
	public static var MTU = 32000;
	
	public static inline function read(data:EitherType<String, Buffer>, acc:PacketAcc, leftovers:PacketAcc, handler:BytesInputEx->Int->Void) {
		var buf:Buffer;
		if (data is String) {
			buf = Buffer.from((data:String));
		} else buf = (data:Buffer);
		var pos = 0;
		var len = buf.length;
		var bytes = buf.hxToBytes();
		var leftoverSize = leftovers.pos;
		if (leftoverSize > 0) {
			bytes = leftovers.buf.concatExt(0, leftoverSize, bytes, 0, len);
			len = bytes.length;
			leftovers.clear();
		}
		inline function stashLeftovers() {
			leftovers.set(bytes, pos, len - pos);
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
				trace("leftoverSize", leftoverSize);
				trace("data", print(bytes));
				throw "Unexpected header " + StringTools.hex(head, 4) + " at pos " + pos;
			}
			var packetSize = bytes.getInt32(pos); pos += 4;
			
			var isContinue = (packetSize & continueFlag) != 0;
			if (isContinue) packetSize &= ~continueFlag;
			
			if (pos + packetSize > len) {
				pos -= headerSize;
				leftovers.set(bytes, pos, len - pos);
				break;
			}
			//trace(packetSize, isContinue, acc.pos);
			if (packetSize == 0 && !isContinue && acc.pos == 0) continue;
			
			if (!isContinue && acc.pos == 0) {
				var reader = new BytesInputEx(bytes, pos, packetSize);
				handler(reader, packetSize);
			} else {
				acc.add(bytes, pos, packetSize);
				if (!isContinue) {
					//trace(acc.buf.sub(0, acc.pos).toString());
					var reader = acc.getInput();
					handler(reader, acc.pos);
					acc.clear();
				}
			}
			pos += packetSize;
		}
	}
	public static function start(kind:Int, expect:Int = 0) {
		var buf = new BytesOutput();
		buf.prepare(7 + expect);
		buf.writeUInt16(header);
		buf.writeInt32(0);
		buf.writeByte(kind);
		return buf;
	}
	public static function send(socket:Socket, buf:BytesOutput) {
		var size = buf.length;
		var bytes = buf.getBytes();
		//trace(print(bytes, -1, size));
		// small enough?
		if (size <= MTU) try {
			var size = buf.length;
			bytes.setInt32(2, size - headerSize);
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
			tmp.setInt32(2, subSize | (subSize < left ? continueFlag : 0));
			tmp.blit(headerSize, bytes, offset, subSize);
			//Console.log('Frame pos=$offset size=$subSize total=$size left=$left');
			offset += subSize;
			left -= subSize;
			//
			var arrayBuffer = tmp.getData();
			var nativeBuffer = Buffer.from(arrayBuffer, 0, subSize + headerSize);
			try {
				socket.write(nativeBuffer);
			} catch (x:Dynamic) {
				return false;
			}
		} while (left > 0);
		return true;
	}
}