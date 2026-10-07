import { expect, test } from 'claude-code/testing'

import { stateFor } from './state'

test('a prompt means working, a stop or a start means idle, the end removes the record', () => {
  expect(stateFor('UserPromptSubmit')).toBe('working')
  expect(stateFor('Stop')).toBe('idle')
  expect(stateFor('SessionStart')).toBe('idle')
  expect(stateFor('SessionEnd')).toBe('end')
})

test('a permission request waits for you', () => {
  expect(stateFor('PermissionRequest')).toBe('waiting')
})

test('a finished tool call turns waiting back into working', () => {
  expect(stateFor('PostToolUse')).toBe('resume')
})

test('only the notifications that need an answer mean waiting', () => {
  expect(stateFor('Notification', 'permission_prompt')).toBe('waiting')
  expect(stateFor('Notification', 'elicitation_dialog')).toBe('waiting')
  expect(stateFor('Notification', 'idle_prompt')).toBeNull()
  expect(stateFor('Notification', 'auth_success')).toBeNull()
  expect(stateFor('Notification')).toBeNull()
})

test('other events are not recorded', () => {
  expect(stateFor('PreCompact')).toBeNull()
  expect(stateFor('SubagentStop')).toBeNull()
})
