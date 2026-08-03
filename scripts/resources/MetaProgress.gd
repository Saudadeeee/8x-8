# res://scripts/resources/MetaProgress.gd
# Lưu tiến trình Meta (giữa các lần chơi). Dùng ResourceSaver để ghi xuống disk.
extends Resource
class_name MetaProgress

# --- TIẾN TRÌNH ---
@export var total_runs: int = 0             # Tổng số lần chơi
@export var total_wins: int = 0
@export var meta_points: int = 0           # Điểm tích lũy để mở khóa

# --- MỞ KHÓA ---
@export var unlocked_king_ids: Array[String] = ["king_default"]
@export var unlocked_soldier_ids: Array[String] = []
@export var unlocked_territory_ids: Array[String] = []
@export var unlocked_encounter_ids: Array[String] = []

# --- BUFF KHỞI ĐẦU (Meta Upgrades) ---
# Mỗi upgrade là một Dictionary: { "id": "...", "level": 1, "max_level": 5 }
@export var meta_upgrades: Array[Dictionary] = []

## Bộ Khai Cuộc đã mở khoá + bộ đang chọn cho ván tới.
## Đây là phần meta "mở LỐI CHƠI mới" — khác hẳn nâng cấp cộng chỉ số: nó không
## làm bạn mạnh hơn, nó cho bạn một cách chơi khác.
@export var unlocked_deck_ids: Array[String] = ["deck_standard"]
@export var selected_deck_id: String = "deck_standard"

## Đã xem hướng dẫn nhập môn chưa. Hiện MỘT LẦN ở ván đầu; màn Cài Đặt có nút
## bật lại. Để ở meta (không phải per-run) vì nó là trải nghiệm lần đầu của
## NGƯỜI CHƠI, không phải của ván.
@export var seen_tutorial: bool = false

# --- ASCENSION (bậc độ khó tăng dần) ---
## Bậc cao nhất đã MỞ KHOÁ (chọn được ở màn king_select). Thắng bậc N mở bậc N+1.
## Save cũ thiếu field này sẽ nhận default 0 → không phá tương thích.
@export var ascension_unlocked: int = 0
## Danh sách các bậc đã từng thắng (để hiện huy hiệu / thống kê).
@export var ascension_cleared: Array[int] = []

# --- THỐNG KÊ ---
@export var best_wave_reached: int = 0
@export var total_enemies_killed: int = 0
@export var total_gold_earned: int = 0

const SAVE_PATH = "user://meta_progress.tres"

## File save hỏng được đổi sang tên này thay vì xoá — người chơi còn cơ hội
## khiếu nại/khôi phục thủ công, và ta có mẫu để tìm nguyên nhân.
const CORRUPT_PATH = "user://meta_progress.corrupt.tres"
## Đuôi PHẢI giữ `.tres`: ResourceSaver suy ra định dạng từ phần mở rộng, đặt
## `.tres.tmp` sẽ trả lỗi 15 (ERR_FILE_UNRECOGNIZED).
const TMP_PATH = "user://meta_progress.tmp.tres"

## Nạp tiến trình meta. LUÔN trả về một MetaProgress dùng được.
##
## Trước đây hàm này `return load(...) as MetaProgress` — save hỏng thì `load()`
## trả null, cast ra null, và GameManager.meta_progress đứng null VĨNH VIỄN:
## không crash (mọi nơi đều có guard) nhưng toàn bộ tiến trình chết câm và
## không bao giờ tự phục hồi. Mất điện giữa lúc ghi save là đủ để hỏng.
static func load_or_create() -> MetaProgress:
	if not ResourceLoader.exists(SAVE_PATH):
		return MetaProgress.new()

	var loaded: Resource = load(SAVE_PATH)
	var data := loaded as MetaProgress
	if data != null:
		return data

	# Tới đây = file có tồn tại nhưng hỏng hoặc sai kiểu.
	push_warning("MetaProgress: save hỏng hoặc sai kiểu — đổi tên sang %s và tạo mới."
		% CORRUPT_PATH)
	var dir := DirAccess.open("user://")
	if dir != null:
		# Xoá bản .corrupt cũ trước: DirAccess.rename() không ghi đè được.
		if dir.file_exists(CORRUPT_PATH.get_file()):
			dir.remove(CORRUPT_PATH.get_file())
		dir.rename(SAVE_PATH.get_file(), CORRUPT_PATH.get_file())
	return MetaProgress.new()

## Ghi ra file TẠM rồi mới đổi tên đè lên bản thật. Ghi thẳng thì tiến trình bị
## giết giữa chừng sẽ để lại file cụt — chính là ca hỏng ở trên.
func save() -> void:
	var err := ResourceSaver.save(self, TMP_PATH)
	if err != OK:
		push_error("MetaProgress: không ghi được save tạm (lỗi %d)." % err)
		return
	var dir := DirAccess.open("user://")
	if dir == null:
		push_error("MetaProgress: không mở được thư mục user://.")
		return
	if dir.file_exists(SAVE_PATH.get_file()):
		dir.remove(SAVE_PATH.get_file())
	var rename_err := dir.rename(TMP_PATH.get_file(), SAVE_PATH.get_file())
	if rename_err != OK:
		push_error("MetaProgress: không đổi tên được save tạm (lỗi %d)." % rename_err)
