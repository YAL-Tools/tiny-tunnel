package shared;

import haxe.io.Bytes;
using shared.BytesTools;

class PacketAcc {
	public var buf:Bytes = Bytes.alloc(1024);
	public var pos = 0;
	public function new() {
		
	}
	public function set(source:Bytes, sourcePos:Int, sourceLen:Int) {
		if (buf.length < sourceLen) buf = Bytes.alloc(sourceLen);
		buf.blit(0, source, sourcePos, sourceLen);
		pos = sourceLen;
	}
	public function add(source:Bytes, sourcePos:Int, sourceLen:Int) {
		var newPos = pos + sourceLen;
		if (buf.length < newPos) buf = buf.realloc(newPos);
		buf.blit(pos, source, sourcePos, sourceLen);
		pos = newPos;
	}
	public function getInput() {
		return new BytesInputEx(buf, 0, pos);
	}
	public function clear() {
		pos = 0;
	}
}