@tool
@icon("res://addons/spine38/icon.svg")
class_name Spine38Sprite
extends Node2D
## Toca um personagem exportado em JSON pelo Spine 3.8.
##
## Importe pelo painel "Spine38" e escolha a animação no Inspector.
## Pelo código: [code]$Personagem.play("Idle")[/code].
## Suporta ossos, rotate/translate/scale/shear, imagens (region) e meshes (com e sem pesos).
# ponytail: sem IK, deform, timelines de slot/drawOrder, eventos, skins extras, mix entre
# animações, blend modes e clipping. O nó mostra um aviso se o JSON usar algum deles.

## Emitido quando uma animação sem loop chega ao fim.
signal animation_finished(anim_name: String)

## O .json exportado pelo Spine 3.8.
@export var skeleton_json: JSON:
	set(v):
		if skeleton_json and skeleton_json.changed.is_connected(_load):
			skeleton_json.changed.disconnect(_load)
		skeleton_json = v
		if v:
			v.changed.connect(_load)
		_load()
## Pasta das imagens. Vazio = pasta "images" ao lado do JSON.
@export_dir var images_dir := "":
	set(v):
		images_dir = v
		_load()
## Animação tocando agora.
@export var animation := "":
	set(v):
		animation = v
		time = 0.0
		queue_redraw()
## Recomeça a animação quando ela termina.
@export var loop := true
## 1 = normal, 2 = dobro da velocidade, 0.5 = metade.
@export_range(0.0, 4.0, 0.05, "or_greater") var speed := 1.0
## Desligue para pausar (também pausa a prévia no editor).
@export var playing := true

## Tempo atual da animação, em segundos.
var time := 0.0

var _parent := PackedInt32Array()
var _setup := PackedFloat32Array() # 7 por osso: x, y, rot, scaleX, scaleY, shearX, shearY
var _slots := [] # [osso, cor, attachment]
var _anims := {} # nome -> [[osso, tipo, keys], ...]
var _dur := {}
var _warnings := PackedStringArray()


## Toca uma animação do começo.
func play(anim: String, loop_anim := true) -> void:
	loop = loop_anim
	animation = anim
	playing = true


## Nomes das animações do personagem.
func get_animations() -> PackedStringArray:
	return PackedStringArray(_anims.keys())


## O que este JSON usa e o runtime ignora (vazio = tudo suportado).
static func unsupported(d: Dictionary) -> PackedStringArray:
	var w := PackedStringArray()
	var ver: String = d.get("skeleton", {}).get("spine", "?")
	if not ver.begins_with("3.8"):
		w.append("Exportado pelo Spine %s; este addon lê o formato do Spine 3.8." % ver)
	for b in d.get("bones", []):
		if b.get("transform", "normal") != "normal":
			w.append("Osso '%s' usa herança '%s'; tratado como normal." % [b.name, b.transform])
	for k in ["ik", "transform", "path"]:
		if d.has(k):
			w.append("Constraints do tipo '%s' são ignoradas." % k)
	var skins = d.get("skins", [])
	for skin in skins if skins is Array else []:
		if skin.name != "default":
			w.append("Skin '%s' é ignorada (só a default é usada)." % skin.name)
		for slot in skin.get("attachments", {}).values():
			for a_name in slot:
				var t: String = slot[a_name].get("type", "region")
				if t in ["linkedmesh", "clipping"]:
					w.append("'%s' é do tipo '%s', que é ignorado." % [a_name, t])
	for anim in d.get("animations", {}):
		for k in d.animations[anim]:
			if k != "bones":
				w.append("Animação '%s': timelines de '%s' são ignoradas." % [anim, k])
	return w


