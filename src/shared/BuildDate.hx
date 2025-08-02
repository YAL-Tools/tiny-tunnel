package shared;

class BuildDate {
	public static macro function get() {
		var s = Date.now().toString();
		return macro $v{s};
	}
}