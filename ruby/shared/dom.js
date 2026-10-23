(function () {
	let size = window.innerWidth + 'x' + window.innerHeight;
	if (document.cookie.indexOf('#{DOM_BROWSER_VIEW_SIZE}=' + size) === -1) {
		document.cookie = '#{DOM_BROWSER_VIEW_SIZE}=' + size + '; path=/'
		window.location = ''
	}

	document.addEventListener('click', async (event) => {
		// The server fills in the DOM_ATTRIBUTE_PREFIX, DOM_TARGET_ID_HEADER and DOM_EVENT_URL placeholders (constants.rb) when it reads this file.
		const element = event.target.closest('a[href], button, input:not([type="hidden"]), select, textarea, summary, [#{DOM_ATTRIBUTE_PREFIX}-onclick]')

		if (!element) return
		if (!element.hasAttribute('#{DOM_ATTRIBUTE_PREFIX}-onclick')) return
		const object_id = element.getAttribute('#{DOM_ATTRIBUTE_PREFIX}-onclick')

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

		const url = `#{DOM_EVENT_URL}/${object_id}`
		const response = await fetch(url, {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json',
			},
			body: JSON.stringify({inputs})
		})

        function update_target_html(target, html) {
            if (!html) return;

            const node = target || document.documentElement;
            const update = () => { node.outerHTML = html; };

            if (document.startViewTransition) {
                document.startViewTransition(update);
            } else {
                update();
            }
        }

		const body = await response.text()
		const target_id = response.headers.get('#{DOM_TARGET_ID_HEADER}')
		const target = document.getElementById(target_id)
        update_target_html(target, body)
	})
})()