## Imagens (caminho sem .png) usadas pela skin default.
static func images_used(d: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var atts := _default_skin(d)
	for slot in atts.values():
		for a_name in slot:
			var a: Dictionary = slot[a_name]
			if a.get("type", "region") in ["region", "mesh"] and a.get("path", a_name) not in out:
				out.append(a.get("path", a_name))
	return out


static func _default_skin(d: Dictionary) -> Dictionary:
	var skins = d.get("skins", [])
	for skin in skins if skins is Array else []:
		if skin.name == "default":
			return skin.get("attachments", {})
	return {}


func _load() -> void:
	_parent.clear()
	_setup.clear()
	_slots.clear()
	_anims.clear()
	_dur.clear()
	_warnings = PackedStringArray()
	_load_data()
	queue_redraw()
	notify_property_list_changed()
	update_configuration_warnings()


func _load_data() -> void:
	if skeleton_json == null:
		return
	var d = skeleton_json.data
	if not (d is Dictionary and d.has("skeleton") and d.has("bones")):
		_warnings.append("Este JSON não parece ter sido exportado pelo Spine.")
		return
	_warnings = unsupported(d)
	var dir := images_dir if images_dir else skeleton_json.resource_path.get_base_dir().path_join("images")

	var bone_idx := {}
	for b in d.bones:
		_parent.append(bone_idx.get(b.get("parent", ""), -1))
		bone_idx[b.name] = _parent.size() - 1
		_setup.append_array(PackedFloat32Array([b.get("x", 0.0), b.get("y", 0.0), b.get("rotation", 0.0),
				b.get("scaleX", 1.0), b.get("scaleY", 1.0), b.get("shearX", 0.0), b.get("shearY", 0.0)]))

	var atts := _default_skin(d)
	for slot in d.get("slots", []):
		var att_name = slot.get("attachment")
		var a = atts.get(slot.name, {}).get(att_name) if att_name else null
		_slots.append([bone_idx[slot.bone], Color.html(slot.get("color", "ffffffff")),
				_attachment(a, att_name, dir) if a else null])

	for anim_name in d.get("animations", {}):
		var anim: Dictionary = d.animations[anim_name]
		var tls := []
		var dur := 0.0
		for bone_name in anim.get("bones", {}):
			for type in anim.bones[bone_name]:
				var keys: Array = anim.bones[bone_name][type]
				tls.append([bone_idx[bone_name], type, keys])
				dur = maxf(dur, keys[-1].get("time", 0.0))
		_anims[anim_name] = tls
		_dur[anim_name] = dur
	if not _anims.has(animation) and not _anims.is_empty():
		animation = _anims.keys()[0]


func _attachment(a: Dictionary, att_name: String, dir: String):
	var type: String = a.get("type", "region")
	var verts := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var tris: PackedInt32Array
	if type == "region":
		var w: float = a.get("width", 32.0) * a.get("scaleX", 1.0) / 2
		var h: float = a.get("height", 32.0) * a.get("scaleY", 1.0) / 2
		var m := Transform2D(deg_to_rad(a.get("rotation", 0.0)), Vector2(a.get("x", 0.0), a.get("y", 0.0)))
		for c in [Vector2(-w, -h), Vector2(-w, h), Vector2(w, h), Vector2(w, -h)]:
			var p: Vector2 = m * c
			verts.append(p.x)
			verts.append(p.y)
		uvs = PackedVector2Array([Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)])
		tris = PackedInt32Array([0, 1, 2, 2, 3, 0])
	elif type == "mesh":
		var uv: Array = a.uvs
		for i in range(0, uv.size(), 2):
			uvs.append(Vector2(uv[i], uv[i + 1]))
		verts = PackedFloat32Array(a.vertices)
		tris = PackedInt32Array(a.triangles)
	else:
		return null
	var path := dir.path_join(a.get("path", att_name) + ".png")
	if not ResourceLoader.exists(path):
		_warnings.append("Imagem não encontrada: %s" % path)
		return null
	return {verts = verts, uvs = uvs, tris = tris, weighted = verts.size() != uvs.size() * 2, tex = load(path)}


func _get_configuration_warnings() -> PackedStringArray:
	if skeleton_json == null:
		return ["Arraste para \"Skeleton Json\" o .json exportado pelo Spine 3.8, ou use o painel Spine38 > Importar."]
	return _warnings


func _validate_property(p: Dictionary) -> void:
	if p.name == "animation" and not _anims.is_empty():
		p.hint = PROPERTY_HINT_ENUM
		p.hint_string = ",".join(get_animations())


func _process(delta: float) -> void:
	if not playing or not _dur.has(animation):
		return
	var dur: float = _dur[animation]
	var before := time
	time += delta * speed
	if loop and dur > 0:
		time = fposmod(time, dur)
	else:
		time = clampf(time, 0.0, dur)
		if before < dur and time >= dur:
			animation_finished.emit(animation)
	queue_redraw()


