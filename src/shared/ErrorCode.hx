package shared;

@:build(shared.AutoEnum.build())
#if gml
@:doc @:keep @:native("pory_result")
#end
enum abstract ErrorCode(Int) from Int to Int {
	var OK = 0;
	var Custom = 1;
	var SlowHello = 2;
	var WantHello = 3;
	var WrongPass = 4;
	var NoHost = 5;
	var NoGuest = 6;
	
	@:keep public function getName() {
		return "Error(" + this + ")";
	}
}