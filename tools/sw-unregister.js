// 구 Godot 오프라인 서비스워커를 스스로 해제하고 캐시를 비운다.
// (파일명 동일 + 내용 변경 → 브라우저가 SW 업데이트로 인식 후 해제)
self.addEventListener('install', (event) => {
	self.skipWaiting();
});
self.addEventListener('activate', (event) => {
	event.waitUntil(
		caches.keys()
			.then((keys) => Promise.all(keys.map((k) => caches.delete(k))))
			.then(() => self.registration.unregister())
			.then(() => self.clients.claim())
	);
});
self.addEventListener('fetch', (event) => {
	// 가로채지 않음: 이후 요청은 전부 네트워크로 통과
});
