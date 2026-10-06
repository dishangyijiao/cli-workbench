import { expect, test } from 'claude-code/testing'

import { driftMessage } from './message'

const row = (path: string) => ({ status: ' M', path })

test('says "differs" for one file', () => {
  expect(driftMessage([row('.zshrc')])).toBe(
    'chezmoi: 1 deployed file differs from the source (.zshrc). Run chezmoi diff.',
  )
})

test('says "differ" for several files', () => {
  expect(driftMessage([row('.zshrc'), row('.tmux.conf')])).toBe(
    'chezmoi: 2 deployed files differ from the source (.zshrc, .tmux.conf). Run chezmoi diff.',
  )
})

test('names three files and counts the rest', () => {
  const rows = ['a', 'b', 'c', 'd', 'e'].map(row)

  expect(driftMessage(rows)).toBe(
    'chezmoi: 5 deployed files differ from the source (a, b, c and 2 more). Run chezmoi diff.',
  )
})

test('has nothing to say when nothing differs', () => {
  expect(driftMessage([])).toBeNull()
})
