class_name SoundManager
extends Node

## Synthetic Audio Generator for self-contained audio feedback without external assets
var audio_players: Array[AudioStreamPlayer] = []
var combo_pitch: float = 1.0

func _ready() -> void:
	for i in range(8):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(p)
		audio_players.append(p)

func _get_available_player() -> AudioStreamPlayer:
	for p in audio_players:
		if not p.playing:
			return p
	return audio_players[0]

func play_launch() -> void:
	var player: AudioStreamPlayer = _get_available_player()
	player.stream = _create_launch_tone()
	player.pitch_scale = randf_range(0.95, 1.05)
	player.volume_db = -4.0
	player.play()

func play_capture(combo_count: int) -> void:
	var player: AudioStreamPlayer = _get_available_player()
	player.stream = _create_capture_tone()
	combo_pitch = clampf(1.0 + (combo_count * 0.06), 1.0, 2.2)
	player.pitch_scale = combo_pitch
	player.volume_db = -2.0
	player.play()

func play_death() -> void:
	combo_pitch = 1.0
	var player: AudioStreamPlayer = _get_available_player()
	player.stream = _create_death_noise()
	player.pitch_scale = 1.0
	player.volume_db = 0.0
	player.play()

func _create_launch_tone() -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	var num_samples: int = int(stream.mix_rate * 0.09)
	var data: PackedByteArray = PackedByteArray()
	data.resize(num_samples)
	for i in range(num_samples):
		var t: float = float(i) / float(stream.mix_rate)
		var freq: float = lerpf(300.0, 750.0, float(i) / float(num_samples))
		var envelope: float = 1.0 - (float(i) / float(num_samples))
		var sample: float = sin(t * freq * TAU) * envelope * 0.7
		var byte_val: int = clampi(int((sample * 127.0) + 128.0), 0, 255)
		data.encode_u8(i, byte_val)
	stream.data = data
	return stream

func _create_capture_tone() -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	var num_samples: int = int(stream.mix_rate * 0.16)
	var data: PackedByteArray = PackedByteArray()
	data.resize(num_samples)
	for i in range(num_samples):
		var t: float = float(i) / float(stream.mix_rate)
		var freq: float = 520.0
		if i > num_samples * 0.35:
			freq = 780.0
		var envelope: float = exp(-float(i) / float(num_samples) * 3.5)
		var sample: float = sin(t * freq * TAU) * envelope * 0.75
		var byte_val: int = clampi(int((sample * 127.0) + 128.0), 0, 255)
		data.encode_u8(i, byte_val)
	stream.data = data
	return stream

func _create_death_noise() -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	var num_samples: int = int(stream.mix_rate * 0.35)
	var data: PackedByteArray = PackedByteArray()
	data.resize(num_samples)
	for i in range(num_samples):
		var envelope: float = exp(-float(i) / float(num_samples) * 4.0)
		var noise: float = (randf() * 2.0 - 1.0) * envelope * 0.9
		var byte_val: int = clampi(int((noise * 127.0) + 128.0), 0, 255)
		data.encode_u8(i, byte_val)
	stream.data = data
	return stream
