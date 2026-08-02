# res://scripts/resources/content_loader.gd
#
# NẠP NỘI DUNG TỪ FILE .tres — điểm vào duy nhất cho thuốc / trang bị / di vật /
# perk.
#
# Vì sao có file này: bốn hệ vật phẩm đều cần đúng một việc — quét một thư mục,
# nạp mọi `.tres`, đổi sang Dictionary cho phần code cũ dùng nguyên si. Viết bốn
# lần thì bốn chỗ lệch nhau lúc sửa.
#
# Thứ tự ưu tiên của mỗi hệ (giống nhau cả bốn):
#   1. `res://res/<loại>/*.tres`  — mở được bằng Inspector, ĐÂY LÀ NGUỒN CHÍNH
#   2. `res://data/<loại>/*.json` — giữ cho tương thích ngược
#   3. Bảng khai cứng trong `.gd` — chỉ còn là lưới an toàn
#
# Trùng `id` thì bước sau ghi đè bước trước, nên sửa một món có sẵn = sửa file
# `.tres` của nó, không phải đụng code.
class_name ContentLoader
extends Object


## Quét `dir` và trả về danh sách Dictionary.
##
## Mỗi Resource phải có `to_dict()`; thiếu hàm đó thì bỏ qua kèm cảnh báo —
## im lặng bỏ qua sẽ thành "món có mà không chạy", đúng lớp lỗi hay gặp nhất
## ở dự án này.
static func load_dir(dir: String, label: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	var d := DirAccess.open(dir)
	if d == null:
		push_warning("ContentLoader: không mở được %s" % dir)
		return out
	for file_name in d.get_files():
		# Bản export mang đuôi .remap; bỏ đuôi đó đi thì load() vẫn đúng đường.
		var clean_name := file_name.trim_suffix(".remap")
		if not clean_name.ends_with(".tres"):
			continue
		var path := dir.path_join(clean_name)
		var res: Resource = load(path)
		if res == null:
			push_warning("ContentLoader: %s — không nạp được %s" % [label, path])
			continue
		if not res.has_method("to_dict"):
			push_warning("ContentLoader: %s — %s thiếu to_dict(), bỏ qua"
				% [label, path])
			continue
		var entry: Dictionary = res.call("to_dict")
		if str(entry.get("id", "")).is_empty():
			push_warning("ContentLoader: %s — %s thiếu `id`, bỏ qua" % [label, path])
			continue
		out.append(entry)
	return out
