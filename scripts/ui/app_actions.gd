class_name AppActions
extends RefCounted
## Settings → Fullscreen, Install app, Update app, and the Quit button (as in
## Mythriven). Install and Update are for the web version: it can be
## installed like an app (a progressive web app), which keeps a copy of the
## game on the device; Update clears that copy and reloads, so the newest
## version is one tap away. The page also updates itself: for 30 s after
## opening it checks for a newer version (web/update.js).


static func is_web() -> bool:
	return OS.has_feature("web")


## Fullscreen works in the browser and on PC (phone apps are always full screen).
static func can_fullscreen() -> bool:
	return is_web() or not OS.has_feature("mobile")


static func is_fullscreen() -> bool:
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


static func toggle_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if is_fullscreen() else DisplayServer.WINDOW_MODE_FULLSCREEN)


## "ready" (the browser can install it now), "installed" (running as an app),
## "ios" (Safari: Share → Add to Home Screen), or "unavailable".
static func install_state() -> String:
	if not is_web():
		return "unavailable"
	return str(JavaScriptBridge.eval("""(function(){
		var m=function(q){return window.matchMedia&&window.matchMedia(q).matches;};
		if(m('(display-mode: fullscreen)')||m('(display-mode: standalone)')||navigator.standalone)return 'installed';
		if(window.gemscoutInstall)return 'ready';
		if(/iPad|iPhone|iPod/.test(navigator.userAgent)||(navigator.platform==='MacIntel'&&navigator.maxTouchPoints>1))return 'ios';
		return 'unavailable';})()""", true))


## Shows the browser's own "Install GemScout?" box (the page keeps the
## browser's offer when it loads; see export_presets.cfg's head include).
static func install() -> void:
	if is_web():
		JavaScriptBridge.eval("(function(){var e=window.gemscoutInstall;if(e){window.gemscoutInstall=null;e.prompt();}})()", true)


## Forgets the saved copy of the game and reloads from the internet. Progress
## is safe: it's saved separately.
static func update_now() -> void:
	if not is_web():
		return
	JavaScriptBridge.eval("""(async function(){
		if(typeof window.gemscoutForceUpdate==='function'){window.gemscoutForceUpdate();return;}
		try{
			if(navigator.serviceWorker){var r=await navigator.serviceWorker.getRegistrations();for(var i=0;i<r.length;i++){await r[i].unregister();}}
			if(window.caches){var k=await caches.keys();for(var j=0;j<k.length;j++){await caches.delete(k[j]);}}
		}catch(e){}
		var u=new URL(location.href);u.searchParams.set('v',Date.now());location.replace(u.toString());})()""", true)


## Quits on PC and phone apps. Browsers only let a page close itself when it
## was opened as an app or by a script, so returns false when the tab stays.
static func quit(tree: SceneTree) -> bool:
	if not is_web():
		tree.quit()
		return true
	JavaScriptBridge.eval("window.close()", true)
	return false


## Broad device details for suggestions (never a raw user-agent or an id).
static func client_info() -> Dictionary:
	var info := {
		"game_version": OnlineConfig.game_version(),
		"runtime": "Web" if is_web() else "Native",
		"device_type": "Desktop",
		"platform": "Unknown",
		"browser": "N/A",
	}
	var os_name: String = OS.get_name()
	var mapping := {"Windows": "Windows", "macOS": "macOS", "Linux": "Linux", "FreeBSD": "FreeBSD", "Android": "Android", "iOS": "iOS"}
	if mapping.has(os_name):
		info["platform"] = mapping[os_name]
	if OS.has_feature("mobile"):
		info["device_type"] = "Phone"
	if is_web():
		var ua: String = str(JavaScriptBridge.eval("navigator.userAgent", true)).to_lower()
		info["browser"] = "Other"
		for pair: Array in [["edg/", "Edge"], ["opr/", "Opera"], ["samsungbrowser", "Samsung Internet"], ["firefox", "Firefox"], ["chrome", "Chrome"], ["safari", "Safari"]]:
			if ua.contains(pair[0]):
				info["browser"] = pair[1]
				break
		for pair: Array in [["android", "Android"], ["iphone", "iOS"], ["ipad", "iOS"], ["cros", "ChromeOS"], ["windows", "Windows"], ["mac os", "macOS"], ["linux", "Linux"]]:
			if ua.contains(pair[0]):
				info["platform"] = pair[1]
				break
		if ua.contains("ipad") or (ua.contains("android") and not ua.contains("mobile")):
			info["device_type"] = "Tablet"
		elif ua.contains("mobile") or ua.contains("iphone"):
			info["device_type"] = "Phone"
	return info
