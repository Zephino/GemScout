// Keeps the web version up to date (the same way as Mythriven and Wave
// Defence). The web build workflow writes the version into the page
// (window.GEMSCOUT_VERSION) and copies this file next to it.
//  - Every game file (.pck, .wasm, .js) is asked for with ?v=<version>, so the
//    browser and GitHub's caches can never mix files from two versions.
//  - In the first 30 s after the game opens it fetches the page fresh from the
//    internet; if a newer version is online it clears the saved copy and
//    reloads into it (only right after opening, never mid-cave).
//  - window.gemscoutForceUpdate() (Settings → Update app) clears the saved
//    copy (service worker and its caches) and reloads from the internet.
(function () {
	var VER = String(window.GEMSCOUT_VERSION || "");
	var stamped = VER !== "" && VER.indexOf("__") !== 0;
	var opened = Date.now();

	function forceUpdate() {
		var jobs = [];
		if ("serviceWorker" in navigator) {
			jobs.push(navigator.serviceWorker.getRegistrations().then(function (regs) {
				return Promise.all(regs.map(function (r) { return r.unregister(); }));
			}));
		}
		if (window.caches && caches.keys) {
			jobs.push(caches.keys().then(function (keys) {
				return Promise.all(keys.map(function (k) { return caches.delete(k); }));
			}));
		}
		var go = function () { location.replace(location.pathname + "?updated=" + Date.now()); };
		Promise.all(jobs).then(go, go);
	}
	window.gemscoutForceUpdate = forceUpdate;

	if (!stamped) return;

	function withVer(url) {
		if (typeof url !== "string" || !/\.(pck|wasm|js)(\?|$)/i.test(url) || /[?&]v=/.test(url)) return url;
		return url + (url.indexOf("?") >= 0 ? "&" : "?") + "v=" + encodeURIComponent(VER);
	}
	var realFetch = window.fetch;
	window.fetch = function (input, init) {
		if (typeof input === "string") input = withVer(input);
		else if (input && typeof Request !== "undefined" && input instanceof Request && withVer(input.url) !== input.url) {
			input = new Request(withVer(input.url), input);
		}
		return realFetch.call(this, input, init);
	};
	var realOpen = XMLHttpRequest.prototype.open;
	XMLHttpRequest.prototype.open = function (method, url) {
		arguments[1] = withVer(url);
		return realOpen.apply(this, arguments);
	};

	if (navigator.onLine === false) return;
	realFetch(location.pathname + "?cb=" + Date.now(), { cache: "no-store" })
		.then(function (r) { return r.ok ? r.text() : ""; })
		.then(function (html) {
			var m = html.match(/GEMSCOUT_VERSION="([^"]+)"/);
			if (m && m[1] !== VER && Date.now() - opened < 30000) forceUpdate();
		})
		.catch(function () {});
})();
