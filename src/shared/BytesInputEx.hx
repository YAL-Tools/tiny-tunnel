package shared;

import haxe.io.Bytes;
import haxe.io.BytesInput;

class BytesInputEx extends BytesInput {
	public final end:Int;
	public function new(b:Bytes, ?pos:Int, ?len:Int) {
		super(b, pos, len);
		end = position + length;
	}
	public inline function eof():Bool {
		return position >= end;
	}
}