// Runs ruby/shared/live_page.js in Node, in a small fake browser, and checks what it sends and what it replaces. tests/live_page_js_test.rb fills the placeholders and starts this file.
// Usage: node live_page_harness.js <filled live_page.js> <constants as JSON>
'use strict'
const assert = require('node:assert/strict')
const fs     = require('node:fs')
const vm     = require('node:vm')

const [script_path, constants_json] = process.argv.slice(2)
const C      = JSON.parse(constants_json)
const PREFIX = C.DOM_ATTRIBUTE_PREFIX

// --- the fake browser -------------------------------------------------------

const all_elements = []

// Only the selector forms that live_page.js uses: [attr], tag, tag[attr], tag:not([type="x"]), and a list of them.
function matches_one(el, selector) {
	let m
	if ((m = selector.match(/^\[([^\]=]+)\]$/))) return el.hasAttribute(m[1])
	if ((m = selector.match(/^([a-z]+)\[([^\]=]+)\]$/))) return el.tagName === m[1].toUpperCase() && el.hasAttribute(m[2])
	if ((m = selector.match(/^([a-z]+):not\(\[type="([a-z]+)"\]\)$/))) return el.tagName === m[1].toUpperCase() && el.type !== m[2]
	if (/^[a-z]+$/.test(selector)) return el.tagName === selector.toUpperCase()
	throw new Error(`the fake browser does not know the selector ${selector}`)
}

class Fake_Element {
	constructor(tag, attributes = {}, properties = {}, parent = null) {
		this.tagName    = tag.toUpperCase()
		this.attributes = { ...attributes }
		this.parent     = parent
		Object.assign(this, properties)
		all_elements.push(this)
	}
	getAttribute(name) { return name in this.attributes ? this.attributes[name] : null }
	hasAttribute(name) { return name in this.attributes }
	matches(selector) { return selector.split(',').some(part => matches_one(this, part.trim())) }
	closest(selector) {
		for (let el = this; el; el = el.parent) if (el.matches(selector)) return el
		return null
	}
}

function element(tag, attributes = {}, properties = {}, parent = null) {
	const prefixed = {}
	for (const [name, value] of Object.entries(attributes)) prefixed[name.startsWith('id') ? name : `${PREFIX}-${name}`] = value
	return new Fake_Element(tag, prefixed, properties, parent)
}

const listeners = []
const document  = {
	cookie: `${C.DOM_BROWSER_VIEW_SIZE}=1x1`,
	title: 'old title',
	body: new Fake_Element('body'),
	addEventListener(name, listener, capture) { listeners.push({ name, listener, capture: capture === true }) },
	querySelectorAll(selector) { return all_elements.filter(el => el.matches(selector)) },
	getElementById(id) { return all_elements.find(el => el.attributes.id === id) || null },
}

let reloads = 0
const location = { pathname: '/tasks', search: '?sort=new', reload() { reloads++ } }

// fetch waits until a test calls reply(), so a test decides the order of the replies.
const requests = []
function fetch(url, options) {
	return new Promise(resolve => requests.push({ url, body: JSON.parse(options.body), resolve }))
}
function reply(request, html, headers = {}) {
	request.resolve({ ok: true, status: 200, headers: { get: name => headers[name] ?? null }, text: async () => html })
}

class DOMParser {
	parseFromString(html) {
		return {
			title: (html.match(/<title>(.*?)<\/title>/) || [])[1] || '',
			body: { html },
			getElementById: id => html.includes(`id="${id}"`) ? { fresh_id: id } : null,
		}
	}
}

const morphs  = []
let   on_morph = null // a test can do something during a morph, as Idiomorph's focus restore does
const Idiomorph = { morph(target, content, options) { morphs.push({ target, content, options }); if (on_morph) on_morph() } }

// A clock that only the test moves.
let now    = 0
let timers = []
function setTimeout(callback, ms) { const id = timers.length + 1; timers.push({ id, at: now + ms, callback }); return id }
function clearTimeout(id) { timers = timers.filter(t => t.id !== id) }
function advance(ms) {
	now += ms
	const due = timers.filter(t => t.at <= now)
	timers    = timers.filter(t => t.at > now)
	due.forEach(t => t.callback())
}

const flush = () => new Promise(resolve => setImmediate(resolve))

