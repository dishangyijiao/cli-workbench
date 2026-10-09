import { expect, mock, test } from 'claude-code/testing'
import type { Engine, MockClock } from 'claude-code/testing'
import type { On } from 'claude-code'

const HOME = '/u/me'
const POLL_MS = 60_000

type Row = { id: string; kind?: string; state?: string; name?: string; cwd?: string; sessionId?: string }
type Ran = { exitCode: number; stdout?: string }

type World = {
  rows: () => Row[] | string
  claude?: () => Ran
  transcripts?: Record<string, string>
  tailFails?: boolean
  sent?: () => boolean
  store?: Record<string, unknown>
}

const bg = (id: string, state: string, name = `job-${id}`): Row => ({
  id,
  kind: 'background',
  state,
  name,
  cwd: '/work/proj',
  sessionId: `${id}-full`,
})

const limitLine = (text: string) => JSON.stringify({ type: 'assistant', isApiErrorMessage: true, message: { content: [{ type: 'text', text }] } })

// Stands in for the engine: the environment, the store, the clock, `claude agents --json`, `tail` and the notification.
const world = (on: On, w: World) => {
  const seen = { runs: [] as (readonly string[])[], notes: [] as { text: string; title?: string }[] }
  mock.env(on, { HOME })
  mock.store(on, w.store ?? {})
  const clock: MockClock = mock.clock(on)
  on('process.run', (_$, e) => {
    seen.runs.push(e.argv)
    let r: Ran = { exitCode: 0 }
    let stdout = ''
    if (e.argv[0] === 'claude') {
      r = w.claude?.() ?? { exitCode: 0 }
      const rows = w.rows()
      stdout = r.stdout ?? (typeof rows === 'string' ? rows : JSON.stringify(rows))
    } else if (e.argv[0] === 'tail') {
      if (w.tailFails) return { value: { exitCode: 1, stdout: '', stderr: 'no such file', isStdoutTruncated: false, isStderrTruncated: false } }
      stdout = w.transcripts?.[e.argv[e.argv.length - 1]] ?? ''
    }
    return { value: { exitCode: r.exitCode, stdout, stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
  })
  on('ui.notify', (_$, e) => {
    seen.notes.push({ text: e.text, title: e.title })
    return { value: (w.sent?.() ?? true) ? { isSent: true as const, channel: 'ghostty' as const } : { isSent: false as const, reason: 'no-surface' as const } }
  })
  on('session.start', (_$, e) => ({ cwd: e.cwd }))
  return { ...seen, clock }
}

const start = async ($: Engine, clock: MockClock) => {
  await $.session.start({ cwd: '/work/proj', surface: 'terminal', isInteractive: true } as never)
  await clock.settle()
}

test('a blocked background session is announced once, by name, and not again on the next polls', async ($, on) => {
  const seen = world(on, { rows: () => [bg('a1', 'blocked', 'backend-fix')] })

  await start($, seen.clock)
  await seen.clock.advance(POLL_MS)
  await seen.clock.advance(POLL_MS)

  expect(seen.notes.map(n => n.text)).toEqual(['backend-fix is blocked'])
})

test('needs_input and waiting are announced too, each once', async ($, on) => {
  const seen = world(on, { rows: () => [bg('a1', 'needs_input', 'one'), bg('b2', 'waiting', 'two')] })

  await start($, seen.clock)
  await seen.clock.advance(POLL_MS)

  expect(seen.notes.map(n => n.text).sort()).toEqual(['one needs your input', 'two is waiting for you'])
})

test('working sessions, idle ones and interactive ones are never announced', async ($, on) => {
  const seen = world(on, {
    rows: () => [bg('a1', 'working'), bg('b2', 'idle'), { id: 'c3', kind: 'interactive', state: 'blocked', name: 'mine' }],
  })

  await start($, seen.clock)
  await seen.clock.advance(POLL_MS)

  expect(seen.notes).toEqual([])
})

test('a session that is active again and blocks again is announced again', async ($, on) => {
  let state = 'blocked'
  const seen = world(on, { rows: () => [bg('a1', state, 'job')] })

  await start($, seen.clock)
  state = 'working'
  await seen.clock.advance(POLL_MS)
  state = 'blocked'
  await seen.clock.advance(POLL_MS)

  expect(seen.notes.map(n => n.text)).toEqual(['job is blocked', 'job is blocked'])
})

test('a change from one waiting state to another is a new state and is announced', async ($, on) => {
  let state = 'blocked'
  const seen = world(on, { rows: () => [bg('a1', state, 'job')] })

  await start($, seen.clock)
  state = 'needs_input'
  await seen.clock.advance(POLL_MS)

  expect(seen.notes.map(n => n.text)).toEqual(['job is blocked', 'job needs your input'])
})

test('a usage limit hit adds the reset time read from the end of the transcript', async ($, on) => {
  const path = `${HOME}/.claude/projects/-work-proj/a1-full.jsonl`
  const seen = world(on, {
    rows: () => [bg('a1', 'blocked', 'job')],
    transcripts: { [path]: limitLine("You've hit your session limit · resets 8:20pm (Asia/Tokyo)") },
  })

  await start($, seen.clock)

  expect(seen.notes.map(n => n.text)).toEqual(['job hit the session limit, resets 8:20pm (Asia/Tokyo)'])
  const tail = seen.runs.find(argv => argv[0] === 'tail')
  expect(tail?.[tail.length - 1]).toBe(path)
})

test('a transcript that cannot be read still gets the plain notification', async ($, on) => {
  const seen = world(on, { rows: () => [bg('a1', 'blocked', 'job')], tailFails: true })

  await start($, seen.clock)

  expect(seen.notes.map(n => n.text)).toEqual(['job is blocked'])
})

test('a failing `claude agents`, bad JSON or a non-list leaves everything quiet', async ($, on) => {
  let mode = 0
  const seen = world(on, {
    rows: () => [bg('a1', 'blocked')],
    claude: () => (mode === 0 ? { exitCode: 1, stdout: JSON.stringify([bg('a1', 'blocked')]) } : mode === 1 ? { exitCode: 0, stdout: 'oops' } : { exitCode: 0, stdout: '{"a":1}' }),
  })

  await start($, seen.clock)
  mode = 1
  await seen.clock.advance(POLL_MS)
  mode = 2
  await seen.clock.advance(POLL_MS)

  expect(seen.notes).toEqual([])
})

test('a failure between two good polls forgets nothing: the session is not announced twice', async ($, on) => {
  let fail = false
  const seen = world(on, { rows: () => [bg('a1', 'blocked', 'job')], claude: () => (fail ? { exitCode: 1, stdout: '' } : { exitCode: 0 }) })

  await start($, seen.clock)
  fail = true
  await seen.clock.advance(POLL_MS)
  fail = false
  await seen.clock.advance(POLL_MS)

  expect(seen.notes).toHaveLength(1)
})

test('with nobody to tell, nothing is remembered: the next poll tries again', async ($, on) => {
  let attached = false
  const seen = world(on, { rows: () => [bg('a1', 'blocked', 'job')], sent: () => attached })

  await start($, seen.clock)
  attached = true
  await seen.clock.advance(POLL_MS)
  await seen.clock.advance(POLL_MS)

  expect(seen.notes).toHaveLength(2)
})

test('a session another window already announced is not announced again', async ($, on) => {
  const seen = world(on, { rows: () => [bg('a1', 'blocked', 'job')], store: { notified: { a1: 'blocked' } } })

  await start($, seen.clock)

  expect(seen.notes).toEqual([])
})

test('a session gone from the list is forgotten, so a new one with the same id is announced', async ($, on) => {
  let rows: Row[] = [bg('a1', 'blocked', 'job')]
  const seen = world(on, { rows: () => rows })

  await start($, seen.clock)
  rows = []
  await seen.clock.advance(POLL_MS)
  rows = [bg('a1', 'blocked', 'job')]
  await seen.clock.advance(POLL_MS)

  expect(seen.notes).toHaveLength(2)
})

test('the poll runs `claude agents --json` as an argv with a time limit, and a second session.start does not start a second timer', async ($, on) => {
  const seen = world(on, { rows: () => [] })

  await start($, seen.clock)
  await start($, seen.clock)
  const before = seen.runs.filter(a => a[0] === 'claude').length
  await seen.clock.advance(POLL_MS)

  expect(seen.runs.find(a => a[0] === 'claude')).toEqual(['claude', 'agents', '--json'])
  expect(seen.runs.filter(a => a[0] === 'claude').length - before).toBe(1)
})
