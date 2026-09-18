extends SceneTree
## Focused PR conflict regression, run with --headless --script.
const Flash = preload("res://scripts/systems/hit_flash.gd")
var failed := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	failed = failed or not ok

func run() -> void:
	Flash.flash(null)
	var target := Sprite2D.new()
	root.add_child(target)
	var original := Color(0.5, 0.6, 0.7, 0.8)
	target.modulate = original
	Flash.flash(target)
	await create_timer(0.02).timeout
	var previous: Tween = target.get_meta(Flash.META_TWEEN)
	Flash.flash(target)
	check(not previous.is_running(), "overlapping flash stops previous tween")
	check(target.get_meta(Flash.META_ORIGINAL_COLOR) == original, "true original color retained")
	await create_timer(0.5).timeout
	check(target.modulate.is_equal_approx(original), "RGBA restored after overlapping flash")
	check(not target.has_meta(Flash.META_TWEEN) and not target.has_meta(Flash.META_ORIGINAL_COLOR), "metadata removed")
	Flash.flash(target)
	await create_timer(0.5).timeout
	check(target.modulate.is_equal_approx(original), "later independent flash restores color")
	target.free()
	quit(1 if failed else 0)