function dispatch(name, target, extra = {}) {
	const event = { target, prevented: false, preventDefault() { this.prevented = true }, stopPropagation() {}, ...extra }
	listeners.filter(l => l.name === name).forEach(l => l.listener(event))
	return event
}

const context = vm.createContext({
	window: { innerWidth: 1, innerHeight: 1 }, document, location, fetch, DOMParser, Idiomorph, Element: Fake_Element,
	localStorage: { getItem: () => 'json' }, TextEncoder, DataView, Uint8Array, setTimeout, clearTimeout, WeakMap, console,
})
vm.runInContext(fs.readFileSync(script_path, 'utf8'), context)

// --- the checks -------------------------------------------------------------

const checks = []
const check  = (name, body) => checks.push({ name, body })
const event_url = token => `${C.DOM_EVENT_URL}/${token}`

check('it listens for each event, and catches focus and blur on the way down', async () => {
	const names = listeners.map(l => l.name)
	for (const name of C.LIVE_PAGE_EVENTS) assert.ok(names.includes(name), `no listener for ${name}`)
	for (const name of ['focus', 'blur']) assert.ok(listeners.find(l => l.name === name).capture, `${name} is not caught on the way down`)
})

check('a click sends the token, the path, the query and every on-server-read value, and no own value', async () => {
	const note   = element('textarea', { 'on-server-read': 'r-note' }, { value: 'buy milk' })
	const button = element('button', { onclick: 'c-save' })
	const label  = new Fake_Element('span', {}, {}, button)
	const event  = dispatch('click', label)

	assert.ok(event.prevented)
	const request = requests.pop()
	assert.equal(request.url, event_url('c-save'))
	assert.deepEqual(request.body, { inputs: { 'r-note': 'buy milk' }, path: '/tasks', query: 'sort=new' })
	all_elements.splice(all_elements.indexOf(note), 1)
})

check('a click on a control inside an element with onclick belongs to the control', async () => {
	const row   = element('div', { onclick: 'c-row' })
	const field = new Fake_Element('input', {}, { type: 'text' }, row)
	const event = dispatch('click', field)
	assert.equal(requests.length, 0)
	assert.equal(event.prevented, false)
})

check('typing sends one event, 250 ms after the last key, with the last text', async () => {
	const box = element('input', { oninput: 'i-search' }, { type: 'text', value: '' })
	for (const text of ['a', 'ab', 'abc']) {
		box.value = text
		dispatch('input', box)
		advance(100)
	}
	assert.equal(requests.length, 0, 'sent before the wait ended')
	advance(149)
	assert.equal(requests.length, 0, 'sent 1 ms early')
	advance(1)
	assert.equal(requests.length, 1)
	const request = requests.pop()
	assert.equal(request.url, event_url('i-search'))
	assert.equal(request.body.inputs['i-search'], 'abc')
})

check('two boxes wait on their own', async () => {
	const first  = element('input', { oninput: 'i-first' }, { type: 'text', value: 'x' })
	const second = element('input', { oninput: 'i-second' }, { type: 'text', value: 'y' })
	dispatch('input', first)
	dispatch('input', second)
	advance(250)
	assert.deepEqual(requests.map(r => r.url).sort(), [event_url('i-first'), event_url('i-second')])
	requests.length = 0
})

check('change sends a Bool for a checkbox and an Array for a multiple select', async () => {
	const box = element('input', { onchange: 'ch-done' }, { type: 'checkbox', checked: false })
	dispatch('change', box)
	assert.strictEqual(requests.pop().body.inputs['ch-done'], false)

	const select = element('select', { onchange: 'ch-tags' }, { multiple: true, selectedOptions: [{ value: 'a' }, { value: 'c' }] })
	dispatch('change', select)
	assert.deepEqual(requests.pop().body.inputs['ch-tags'], ['a', 'c'])
})

check('keydown and keyup send the key', async () => {
	const box = element('input', { onkeydown: 'k-down', onkeyup: 'k-up' }, { type: 'text', value: '' })
	dispatch('keydown', box, { key: 'Enter' })
	dispatch('keyup', box, { key: 'ArrowUp' })
	assert.deepEqual(requests.map(r => [r.url, r.body.inputs[r.url.split('/').pop()]]), [[event_url('k-down'), 'Enter'], [event_url('k-up'), 'ArrowUp']])
	requests.length = 0
})

