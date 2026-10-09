import { expect, test } from 'claude-code/testing'

import { isWaiting, projectDir, resetFrom, wording } from './limit'

const line = (type: string, text: string, extra: Record<string, unknown> = {}) =>
  JSON.stringify({ type, message: { role: type, content: [{ type: 'text', text }] }, ...extra })

test('only blocked, needs_input and waiting count as waiting for the owner', () => {
  for (const s of ['blocked', 'needs_input', 'waiting']) expect(isWaiting(s)).toBe(true)
  for (const s of ['working', 'idle', 'completed', 'unknown', undefined]) expect(isWaiting(s)).toBe(false)
})

test('the transcript folder is the working directory with every non-alphanumeric character as a dash', () => {
  expect(projectDir('/srv/dev/projects/new-magnet')).toBe('-srv-dev-projects-new-magnet')
  expect(projectDir('/work/my.proj_x')).toBe('-work-my-proj-x')
})

test('the reset time is read from a session limit line', () => {
  const tail = [line('user', 'go'), line('assistant', "You've hit your session limit · resets 8:20pm (Asia/Tokyo)", { isApiErrorMessage: true })].join('\n')
  expect(resetFrom(tail)).toEqual({ kind: 'session', resets: '8:20pm (Asia/Tokyo)' })
})

test('a weekly limit is named as such', () => {
  const tail = line('assistant', "You've hit your weekly limit · resets Oct 12, 9am (Asia/Tokyo)")
  expect(resetFrom(tail)).toEqual({ kind: 'weekly', resets: 'Oct 12, 9am (Asia/Tokyo)' })
})

test('an error suffix after the reset time is dropped', () => {
  const tail = line('assistant', "You've hit your session limit · resets 4:50pm (Asia/Tokyo) (error type rate_limit, HTTP 429)")
  expect(resetFrom(tail)?.resets).toBe('4:50pm (Asia/Tokyo)')
})

test('only the last assistant text counts: an older limit line is stale', () => {
  const tail = [line('assistant', "You've hit your session limit · resets 4:50pm (Asia/Tokyo)"), line('assistant', 'Back at work, running the tests.')].join('\n')
  expect(resetFrom(tail)).toBeUndefined()
})

test('a limit line without a reset time still names the kind', () => {
  expect(resetFrom(line('assistant', "You've hit your session limit"))).toEqual({ kind: 'session', resets: undefined })
})

test('lines that are not JSON, a cut first line and non-text blocks are skipped', () => {
  const tail = ['{"type":"assistant","mess', 'not json', JSON.stringify({ type: 'assistant', message: { content: [{ type: 'tool_use', name: 'Bash' }] } })].join('\n')
  expect(resetFrom(tail)).toBeUndefined()
  expect(resetFrom('')).toBeUndefined()
})

test('the wording names the session and the reason', () => {
  expect(wording('backend-fix', 'blocked', undefined)).toBe('backend-fix is blocked')
  expect(wording('backend-fix', 'needs_input', undefined)).toBe('backend-fix needs your input')
  expect(wording('backend-fix', 'waiting', undefined)).toBe('backend-fix is waiting for you')
  expect(wording('backend-fix', 'blocked', { kind: 'session', resets: '8:20pm (Asia/Tokyo)' })).toBe(
    'backend-fix hit the session limit, resets 8:20pm (Asia/Tokyo)',
  )
  expect(wording('backend-fix', 'blocked', { kind: 'weekly', resets: undefined })).toBe('backend-fix hit the weekly limit')
})
