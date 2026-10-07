import type { On } from 'claude-code'
import { expect, test } from 'claude-code/testing'

const done = { stderr: '', isStdoutTruncated: false, isStderrTruncated: false }

// What the engine does beneath the mod: every classic event ends here with no opinion of its own.
const engine = (on: On) => {
  on('classic.UserPromptSubmit', () => ({}))
  on('classic.PostToolUse', () => ({}))
  on('classic.PermissionRequest', () => ({}))
  on('classic.Notification', () => ({}))
  on('classic.Stop', () => ({}))
  on('classic.SessionStart', () => ({}))
  on('classic.SessionEnd', () => ({}))
}

// Stands in for the host's processes and remembers every command the mod ran.
const recorder = (on: On, exitCode = 0) => {
  engine(on)
  const runs: { argv: readonly string[]; stdin?: string }[] = []
  on('process.run', ($, e) => {
    runs.push({ argv: e.argv, stdin: e.init?.stdin })
    return { value: { exitCode, stdout: '', ...done } }
  })
  return runs
}

const stateOf = (run: { argv: readonly string[] }) => run.argv[run.argv.length - 1]

test('a prompt records working, with the session id on stdin', async ($, on) => {
  const runs = recorder(on)

  await $.classic.UserPromptSubmit({ session_id: 's-1', prompt: 'hi' })

  expect(runs).toHaveLength(1)
  expect(stateOf(runs[0]!)).toBe('working')
  expect(JSON.parse(runs[0]!.stdin ?? '{}')).toEqual({ session_id: 's-1' })
})

test('the script is the deployed one, run without a shell string built from event text', async ($, on) => {
  const runs = recorder(on)

  await $.classic.Stop({ stop_hook_active: false })

  expect(runs[0]!.argv.slice(0, 2)).toEqual(['sh', '-c'])
  expect(runs[0]!.argv[2]).toContain('$HOME/.tmux/scripts/agent-state.sh')
  expect(stateOf(runs[0]!)).toBe('idle')
})

test('every mapped event runs the script with its state', async ($, on) => {
  const runs = recorder(on)

  await $.classic.SessionStart({ source: 'startup' })
  await $.classic.PermissionRequest({ tool_name: 'Bash', tool_input: {} })
  await $.classic.PostToolUse({ tool_name: 'Bash', tool_input: {}, tool_response: {}, tool_use_id: 't' })
  await $.classic.SessionEnd({ reason: 'other' })

  expect(runs.map(stateOf)).toEqual(['idle', 'waiting', 'resume', 'end'])
})

test('a notification that is only a reminder records nothing', async ($, on) => {
  const runs = recorder(on)

  await $.classic.Notification({ message: 'Claude is waiting for your input', notification_type: 'idle_prompt' })
  expect(runs).toHaveLength(0)

  await $.classic.Notification({ message: 'Claude needs your permission', notification_type: 'permission_prompt' })
  expect(runs.map(stateOf)).toEqual(['waiting'])
})

test('a failing script never breaks the hook chain', async ($, on) => {
  recorder(on, 1)

  await expect($.classic.Stop({ stop_hook_active: false })).resolves.toBeDefined()
})

test('a script that cannot start never breaks the hook chain', async ($, on) => {
  engine(on)
  on('process.run', () => {
    throw new Error('spawn failed')
  })

  await expect($.classic.Stop({ stop_hook_active: false })).resolves.toBeDefined()
})
