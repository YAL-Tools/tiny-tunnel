package shared;

import haxe.io.Bytes;

class LeftoverAcc {
	static inline var debug = true;
	public var bytes:Bytes;
	public var offset:Int;
	public var length:Int;
	public function new(b:Bytes, pos:Int, len:Int) {
		if (debug) {
			bytes = b;
			pos = offset;
			length = len;
		} else {
			
		}
	}
}