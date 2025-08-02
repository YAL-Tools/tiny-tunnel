package shared;
import sys.FileSystem;
import sys.io.File;

class DumpTools {
	public static function ensureDirectory(path) {
		if (!FileSystem.exists(path)) FileSystem.createDirectory(path);
	}
	public static function ensureEmptyDirectory(dir) {
		if (FileSystem.exists(dir)) {
			for (rel in FileSystem.readDirectory(dir)) {
				var full = '$dir/$rel';
				FileSystem.deleteFile(full);
			}
		} else FileSystem.createDirectory(dir);
	}
}