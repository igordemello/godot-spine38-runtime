@tool
extends VBoxContainer
## Painel "Spine38": traz um personagem exportado pelo Spine 3.8 para dentro do projeto.

const DEST := "res://spine"
const Sprite := preload("spine38_sprite.gd")
const OK_COLOR := "#7ee787"
const WARN_COLOR := "#f2cc60"
const ERR_COLOR := "#ff7b72"
const SCENE := """[gd_scene format=3]

[ext_resource type="Script" path="%s" id="1"]
[ext_resource type="JSON" path="%s" id="2"]

[node name="%s" type="Node2D"]
script = ExtResource("1")
skeleton_json = ExtResource("2")
"""

var _log := RichTextLabel.new()
var _last_dir := ""


func _init() -> void:
	name = "Spine38"
	var btn := Button.new()
	btn.text = "Importar personagem do Spine…"
	btn.icon = EditorInterface.get_editor_theme().get_icon("Load", "EditorIcons")
	btn.pressed.connect(func(): _ask(EditorFileDialog.FILE_MODE_OPEN_FILE, "Escolha o .json exportado pelo Spine 3.8", import_json))
	add_child(btn)
	var help := Label.new()
	help.text = "No Spine: Exportar > JSON, sem Texture Atlas.\nA cena abre pronta em %s/<nome>/.\nPara atualizar, importe o mesmo .json de novo." % DEST
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.modulate.a = 0.7
	add_child(help)
	_log.custom_minimum_size.y = 160
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.selection_enabled = true
	_log.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(_log)


## Importa (ou atualiza) um personagem. images_dir vazio = procura a pasta sozinho.
func import_json(json_path: String, images_dir := "") -> void:
	_say("\nImportando %s" % json_path.get_file())
	var d = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not (d is Dictionary and d.has("skeleton") and d.has("bones")):
		_say("✖ Este arquivo não parece um JSON exportado pelo Spine.", ERR_COLOR)
		return
	_say("Spine %s · %d ossos · %d slots · animações: %s" % [d.skeleton.get("spine", "?"), d.bones.size(),
			d.get("slots", []).size(), ", ".join(PackedStringArray(d.get("animations", {}).keys()))])

	var images := Sprite.images_used(d)
	if images_dir == "":
		images_dir = _find_images(json_path, d, images)
	if images_dir == "":
		_say("Não achei a pasta das imagens. Escolha a pasta \"images\" que o Spine usa.", WARN_COLOR)
		_ask(EditorFileDialog.FILE_MODE_OPEN_DIR, "Onde estão as imagens deste personagem?",
				func(dir: String): import_json(json_path, dir))
		return

	var char_name := json_path.get_file().get_basename()
	var dest := DEST.path_join(char_name)
	var json_dest := dest.path_join(char_name + ".json")
	_copy(json_path, json_dest)
	var copied := 0
	for img in images:
		var from := images_dir.path_join(img + ".png")
		if FileAccess.file_exists(from):
			_copy(from, dest.path_join("images").path_join(img + ".png"))
			copied += 1
		else:
			_say("⚠ Imagem faltando: %s" % from, WARN_COLOR)
	_say("✔ JSON e %d de %d imagens copiados para %s" % [copied, images.size(), dest], OK_COLOR)
	for w in Sprite.unsupported(d):
		_say("⚠ " + w, WARN_COLOR)

	var scene := dest.path_join(char_name + ".tscn")
	if FileAccess.file_exists(scene):
		_say("A cena %s já existia: mantive suas mudanças nela e só atualizei os dados." % scene)
	else:
		var f := FileAccess.open(scene, FileAccess.WRITE)
		var sprite_script: String = get_script().resource_path.get_base_dir().path_join("spine38_sprite.gd")
		f.store_string(SCENE % [sprite_script, json_dest, char_name.validate_node_name()])
		f.close()
		_say("✔ Cena criada: %s" % scene, OK_COLOR)

	_say("Atualizando o FileSystem…")
	var efs := EditorInterface.get_resource_filesystem()
	efs.scan()
	await efs.filesystem_changed
	var j := ResourceLoader.load(json_dest, "", ResourceLoader.CACHE_MODE_REPLACE)
	if j:
		j.emit_changed() # personagens já abertos recarregam o JSON novo
	EditorInterface.open_scene_from_path(scene)
	_say("✔ Pronto! Cena aberta. Escolha a animação no Inspector (campo Animation).", OK_COLOR)


## Procura a pasta de imagens: "images" ao lado do JSON, ou o caminho salvo no projeto do Spine.
func _find_images(json_path: String, d: Dictionary, images: PackedStringArray) -> String:
	if images.is_empty():
		return json_path.get_base_dir()
	var rel: String = d.skeleton.get("images", "")
	for candidate in [json_path.get_base_dir().path_join("images"), json_path.get_base_dir().path_join(rel), rel]:
		var dir: String = candidate.simplify_path()
		if dir and FileAccess.file_exists(dir.path_join(images[0] + ".png")):
			return dir
	return ""


## Copia criando as pastas. Pula se origem e destino forem o mesmo arquivo (reimportar de dentro do projeto).
func _copy(from: String, to: String) -> void:
	from = ProjectSettings.globalize_path(from).simplify_path()
	to = ProjectSettings.globalize_path(to).simplify_path()
	if from.to_lower() == to.to_lower():
		return
	DirAccess.make_dir_recursive_absolute(to.get_base_dir())
	DirAccess.copy_absolute(from, to)


func _ask(mode: EditorFileDialog.FileMode, title: String, then: Callable) -> void:
	var fd := EditorFileDialog.new()
	fd.access = EditorFileDialog.ACCESS_FILESYSTEM
	fd.file_mode = mode
	fd.title = title
	if mode == EditorFileDialog.FILE_MODE_OPEN_FILE:
		fd.add_filter("*.json", "JSON exportado pelo Spine 3.8")
	if _last_dir:
		fd.current_dir = _last_dir
	var picked := func(path: String):
		_last_dir = path if mode == EditorFileDialog.FILE_MODE_OPEN_DIR else path.get_base_dir()
		then.call(path)
	fd.file_selected.connect(picked)
	fd.dir_selected.connect(picked)
	fd.visibility_changed.connect(func(): if not fd.visible: fd.queue_free())
	EditorInterface.get_base_control().add_child(fd)
	fd.popup_file_dialog()


func _say(msg: String, color := "") -> void:
	msg = msg.replace("[", "[lb]")
	_log.append_text(("[color=%s]%s[/color]\n" % [color, msg]) if color else msg + "\n")
