package shared;

import haxe.io.Bytes;
import js.node.Buffer;
import haxe.extern.EitherType;
import haxe.io.BytesOutput;
import haxe.io.BytesInput;

class BytesTools {
	public static function writeBytesInput(o:BytesOutput, i:BytesInputEx, n:Int) {
		static var tmp:Bytes = Bytes.alloc(1024 * 150);
		if (tmp.length < n) tmp = Bytes.alloc(n * 2);
		i.readBytes(tmp, 0, n);
		o.writeBytes(tmp, 0, n);
	}
	public static inline function writeCString(o:BytesOutput, s:String) {
		o.writeString(s);
		o.writeByte(0);
	}
	public static function readCString(i:BytesInputEx) {
		var out = new BytesOutput();
		while (!i.eof()) {
			var b = i.readByte();
			if (b != 0) {
				out.writeByte(b);
			} else break;
		}
		return out.getBytes().toString();
	}
	@:noUsing public static function dataToBytes(data:EitherType<String, Buffer>) {
		var buf:Buffer;
		if (data is String) {
			buf = Buffer.from((data:String));
		} else buf = (data:Buffer);
		var pos = 0;
		var len = buf.length;
		var bytes = buf.hxToBytes();
		return bytes;
	}
	public static inline function writeBool(o:BytesOutput, bool:Bool) {
		o.writeByte(bool ? 1 : 0);
	}
	public static function realloc(b:Bytes, newSize:Int) {
		if (b.length > newSize) return b;
		var nb = Bytes.alloc(newSize);
		nb.blit(0, b, 0, b.length);
		return nb;
	}
	public static function concatExt(a:Bytes, aPos:Int, aLen:Int, b:Bytes, bPos:Int, bLen:Int) {
		var r = Bytes.alloc(aLen + bLen);
		r.blit(0, a, aPos, aLen);
		r.blit(aLen, b, bPos, bLen);
		return r;
	}
}