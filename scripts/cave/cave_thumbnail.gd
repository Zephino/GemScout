class_name CaveThumbnail
extends RefCounted
## A small picture of a whole cave for the leaderboard: one pixel per cell,
## greyscale (rock, air, gems bright, exit and start mid-grey). Sent with a
## score as a base64 PNG; the Worker accepts up to 4 KB and 256 x 256.

const MAX_BYTES := 4096
const ROCK := 70
const AIR := 14
const GEM := 255
const EXIT := 190
const START := 130


static func make_image(cave: CaveData) -> Image:
	var img := Image.create(cave.width, cave.height, false, Image.FORMAT_L8)
	for y in cave.height:
		for x in cave.width:
			img.set_pixel(x, y, Color8(ROCK, ROCK, ROCK) if cave.is_solid(x, y) else Color8(AIR, AIR, AIR))
	_dot(img, cave.start, START)
	_dot(img, cave.exit, EXIT)
	for g in cave.gems:
		_dot(img, g, GEM)
	return img


static func _dot(img: Image, cell: Vector2i, level: int) -> void:
	for dy in range(-1, 1):
		for dx in range(0, 2):
			var p := Vector2i(cell.x + dx, cell.y + dy)
			if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
				img.set_pixel(p.x, p.y, Color8(level, level, level))


## The PNG as base64, made smaller until it fits MAX_BYTES ("" if it never does).
static func make_base64(cave: CaveData) -> String:
	var img: Image = make_image(cave)
	for i in 3:
		var png: PackedByteArray = img.save_png_to_buffer()
		if png.size() <= MAX_BYTES:
			return Marshalls.raw_to_base64(png)
		img.resize(maxi(1, img.get_width() / 2), maxi(1, img.get_height() / 2), Image.INTERPOLATE_NEAREST)
	return ""


## A coloured texture from a leaderboard picture (null if it isn't a PNG).
static func texture_from_base64(data: String) -> Texture2D:
	if data == "":
		return null
	var bytes: PackedByteArray = Marshalls.base64_to_raw(data)
	# Only real PNGs (the signature), so junk never reaches the decoder.
	if bytes.size() < 8 or bytes.slice(0, 8) != PackedByteArray([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]):
		return null
	var img := Image.new()
	if img.load_png_from_buffer(bytes) != OK:
		return null
	img.convert(Image.FORMAT_RGBA8)
	# Tint: rock purple-grey, gems gold, air dark.
	for y in img.get_height():
		for x in img.get_width():
			var l: float = img.get_pixel(x, y).r
			var c: Color
			if l > 0.9:
				c = Color8(255, 210, 70)
			elif l > 0.6:
				c = Color8(90, 220, 140)
			elif l > 0.4:
				c = Color8(120, 170, 255)
			elif l > 0.2:
				c = Color8(110, 94, 130)
			else:
				c = Color8(24, 19, 32)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