func _draw() -> void:
	var ci := get_canvas_item()
	for sp in _world_points():
		var s: Array = sp[0]
		var a: Dictionary = s[2]
		RenderingServer.canvas_item_add_triangle_array(ci, a.tris, sp[1], PackedColorArray([s[1]]),
				a.uvs, PackedInt32Array(), PackedFloat32Array(), a.tex.get_rid())


## Vértices de cada slot visível no tempo atual, em coordenadas do Godot (y pra baixo).
func _world_points() -> Array:
	var pose := _setup.duplicate()
	for tl in _anims.get(animation, []):
		var i: int = tl[0] * 7
		match tl[1]:
			"rotate":
				pose[i + 2] += _sample(tl[2], "angle", "angle", 0.0, true).x
			"translate":
				var v := _sample(tl[2], "x", "y", 0.0)
				pose[i] += v.x
				pose[i + 1] += v.y
			"scale":
				var v := _sample(tl[2], "x", "y", 1.0)
				pose[i + 3] *= v.x
				pose[i + 4] *= v.y
			"shear":
				var v := _sample(tl[2], "x", "y", 0.0)
				pose[i + 5] += v.x
				pose[i + 6] += v.y

	var world: Array[Transform2D] = []
	world.resize(_parent.size())
	for b in _parent.size():
		var i := b * 7
		var r := deg_to_rad(pose[i + 2])
		var m := Transform2D(Vector2.from_angle(r + deg_to_rad(pose[i + 5])) * pose[i + 3],
				Vector2.from_angle(r + deg_to_rad(90.0 + pose[i + 6])) * pose[i + 4],
				Vector2(pose[i], pose[i + 1]))
		world[b] = m if _parent[b] < 0 else world[_parent[b]] * m

	var out := []
	for s in _slots:
		var a = s[2]
		if a == null:
			continue
		var v: PackedFloat32Array = a.verts
		var pts := PackedVector2Array()
		var j := 0
		while j < v.size():
			var p := Vector2.ZERO
			if a.weighted: # [nº de ossos, (osso, x, y, peso) * n] por vértice
				var end := j + 1 + int(v[j]) * 4
				j += 1
				while j < end:
					p += world[int(v[j])] * Vector2(v[j + 1], v[j + 2]) * v[j + 3]
					j += 4
			else:
				p = world[s[0]] * Vector2(v[j], v[j + 1])
				j += 2
			pts.append(Vector2(p.x, -p.y)) # Spine é y pra cima
		out.append([s, pts])
	return out


## Valor da timeline no tempo atual. Antes da 1ª key = pose de setup (d).
func _sample(keys: Array, fa: String, fb: String, d: float, angle := false) -> Vector2:
	if time < keys[0].get("time", 0.0):
		return Vector2(d, d)
	var i := keys.size() - 1
	while keys[i].get("time", 0.0) > time:
		i -= 1
	var k: Dictionary = keys[i]
	var a := Vector2(k.get(fa, d), k.get(fb, d))
	if i == keys.size() - 1:
		return a
	var nk: Dictionary = keys[i + 1]
	var b := Vector2(nk.get(fa, d), nk.get(fb, d))
	if angle: # caminho mais curto, como o runtime 3.8
		b.x = a.x + wrapf(b.x - a.x, -180.0, 180.0)
	var t0: float = k.get("time", 0.0)
	return a.lerp(b, _curve(k, (time - t0) / (nk.get("time", 0.0) - t0)))


## Curva da key (3.8: "curve" = cx1, c2 = cy1, c3 = cx2, c4 = cy2).
func _curve(k: Dictionary, p: float) -> float:
	var c = k.get("curve")
	if c == null:
		return p
	if c is String: # "stepped"
		return 0.0
	var x1: float = c
	var y1: float = k.get("c2", 0.0)
	var x2: float = k.get("c3", 1.0)
	var y2: float = k.get("c4", 1.0)
	var lo := 0.0
	var hi := 1.0
	for _i in 20: # acha s com x(s) = p
		var s := (lo + hi) * 0.5
		if bezier_interpolate(0.0, x1, x2, 1.0, s) < p:
			lo = s
		else:
			hi = s
	return bezier_interpolate(0.0, y1, y2, 1.0, (lo + hi) * 0.5)
