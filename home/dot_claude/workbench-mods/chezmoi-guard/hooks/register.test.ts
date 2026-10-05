import type { On } from 'claude-code'
import { expect, test } from 'claude-code/testing'

const SOURCE = '/src/home/dot_zshrc'

const done = { stderr: '', isStdoutTruncated: false, isStderrTruncated: false }

// Stands in for chezmoi: ~/.zshrc is managed, anything else is not.
const fakeChezmoi = (on: On) =>
  on('process.run', ($, e) => {
    const [, sub, path] = e.argv
    if (sub !== 'source-path') return { value: { exitCode: 0, stdout: '', ...done } }
    return path === '/srv/target/.zshrc'
      ? { value: { exitCode: 0, stdout: `${SOURCE}\n`, ...done } }
      : { value: { exitCode: 1, stdout: '', ...done } }
  })

test('denies an Edit of a deployed file and names the source', async ($, on) => {
  fakeChezmoi(on)

  const out = await $.tool.call({
    tool: 'Edit',
    file_path: '/srv/target/.zshrc',
    old_string: 'a',
    new_string: 'b',
  })

  expect(out.deny).toContain(SOURCE)
})

test('denies a Write of a deployed file', async ($, on) => {
  fakeChezmoi(on)

  const out = await $.tool.call({ tool: 'Write', file_path: '/srv/target/.zshrc', content: 'x' })

  expect(out.deny).toContain('chezmoi')
})

test('lets an unmanaged file through', async ($, on) => {
  fakeChezmoi(on)
  on('tool.call', () => ({ result: 'ok' }))

  const out = await $.tool.call({ tool: 'Write', file_path: '/srv/target/notes.md', content: 'x' })

  expect(out.deny).toBeUndefined()
})
