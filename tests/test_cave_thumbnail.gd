extends TestCase
## The leaderboard picture fits the Worker's limits and reads back.


func test_thumbnail_fits_and_decodes() -> void:
	for seed: int in [5, 77, 31337, 4294967295]:
		var cave: CaveData = CaveGenerator.generate(seed)
		var b64: String = CaveThumbnail.make_base64(cave)
		check(b64 != "", "seed %d: a picture is made" % seed)
		var bytes: PackedByteArray = Marshalls.base64_to_raw(b64)
		check(bytes.size() <= CaveThumbnail.MAX_BYTES, "seed %d: at most 4 KB (%d)" % [seed, bytes.size()])
		var img := Image.new()
		check_eq(img.load_png_from_buffer(bytes), OK, "seed %d: it's a PNG" % seed)
		check(img.get_width() <= 256 and img.get_height() <= 256, "seed %d: at most 256 x 256" % seed)
		check(CaveThumbnail.texture_from_base64(b64) != null, "seed %d: shows on the leaderboard" % seed)
	check(CaveThumbnail.texture_from_base64("bm90IGEgcG5n") == null, "junk isn't shown")
