import type { On } from 'claude-code'
import { expect, test } from 'claude-code/testing'

import { toolKey } from './state'

const done = { stderr: '', isStdoutTruncated: false, isStderrTruncated: false }

// What the engine does beneath the mod: every event ends here with no opinion of its own.
const engine = (on: On) => {
  on('session.id', () => ({ value: 'sess-1' }))
  on('turn.start', (_$, e) => ({ turnId: e.turnId }))
  on('turn.complete', () => ({ text: '' }))
  on('classic.SessionStart', () => ({}))
  on('classic.SessionEnd', () => ({}))
  on('classic.PermissionRequest', () => ({}))
  on('classic.PermissionDenied', () => ({}))
  on('classic.PostToolUse', () => ({}))
  on('classic.PostToolUseFailure', () => ({}))
  on('classic.Notification', () => ({}))
  on('classic.ElicitationResult', () => ({}))
}

type Run = { argv: readonly string[]; stdin: { session_id?: string; ts?: number; key?: string }; timeoutMs?: number }

// Stands in for the host's processes and remembers every command the mod ran.
const recorder = (on: On, exitCode = 0) => {
  engine(on)
  const runs: Run[] = []
  on('process.run', ($, e) => {
    runs.push({ argv: e.argv, stdin: JSON.parse(e.init?.stdin ?? '{}'), timeoutMs: e.init?.timeoutMs })
    return { value: { exitCode, stdout: '', ...done } }
  })
  return runs
}

const action = (run: Run) => run.argv[run.argv.length - 1]
const actions = (runs: Run[]) => runs.map(action)

test('a turn start records begin, with the session id and an event time on stdin', async ($, on) => {
  const runs = recorder(on)

  await $.turn.start({ text: 'hi', turnId: 't1' })

  expect(actions(runs)).toEqual(['begin'])
  expect(runs[0]!.stdin.session_id).toBe('sess-1')
  expect(typeof runs[0]!.stdin.ts).toBe('number')
})

test('the script is the deployed one, run without a shell string built from event text', async ($, on) => {
  const runs = recorder(on)

  await $.turn.start({ text: 'ignore me; rm -rf /', turnId: 't1' })

  expect(runs[0]!.argv.slice(0, 2)).toEqual(['sh', '-c'])
  expect(runs[0]!.argv[2]).toContain('$HOME/.tmux/scripts/agent-state.sh')
  expect(JSON.stringify(runs[0]!.argv)).not.toContain('rm -rf')
})

test('every turn end records idle: an answer, an interrupt, a refusal and an error alike', async ($, on) => {
  const runs = recorder(on)

  for (const reason of ['answer', 'aborted', 'error'] as const) {
    await $.turn.complete({ answer: '', durationMs: 1, isAborted: reason === 'aborted', turnId: 't', reason })
  }

  expect(actions(runs)).toEqual(['idle', 'idle', 'idle'])
})

test('a subagent turn is not the agent being idle', async ($, on) => {
  const runs = recorder(on)

  await $.turn.complete({ answer: '', durationMs: 1, isAborted: false, turnId: 't', reason: 'answer', agentId: 'sub-1' })

  expect(runs).toHaveLength(0)
})

test('event times only go up, even within one millisecond', async ($, on) => {
  const runs = recorder(on)

  await $.turn.start({ text: 'a', turnId: 't1' })
  await $.turn.start({ text: 'b', turnId: 't2' })
  await $.turn.start({ text: 'c', turnId: 't3' })

  const times = runs.map(run => run.stdin.ts!)
  expect(times[1]).toBeGreaterThan(times[0]!)
  expect(times[2]).toBeGreaterThan(times[1]!)
})

test('a fresh session or a resume is idle; a compaction is not a new start', async ($, on) => {
  const runs = recorder(on)

  await $.classic.SessionStart({ source: 'startup' })
  await $.classic.SessionStart({ source: 'resume' })
  await $.classic.SessionStart({ source: 'clear' })
  await $.classic.SessionStart({ source: 'compact' })

  expect(actions(runs)).toEqual(['start', 'start', 'start'])
})

test('a session end records end', async ($, on) => {
  const runs = recorder(on)

  await $.classic.SessionEnd({ reason: 'other' })

  expect(actions(runs)).toEqual(['end'])
})

test('a permission request waits under the key of that tool call', async ($, on) => {
  const runs = recorder(on)

  await $.classic.PermissionRequest({ tool_name: 'Bash', tool_input: { command: 'ls' } })

  expect(actions(runs)).toEqual(['wait'])
  expect(runs[0]!.stdin.key).toBe(toolKey('Bash', { command: 'ls' }))
})

test('that call finishing, failing or being denied answers that wait, and no other', async ($, on) => {
  const runs = recorder(on)
  const input = { command: 'ls' }

  await $.classic.PostToolUse({ tool_name: 'Bash', tool_input: input, tool_response: {}, tool_use_id: 'u1' })
  await $.classic.PostToolUseFailure({ tool_name: 'Bash', tool_input: input, tool_use_id: 'u2', error: 'x' })
  await $.classic.PermissionDenied({ tool_name: 'Bash', tool_input: input, tool_use_id: 'u3', reason: 'no' })

  expect(actions(runs)).toEqual(['unwait', 'unwait', 'unwait'])
  expect(new Set(runs.map(run => run.stdin.key))).toEqual(new Set([toolKey('Bash', input)]))
})

test('a notification that asks a question is a wait; the dialog result answers it', async ($, on) => {
  const runs = recorder(on)

  await $.classic.Notification({ message: 'pick one', notification_type: 'elicitation_url_dialog' })
  await $.classic.ElicitationResult({ mcp_server_name: 's', action: 'accept' })

  expect(actions(runs)).toEqual(['wait', 'unwait-prefix'])
  expect(runs[0]!.stdin.key).toBe('notify:elicitation_url_dialog')
  expect(runs[1]!.stdin.key).toBe('notify:')
})

test('a notification that is only a reminder records nothing', async ($, on) => {
  const runs = recorder(on)

  await $.classic.Notification({ message: 'Claude is waiting for your input', notification_type: 'idle_prompt' })
  await $.classic.Notification({ message: 'Claude needs your permission', notification_type: 'permission_prompt' })

  expect(runs).toHaveLength(0)
})

test('the script gets at most one second', async ($, on) => {
  const runs = recorder(on)

  await $.turn.start({ text: 'hi', turnId: 't1' })

  expect(runs[0]!.timeoutMs).toBeLessThanOrEqual(1000)
})

test('a failing script never breaks the hook chain', async ($, on) => {
  recorder(on, 1)

  await expect($.turn.start({ text: 'hi', turnId: 't1' })).resolves.toBeDefined()
})

test('a script that cannot start never breaks the hook chain', async ($, on) => {
  engine(on)
  on('process.run', () => {
    throw new Error('spawn failed')
  })

  await expect($.turn.start({ text: 'hi', turnId: 't1' })).resolves.toBeDefined()
})
