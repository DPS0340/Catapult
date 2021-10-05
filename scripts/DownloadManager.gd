extends Node


signal status_message
signal download_started
signal download_finished

# Give progress update after this time or this amount downloaded,
# whichever comes first.
const _PROGRESS_AFTER_MSECS = 2000
const _PROGRESS_AFTER_BYTES = 1024 * 1024 * 5

var _current_filename: String = ""
var _current_file_path: String = ""
var _download_ongoing: bool = false

onready var _http = $HTTPRequest


func download_file(url: String, target_dir: String, target_filename: String) -> void:
	
	emit_signal("status_message", "Downloading %s..." % target_filename)
	emit_signal("download_started")
	_current_filename = target_filename
	_current_file_path = target_dir.plus_file(target_filename)
	_http.download_file = target_dir + "/" + target_filename
	print(_http.download_file)
	_http.request(url)
	_download_ongoing = true
	var last_progress_time = OS.get_system_time_msecs()
	var last_progress_bytes = 0
	
	while _download_ongoing:
		
		var downloaded = _http.get_downloaded_bytes()
		var total = _http.get_body_size()
		
		if downloaded < 1:
			yield(get_tree(), "idle_frame")
			continue
		
		var delta_time = OS.get_system_time_msecs() - last_progress_time
		var delta_bytes = downloaded - last_progress_bytes
		
		if (delta_time >= _PROGRESS_AFTER_MSECS) or (delta_bytes >= _PROGRESS_AFTER_BYTES):
			emit_signal("status_message", _get_progress_string(downloaded, total, delta_time, delta_bytes))
			last_progress_time = OS.get_system_time_msecs()
			last_progress_bytes = downloaded
		
		yield(get_tree(), "idle_frame")


func _get_progress_string(downloaded: int, total: int,
		delta_time: int, delta_bytes: int) -> String:
	
	var amount_str = ""
	if (downloaded > 1024*1024):
		amount_str = "%.1f MB" % (downloaded / 1048576.0)
	else:
		# warning-ignore:integer_division
		amount_str = "%s KB" % (downloaded / 1024)
		
	var percent_str = ""
	if total > 0:
		percent_str = " (%.1f%%)" % ((float(downloaded) / total) * 100)
		
	var speed_str = " at "
	var speed_bps = delta_bytes / float(delta_time) * 1000.0
	if speed_bps > 1048576.0:
		speed_str += "%.1f MB/s" % (speed_bps / 1048576.0)
	else:
		speed_str += "%d KB/s" % (speed_bps / 1024.0)
		
	var result = "Downloading: %s%s%s" % [amount_str, percent_str, speed_str]
	return result


func _on_HTTPRequest_request_completed(_result: int, _response_code: int,
		_headers: PoolStringArray, _body: PoolByteArray) -> void:
	
	_download_ongoing = false
	emit_signal("status_message", "[b]HTTPRequest info:[/b]\n[u]Result:[/u] %s\n[u]Response code:[/u] %s\n[u]Headers:[/u] %s" %
			[_result, _response_code, _headers], Enums.MSG_DEBUG)
			
	if Directory.new().file_exists(_current_file_path):
		emit_signal("status_message", "Finished downloading %s." % _current_filename)
	else:
		emit_signal("status_message", "Failed to download %s." % _current_filename, Enums.MSG_ERROR)
	
	emit_signal("download_finished")


