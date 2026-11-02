import type { EngineInterface as Engine, Register } from 'claude-code'

import { isWaiting, projectDir, resetFrom, wording } from './limit'

// A session that stops on a usage limit has stopped: no hook fires in it. So this mod sits in the owner's own session and
// asks `claude agents --json` now and then. It runs from a timer, outside any hook chain, so it never holds up a turn.
const POLL_MS = 60_000
const LIST_BUDGET_MS = 10_000
const TAIL_BUDGET_MS = 3_000
const TAIL_LINES = '20'

type Row = { id?: unknown; kind?: unknown; state?: unknown; name?: unknown; cwd?: unknown; sessionId?: unknown }
type Notified = Record<string, string>

// The list of background sessions, or undefined when `claude` fails or answers something else: then nothing changes.
const background = async ($: Engine): Promise<Row[] | undefined> => {
  try {
    const out = await $.process.run(['claude', 'agents', '--json'], { timeoutMs: LIST_BUDGET_MS })
    if (out.exitCode !== 0) return undefined
    const rows: unknown = JSON.parse(out.stdout)
    if (!Array.isArray(rows)) return undefined
    return rows.filter((r): r is Row => r !== null && typeof r === 'object' && r.kind === 'background')
  } catch {
    return undefined
  }
}

// The end of the session's transcript, or '' when it cannot be read: the notification then lacks the reset time, no more.
const transcriptTail = async ($: Engine, row: Row): Promise<string> => {
  try {
    if (typeof row.cwd !== 'string' || typeof row.sessionId !== 'string') return ''
    const root = (await $.env.get('CLAUDE_CONFIG_DIR')) ?? `${await $.env.get('HOME')}/.claude`
    const path = `${root}/projects/${projectDir(row.cwd)}/${row.sessionId}.jsonl`
    const out = await $.process.run(['tail', '-n', TAIL_LINES, path], { timeoutMs: TAIL_BUDGET_MS })
    return out.exitCode === 0 ? out.stdout : ''
  } catch {
    return ''
  }
}

const readNotified = async ($: Engine): Promise<Notified> => (((await $.store.get('notified')) ?? {}) as Notified)

// What was announced: session id -> the state it was announced in. It lives in the store, which every window shares, so
// two windows do not both announce. A session that is no longer waiting, or gone, drops out, so its next stop is announced.
//
// The store has no compare-and-set, so two windows polling in the same instant could still both announce. To make that
// instant as short as it can be, a new stop is written to the store first, before the slow work (reading the transcript,
// sending the notification), and given back if nobody could be told.
const poll = async ($: Engine): Promise<void> => {
  try {
    const rows = await background($)
    if (rows === undefined) return
    const before = await readNotified($)
    const claimed: Notified = {}
    const fresh: { id: string; state: string; row: Row }[] = []
    for (const row of rows) {
      if (typeof row.id !== 'string') continue
      // A row we cannot read the state of says nothing: keep what we knew about it, so it is not announced again later.
      if (typeof row.state !== 'string') {
        if (before[row.id] !== undefined) claimed[row.id] = before[row.id]
        continue
      }
      if (!isWaiting(row.state)) continue
      if (before[row.id] === row.state) claimed[row.id] = row.state
      else fresh.push({ id: row.id, state: row.state, row })
    }
    for (const f of fresh) claimed[f.id] = f.state
    if (JSON.stringify(before) !== JSON.stringify(claimed)) await $.store.set('notified', claimed)

    for (const f of fresh) {
      const name = typeof f.row.name === 'string' && f.row.name !== '' ? f.row.name : f.id
      const text = wording(name, f.state, resetFrom(await transcriptTail($, f.row)))
      if ((await $.ui.notify(text, { title: 'Claude Code' })).isSent) continue
      // Nobody to tell (no terminal, notifications off): give the claim back, so the next poll tries again. Read the store
      // again first: another window may have changed it meanwhile.
      const now = await readNotified($)
      if (now[f.id] === f.state) {
        delete now[f.id]
        await $.store.set('notified', now)
      }
    }
  } catch {
    // A failed poll costs one minute: the next one looks again.
  }
}

export const register: Register = on => {
  let timer: { cancel: () => void } | undefined
  on('session.start', async ($, e, next) => {
    // Hot reload and resumed sessions fire it again; one timer is enough.
    if (timer === undefined) {
      timer = $.clock.every(POLL_MS, () => void poll($))
      $.clock.after(0, () => void poll($))
    }
    return next(e)
  })
}
