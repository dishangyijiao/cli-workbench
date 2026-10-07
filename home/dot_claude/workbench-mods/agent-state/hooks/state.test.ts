import { expect, test } from 'claude-code/testing'

import { notificationWait, toolKey } from './state'

test('only the notifications that ask you something are waits', () => {
  expect(notificationWait('elicitation_dialog')).toBe('notify:elicitation_dialog')
  expect(notificationWait('elicitation_url_dialog')).toBe('notify:elicitation_url_dialog')
  // A permission prompt is already a PermissionRequest; the others only remind or inform.
  expect(notificationWait('permission_prompt')).toBeNull()
  expect(notificationWait('idle_prompt')).toBeNull()
  expect(notificationWait('auth_success')).toBeNull()
  expect(notificationWait(undefined)).toBeNull()
})

test('a tool call has the same key when it is asked and when it is answered', () => {
  expect(toolKey('Bash', { command: 'ls', description: 'x' })).toBe(toolKey('Bash', { command: 'ls', description: 'x' }))
})

test('different calls have different keys', () => {
  expect(toolKey('Bash', { command: 'ls' })).not.toBe(toolKey('Bash', { command: 'pwd' }))
  expect(toolKey('Bash', { command: 'ls' })).not.toBe(toolKey('Read', { command: 'ls' }))
  expect(toolKey('Bash', undefined)).not.toBe(toolKey('Bash', {}))
})

test('a key is short and made of plain characters', () => {
  expect(toolKey('mcp__a__b', { text: 'x'.repeat(100000) })).toMatch(/^tool:[A-Za-z0-9_]{1,40}:[0-9a-f]{8}$/)
})
