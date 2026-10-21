class_name IconButton
extends GlowButton
## Round glass button showing a vector icon.

var kind := "back"
var icon_color := UI.TEXT


static func make_icon(icon_kind: String, diameter := 72, accent_color := UI.ACCENT) -> IconButton:
	var b := IconButton.new()
	b.kind = icon_kind
	b.accent = accent_color
	b.corner = diameter / 2
	b.custom_minimum_size = Vector2(diameter, diameter)
	return b


func _draw() -> void:
	var c := size * 0.5
	var s := minf(size.x, size.y) * 0.2
	var col := icon_color if not disabled else Color(1, 1, 1, 0.3)
	match kind:
		"back": Icons.chevron(self, c + Vector2(-s * 0.1, 0), s, -1.0, col, 5.0)
		"next": Icons.chevron(self, c + Vector2(s * 0.1, 0), s, 1.0, col, 5.0)
		"pause": Icons.pause(self, c, s, col)
		"play": Icons.play(self, c + Vector2(s * 0.12, 0), s, col)
		"restart": Icons.restart(self, c, s * 1.1, col)
		"home": Icons.home(self, c, s * 1.1, col)
		"close": Icons.cross(self, c, s * 0.9, col)
