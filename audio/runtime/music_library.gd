extends RefCounted
## Explicit references keep the soundtrack in exported games.
const TRACKS := {
	&"menu": preload("res://audio/assets/music/menu.ogg"),
	&"exploration": preload("res://audio/assets/music/exploration.ogg"),
	&"danger": preload("res://audio/assets/music/danger.ogg"),
}
const TITLES := {
	&"menu": "Kleine Umlaufbahn",
	&"exploration": "Unter fremden Blättern",
	&"danger": "Etwas im Unterholz",
	&"silent": "Musik aus",
}
