(function () {
	let size = window.innerWidth + 'x' + window.innerHeight;
	if (document.cookie.indexOf('#{DOM_BROWSER_VIEW_SIZE}=' + size) === -1) {
		document.cookie = '#{DOM_BROWSER_VIEW_SIZE}=' + size + '; path=/'
		window.location = ''
	}

	// Idiomorph (ruby/shared/3rd/, loaded before this file) keeps the elements that are already on the page and changes only what differs, so focus, the cursor, typed text and scroll stay.
	// ignoreActiveValue: the input that has the focus keeps the value that the user is typing.
	const MORPH = { morphStyle: 'outerHTML', ignoreActiveValue: true }

	// Animates from the old view to the new one, where the browser can.
	function with_transition(update) {
		if (document.startViewTransition) {
			document.startViewTransition(update)
		} else {
			update()
		}
	}

	// A click goes as bytes. To read clicks in the browser's network tab, run `localStorage.live_page_format = 'json'` in the console.
	function click_format() {
		try {
			return localStorage.getItem('live_page_format') || 'bytes'
		} catch {
			return 'bytes'
		}
	}

	// The click as bytes. lang/web/live_page.code has the format and decodes it. Numbers are big-endian.
	function encode_click(path, query, inputs) {
		const text  = new TextEncoder()
		const parts = []
		const u8    = (n) => parts.push(Uint8Array.of(n))
		const u16   = (n) => { const b = new Uint8Array(2); new DataView(b.buffer).setUint16(0, n); parts.push(b) }
		const str   = (s) => { const bytes = text.encode(s); const b = new Uint8Array(4); new DataView(b.buffer).setUint32(0, bytes.length); parts.push(b, bytes) }

		u8(1) // the version
		str(path)
		str(query)

		const entries = Object.entries(inputs)
		u16(entries.length)
		for (const [element_id, value] of entries) {
			str(element_id)
			if (Array.isArray(value)) {
				u8(1); u16(value.length); value.forEach(str)
			} else if (typeof value === 'boolean') {
				u8(3); u8(value ? 1 : 0)
			} else if (value === null || value === undefined) {
				u8(2)
			} else {
				u8(0); str(String(value))
			}
		}

		const bytes = new Uint8Array(parts.reduce((size, part) => size + part.length, 0))
		let at = 0
		for (const part of parts) {
			bytes.set(part, at)
			at += part.length
		}
		return bytes
	}

	document.addEventListener('click', async (event) => {
		// The server fills in the DOM_ATTRIBUTE_PREFIX, DOM_TARGET_ID_HEADER and DOM_EVENT_URL placeholders (constants.rb) when it reads this file.
		const element = event.target.closest('a[href], button, input:not([type="hidden"]), select, textarea, summary, [#{DOM_ATTRIBUTE_PREFIX}-onclick]')

		if (!element) return
		if (!element.hasAttribute('#{DOM_ATTRIBUTE_PREFIX}-onclick')) return
		const object_id = element.getAttribute('#{DOM_ATTRIBUTE_PREFIX}-onclick')
		const replacement_target_id = element.getAttribute('#{DOM_ATTRIBUTE_PREFIX}-replacement-target-id')

		event.preventDefault()
		event.stopPropagation()

		const inputs = {};
		document.querySelectorAll('[#{DOM_ATTRIBUTE_PREFIX}-on-server-read]').forEach(el => {
			const input_id = el.getAttribute('#{DOM_ATTRIBUTE_PREFIX}-on-server-read')

			if (el.type === 'checkbox' || el.type === 'radio') {
				inputs[input_id] = el.checked
			} else if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') {
				inputs[input_id] = el.value
			} else if (el.tagName === 'SELECT') {
				if (el.multiple) {
					inputs[input_id] = Array.from(el.selectedOptions, o => o.value)
				} else {
					inputs[input_id] = el.value
				}
			}
		});

		// The page path and query tell the server which page to run again when the handler returns no HTML.
		const url = `#{DOM_EVENT_URL}/${object_id}`
		const path = location.pathname
		const query = location.search.slice(1)
		const as_json = click_format() === 'json'
		const response = await fetch(url, {
			method: 'POST',
			headers: {
				'Content-Type': as_json ? 'application/json' : '#{CLICK_BYTES_CONTENT_TYPE}',
			},
			body: as_json ? JSON.stringify({ inputs, path, query }) : encode_click(path, query, inputs),
		})

		const html = await response.text()
		if (!response.ok) { // todo; I just realized these probably need proper errors also
			console.error(`${url}: ${response.status}`)
		}

		// 1. The reply names an element: it is that element's new HTML.
		const target_id = response.headers.get('#{DOM_TARGET_ID_HEADER}')
		if (target_id) {
			const target = document.getElementById(target_id)
			if (target) {
				with_transition(() => Idiomorph.morph(target, html, MORPH))
			} else {
				// The reply is only one element, so it cannot stand in for the page. Load the page again instead.
				console.warn(`no element with id "${target_id}" on this page`)
				location.reload()
			}
			return
		}

		// The reply is a full page. A script in it does not run, so live_page.js does not add its listener a second time.
		const doc = new DOMParser().parseFromString(html, 'text/html')

		// 2. The clicked element names an element to replace: morph it into the same element from the new page.
		const fresh = replacement_target_id && doc.getElementById(replacement_target_id)
		const current = replacement_target_id && document.getElementById(replacement_target_id)
		if (fresh && current) {
			with_transition(() => Idiomorph.morph(current, fresh, MORPH))
			return
		}

		// 3. Morph <body> into the new page's <body>.
		with_transition(() => {
			Idiomorph.morph(document.body, doc.body, MORPH)
			if (doc.title) document.title = doc.title
		})
	})
})()
