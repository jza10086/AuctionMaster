extends Node
## Local presentation playlist; shuffle bags never affect the host's gameplay RNG.
@export var audio: PartyGameAudio
@export var tracks: Array[PartyAudioCue] = []
var _bag: Array[int] = []
var _last: int = -1
var _active: bool = false
var _handle: PartyAudioHandle

func _ready() -> void:
	assert(audio != null and not tracks.is_empty())
	for cue: PartyAudioCue in tracks:
		assert(cue != null and cue.validate() == OK)
	audio.playback_ended.connect(_on_playback_ended)

func start() -> void:
	if _active:
		return
	_active = true
	_play_next()

func stop() -> void:
	_active = false
	if _handle != null:
		_handle.stop(0.0)
		_handle = null

func _play_next() -> void:
	if _bag.is_empty():
		for index: int in tracks.size():
			_bag.append(index)
		_bag.shuffle()
		if _bag.size() > 1 and _bag[0] == _last:
			var swap: int = _bag[0]
			_bag[0] = _bag[1]
			_bag[1] = swap
	_last = _bag.pop_front()
	_handle = audio.play_music(tracks[_last], 0.4)
	if _handle.error != OK:
		_active = false
		push_error("Auction music playback failed: " + error_string(_handle.error))

func _on_playback_ended(handle: PartyAudioHandle, _cue: PartyAudioCue, category: PartyGameAudio.Category, reason: PartyAudioHandle.EndReason) -> void:
	if _active and handle == _handle and category == PartyGameAudio.Category.MUSIC and reason == PartyAudioHandle.EndReason.COMPLETED:
		_play_next()
