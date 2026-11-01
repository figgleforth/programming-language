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

	// The value of an element, the way the server gets it: a Bool for a checkbox or a radio, an Array for a <select multiple>, else the text.
	function value_of(el) {
		if (el.type === 'checkbox' || el.type === 'radio') return el.checked
		if (el.tagName === 'SELECT' && el.multiple) return Array.from(el.selectedOptions, o => o.value)
		if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.tagName === 'SELECT') return el.value
		return null
	}

	// Each element with an on-server-read token, with its value now.
	function read_inputs() {
		const inputs = {}
		document.querySelectorAll('[#{DOM_ATTRIBUTE_PREFIX}-on-server-read]').forEach(el => {
			const value = value_of(el)
			if (value !== null) inputs[el.getAttribute('#{DOM_ATTRIBUTE_PREFIX}-on-server-read')] = value
		})
		return inputs
	}

	// A morph can move the focus. That focus is not the user's, so it sends no focus or blur event.
	let morphing = false
	function morph(target, html) {
		morphing = true
		try {
			Idiomorph.morph(target, html, MORPH)
		} finally {
			morphing = false
		}
	}

	// Each event gets a number when it is sent. A reply that comes back after the reply to a newer event is dropped, so a slow reply cannot replace newer text.
	let sent    = 0
	let applied = 0

	// Sends one event for the closure that `token` names. `own_value` is the element's own value, sent under its own token; undefined sends none.
	async function send_event(element, token, own_value) {
		const number                = ++sent
		const replacement_target_id = element.getAttribute('#{DOM_ATTRIBUTE_PREFIX}-replacement-target-id')

		const inputs = read_inputs()
		if (own_value !== undefined) inputs[token] = own_value

		// The page path and query tell the server which page to run again when the handler returns no HTML.
		const url      = `#{DOM_EVENT_URL}/${token}`
		const path     = location.pathname
		const query    = location.search.slice(1)
		const as_json  = click_format() === 'json'
		const response = await fetch(url, {
			method: 'POST',
			headers: {
				'Content-Type': as_json ? 'application/json' : '#{CLICK_BYTES_CONTENT_TYPE}',
			},
			body: as_json ? JSON.stringify({ inputs, path, query }) : encode_click(path, query, inputs),
		})

		const html = await response.text()
		if (number < applied) return
		applied = number

		if (!response.ok) { // todo; I just realized these probably need proper errors also
			console.error(`${url}: ${response.status}`)
		}

		// 1. The reply names an element: it is that element's new HTML.
		const target_id = response.headers.get('#{DOM_TARGET_ID_HEADER}')
		if (target_id) {
			const target = document.getElementById(target_id)
			if (target) {
				with_transition(() => morph(target, html))
			} else {
				// The reply is only one element, so it cannot stand in for the page. Load the page again instead.
				console.warn(`no element with id "${target_id}" on this page`)
				location.reload()
			}
			return
		}

		// The reply is a full page. A script in it does not run, so live_page.js does not add its listeners a second time.
		const doc = new DOMParser().parseFromString(html, 'text/html')

		// 2. The element names an element to replace: morph it into the same element from the new page.
		const fresh   = replacement_target_id && doc.getElementById(replacement_target_id)
		const current = replacement_target_id && document.getElementById(replacement_target_id)
		if (fresh && current) {
			with_transition(() => morph(current, fresh))
			return
		}

		// 3. Morph <body> into the new page's <body>.
		with_transition(() => {
			morph(document.body, doc.body)
			if (doc.title) document.title = doc.title
		})
	}

	// The element that has a closure for this event, and its token.
	function handler_for(event_name, target) {
		const attribute = `#{DOM_ATTRIBUTE_PREFIX}-on${event_name}`
		const element   = target instanceof Element && target.closest(`[${attribute}]`)
		return element ? [element, element.getAttribute(attribute)] : [null, null]
	}

	// The server fills in the DOM_ATTRIBUTE_PREFIX, DOM_TARGET_ID_HEADER and DOM_EVENT_URL placeholders (constants.rb) when it reads this file.
	document.addEventListener('click', (event) => {
		// A click on a control inside an element with an onclick belongs to the control, so the element's closure does not run.
		const element = event.target.closest('a[href], button, input:not([type="hidden"]), select, textarea, summary, [#{DOM_ATTRIBUTE_PREFIX}-onclick]')
		if (!element || !element.hasAttribute('#{DOM_ATTRIBUTE_PREFIX}-onclick')) return

		event.preventDefault()
		event.stopPropagation()
		send_event(element, element.getAttribute('#{DOM_ATTRIBUTE_PREFIX}-onclick'))
	})

	// A form's submit runs its closure, and the page does not load again.
	document.addEventListener('submit', (event) => {
		const [form, token] = handler_for('submit', event.target)
		if (!form) return

		event.preventDefault()
		send_event(form, token)
	})

	// Typing waits until no key has come for 250 ms, so one word is one event, not one for each letter.
	const INPUT_WAIT_MS  = 250
	const waiting_inputs = new WeakMap()
	document.addEventListener('input', (event) => {
		const [element, token] = handler_for('input', event.target)
		if (!element) return

		clearTimeout(waiting_inputs.get(element))
		waiting_inputs.set(element, setTimeout(() => send_event(element, token, value_of(element)), INPUT_WAIT_MS))
	})

	document.addEventListener('change', (event) => {
		const [element, token] = handler_for('change', event.target)
		if (element) send_event(element, token, value_of(element))
	})

	// Every key, also one that repeats while it is held down.
	for (const event_name of ['keydown', 'keyup']) {
		document.addEventListener(event_name, (event) => {
			const [element, token] = handler_for(event_name, event.target)
			if (element) send_event(element, token, event.key)
		})
	}

	// focus and blur do not bubble, so they are caught on the way down (the last argument, true).
	for (const event_name of ['focus', 'blur']) {
		document.addEventListener(event_name, (event) => {
			if (morphing) return
			const [element, token] = handler_for(event_name, event.target)
			// Only the element that has the closure: a focus on a field inside it is not the element's own focus.
			if (element && element === event.target) send_event(element, token, value_of(element))
		}, true)
	}
})()