check('submit stops the page load and sends no own value', async () => {
	const form  = element('form', { onsubmit: 's-login' })
	const event = dispatch('submit', new Fake_Element('button', {}, {}, form))
	assert.ok(event.prevented)
	const request = requests.pop()
	assert.equal(request.url, event_url('s-login'))
	assert.equal('s-login' in request.body.inputs, false)
})

check('a form without onsubmit loads as usual', async () => {
	const event = dispatch('submit', new Fake_Element('form'))
	assert.equal(event.prevented, false)
	assert.equal(requests.length, 0)
})

check('focus and blur count only on the element itself, not on a field inside it', async () => {
	const panel = element('div', { onfocus: 'f-panel' })
	dispatch('focus', new Fake_Element('input', {}, { type: 'text', value: '' }, panel))
	assert.equal(requests.length, 0)

	const box = element('input', { onblur: 'b-name' }, { type: 'text', value: 'Ada' })
	dispatch('blur', box)
	assert.equal(requests.pop().body.inputs['b-name'], 'Ada')
})

check('a reply that names an element replaces that element', async () => {
	const target = element('div', { id: 'box' })
	dispatch('click', element('button', { onclick: 'c-box' }))
	reply(requests.pop(), '<div id="box">new</div>', { [C.DOM_TARGET_ID_HEADER]: 'box' })
	await flush()
	const morph = morphs.at(-1)
	assert.equal(morph.target, target)
	assert.equal(morph.content, '<div id="box">new</div>')
	assert.equal(morph.options.ignoreActiveValue, true)
})

check('a reply that names an element that is not on the page loads the page again', async () => {
	const before = reloads
	dispatch('click', element('button', { onclick: 'c-gone' }))
	reply(requests.pop(), '<p>x</p>', { [C.DOM_TARGET_ID_HEADER]: 'not-here' })
	await flush()
	assert.equal(reloads, before + 1)
})

check('replacement_target_id takes that element from the new page', async () => {
	const results = element('ul', { id: 'results' })
	dispatch('click', element('button', { onclick: 'c-filter', 'replacement-target-id': 'results' }))
	reply(requests.pop(), '<html><body><ul id="results"><li>a</li></ul></body></html>')
	await flush()
	const morph = morphs.at(-1)
	assert.equal(morph.target, results)
	assert.deepEqual(morph.content, { fresh_id: 'results' })
})

check('any other reply replaces the body and the title', async () => {
	dispatch('click', element('button', { onclick: 'c-page' }))
	reply(requests.pop(), '<html><head><title>New</title></head><body>page</body></html>')
	await flush()
	assert.equal(morphs.at(-1).target, document.body)
	assert.equal(document.title, 'New')
})

check('a reply that comes after the reply to a newer event is dropped', async () => {
	dispatch('click', element('button', { onclick: 'c-old' }))
	dispatch('click', element('button', { onclick: 'c-new' }))
	const [older, newer] = requests.splice(0)
	const before         = morphs.length

	reply(newer, '<body>newer</body>')
	await flush()
	reply(older, '<body>older</body>')
	await flush()

	assert.equal(morphs.length, before + 1)
	assert.deepEqual(morphs.at(-1).content, { html: '<body>newer</body>' })
})

check('a focus that a morph causes sends nothing', async () => {
	const box = element('input', { onfocus: 'f-box' }, { type: 'text', value: '' })
	on_morph  = () => dispatch('focus', box)
	dispatch('click', element('button', { onclick: 'c-morph' }))
	reply(requests.pop(), '<body>x</body>')
	await flush()
	on_morph = null
	assert.equal(requests.length, 0)

	dispatch('focus', box)
	assert.equal(requests.length, 1, 'a real focus after the morph should still send')
	requests.length = 0
})

;(async () => {
	let failed = 0
	for (const { name, body } of checks) {
		try {
			await body()
			console.log(`ok   ${name}`)
		} catch (error) {
			failed++
			console.log(`FAIL ${name}\n     ${error.message.split('\n').join('\n     ')}`)
		}
	}
	console.log(`${checks.length} checks, ${failed} failed`)
	process.exit(failed ? 1 : 0)
})()
