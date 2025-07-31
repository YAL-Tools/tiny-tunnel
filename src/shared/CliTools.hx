package shared;

import js.html.Console;

class CliTools {
	public static inline function parseArgs(args:Array<String>, handler:(name:String, params:ArrayWithOffset<String>)->Int) {
		var i = 0;
		var ao = new ArrayWithOffset(args);
		while (i < args.length) {
			var name = args[i];
			ao.offset = i + 1;
			var remove = handler(name, ao);
			if (remove >= 0) {
				args.splice(i, remove + 1);
			} else i += 1;
		}
	}
	public static inline function requireArg<T>(val:T, name:String) {
		if (val == null) {
			Console.error('Command-line argument $name is required!');
			Sys.exit(1);
		}
	}
}
@:forward(offset)
abstract ArrayWithOffset<T>(ArrayWithOffsetImpl<T>) {
	public inline function new(arr) {
		this = new ArrayWithOffsetImpl(arr);
	}
	@:arrayAccess
	public inline function get(index:Int) {
		return this.array[index + this.offset];
	}
	@:arrayAccess
	public inline function set(index:Int, value:T) {
		this.array[index + this.offset] = value;
		return value;
	}
	public var length(get, never):Int;
	inline function get_length() {
		return this.array.length - this.offset;
	}
}
class ArrayWithOffsetImpl<T> {
	public var array:Array<T>;
	public var offset:Int = 0;
	public function new(arr:Array<T>) {
		array = arr;
	}
}