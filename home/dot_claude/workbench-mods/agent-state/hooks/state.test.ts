import { expect, test } from 'claude-code/testing'

import { asksYou } from './state'

test('the notifications that ask you something', () => {
  expect(asksYou('permission_prompt')).toBe(true)
  expect(asksYou('elicitation_dialog')).toBe(true)
  expect(asksYou('elicitation_url_dialog')).toBe(true)
})

test('reminders and information do not', () => {
  expect(asksYou('idle_prompt')).toBe(false)
  expect(asksYou('auth_success')).toBe(false)
  expect(asksYou(undefined)).toBe(false)
})
