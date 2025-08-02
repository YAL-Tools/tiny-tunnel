package shared;

import haxe.io.Bytes;
using shared.BytesTools;

class LeftoverAcc {
	static inline var debug = true;
	public var bytes:Bytes;
	public var offset:Int;
	public var length:Int;
	public function new() {
		
	}
	public function set(b:Bytes, pos:Int, len:Int) {
		if (debug) {
			bytes = b.sub(0, bytes.length);
			offset = pos;
			length = len;
		} else {
			bytes = b.sub(pos, len);
			offset = 0;
			length = len;
		}
	}
	
	public function concat(b:Bytes, len:Int) {
		return bytes.concatExt(offset, length, b, 0, len);
	}
}