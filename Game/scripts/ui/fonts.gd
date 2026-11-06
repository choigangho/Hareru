class_name Fonts
extends RefCounted
## One place for the game's fonts. A-4: dialogue/UI = pixel gothic (font not chosen yet —
## owner must OK the license), paper = smooth mincho. Until then: system gothic/mincho.

static var _gothic: Font
static var _mincho: Font


static func gothic() -> Font:
	if _gothic == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Hiragino Sans", "Hiragino Kaku Gothic ProN", "Apple SD Gothic Neo", "Yu Gothic UI", "Yu Gothic", "Meiryo", "Malgun Gothic", "Noto Sans CJK JP", "sans-serif"])
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_gothic = f
	return _gothic


static var _gothic_bold: Font


## Bold gothic (the current sense on the reader's meaning line, D-15).
static func gothic_bold() -> Font:
	if _gothic_bold == null:
		var f := SystemFont.new()
		f.font_names = (gothic() as SystemFont).font_names
		f.font_weight = 700
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_gothic_bold = f
	return _gothic_bold


static func mincho() -> Font:
	if _mincho == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Hiragino Mincho ProN", "Yu Mincho", "MS Mincho", "Noto Serif CJK JP", "serif"])
		_mincho = f
	return _mincho
