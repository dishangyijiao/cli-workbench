import type { On, SessionMessage } from 'claude-code'
import { expect, mock, test } from 'claude-code/testing'
import type { Engine, MockClock } from 'claude-code/testing'

const HOME = '/u/me'
const CWD = '/work/proj'
const PANE = 'md-open'

type Ran = { exitCode: number; stderr?: string }

type World = {
  messages: SessionMessage[]
  files: string[]
  env?: Record<string, string>
  run?: (argv: readonly string[], clock: MockClock) => Promise<Ran> | Ran
}

// Stands in for the engine: the conversation, the files on disk, the environment, tmux, the pane and the toasts.
const world = (on: On, w: World) => {
  const seen = { runs: [] as (readonly string[])[], toasts: [] as string[], opened: [] as string[], closed: [] as string[], registered: [] as string[] }
  mock.env(on, { HOME, ...(w.env ?? { TMUX: '/tmp/tmux-1/default,1,0' }) })
  const clock = mock.clock(on)
  on('session.messages', () => ({ value: w.messages }))
  on('session.cwd', () => ({ value: CWD }))
  on('fs.stat', (_$, e) => {
    if (!w.files.includes(e.path)) throw new Error(`ENOENT: ${e.path}`)
    return { value: { kind: 'file' as const, size: 1, mtimeMs: 0, isLink: false } }
  })
  on('process.run', async (_$, e) => {
    seen.runs.push(e.argv)
    const { exitCode, stderr = '' } = (await w.run?.(e.argv, clock)) ?? { exitCode: 0 }
    return { value: { exitCode, stdout: '', stderr, isStdoutTruncated: false, isStderrTruncated: false } }
  })
  on('ui.toast', (_$, e) => {
    seen.toasts.push(e.text)
    return { value: undefined }
  })
  on('ui.open', (_$, e) => {
    seen.opened.push(e.id)
    return { value: { isPlaced: true as const } }
  })
  on('ui.close', (_$, e) => {
    seen.closed.push(e.id)
    return { value: undefined }
  })
  on('command.register', (_$, e) => {
    seen.registered.push(e.name)
    return { value: { command: e.name } }
  })
  return { ...seen, clock }
}

const say = (text: string): SessionMessage => ({ role: 'assistant', text, toolUses: [] })
const ask = (text: string): SessionMessage => ({ role: 'user', text, toolUses: [] })
const used = (tool: string, input: Record<string, unknown>): SessionMessage => ({
  role: 'assistant',
  text: '',
  toolUses: [{ tool_use_id: `u-${tool}-${JSON.stringify(input).length}`, tool, input }],
})
const answered = (text: string): SessionMessage => ({
  role: 'user',
  text: '',
  toolUses: [],
  toolResults: [{ tool_use_id: 'r', text, isError: false }],
})

const md = (args = '') =>
  ({ command: 'md', args, origin: { kind: 'composer' }, presentation: { isFullscreen: false, columns: 160 } }) as const

const PANE_PROPS = {
  title: 'Markdown',
  isFocused: true,
  bodyColumns: 120,
  placement: 'inline' as const,
  scroll: { offset: 0, bodyRows: 20 },
  view: {},
}

// The list as the pane shows it: one Button per file, newest first.
const listed = async ($: Engine) => {
  const ui = await $.ui.mount({ plugin: 'md-open', surface: 'terminal', component: 'Pane', requestId: PANE, props: PANE_PROPS })
  const buttons = await ui.findAll({ type: 'Button' })
  return { ui, labels: buttons.map(b => b.props.label) }
}

test('/md is registered as a command when the session starts', async ($, on) => {
  const seen = world(on, { messages: [], files: [] })
  on('session.start', (_$, e) => ({ cwd: e.cwd }))

  await $.session.start({ cwd: CWD, surface: 'terminal', isInteractive: true } as never)

  expect(seen.registered).toEqual(['md'])
})

test('lists the files from tool calls, Bash commands, replies and tool results, newest first, each once', async ($, on) => {
  const files = ['/work/proj/docs/plan.md', '/u/me/notes/a.md', '/tmp/report.md', '/work/proj/README.md', '/srv/b.md']
  const seen = world(on, {
    files,
    messages: [
      ask('please read README.md'),
      used('Read', { file_path: '/work/proj/docs/plan.md' }),
      used('Bash', { command: 'cat ~/notes/a.md | head' }),
      answered('found /srv/b.md'),
      say('The report is in /tmp/report.md.'),
      used('Write', { file_path: '/work/proj/docs/plan.md', content: 'x' }),
    ],
  })

  const out = await $.command.run(md())

  expect(seen.opened).toEqual([PANE])
  expect(out.text).toContain('5')
  const { labels } = await listed($)
  expect(labels).toEqual(['/work/proj/docs/plan.md', '/tmp/report.md', '/srv/b.md', '~/notes/a.md', '/work/proj/README.md'])
})

test('files that do not exist are left out', async ($, on) => {
  world(on, { files: ['/tmp/real.md'], messages: [say('see /tmp/gone.md and /tmp/real.md and docs/missing.md')] })

  await $.command.run(md())

  expect((await listed($)).labels).toEqual(['/tmp/real.md'])
})

test('a path under the home directory is shown with ~', async ($, on) => {
  world(on, { files: ['/u/me/r.md'], messages: [say('wrote /u/me/r.md')] })

  await $.command.run(md())

  expect((await listed($)).labels).toEqual(['~/r.md'])
})

test('the same file spelled three ways is listed once, where it was last mentioned', async ($, on) => {
  world(on, {
    files: ['/work/proj/a.md', '/tmp/b.md'],
    messages: [say('./a.md'), say('/tmp/b.md'), say('docs/../a.md')],
  })

  await $.command.run(md())

  expect((await listed($)).labels).toEqual(['/work/proj/a.md', '/tmp/b.md'])
})

test('nothing mentioned: one line, and no pane', async ($, on) => {
  const seen = world(on, { files: ['/tmp/x.md'], messages: [say('nothing to read'), say('/tmp/missing.md')] })

  const out = await $.command.run(md())

  expect(out.text).toBe('This conversation mentions no Markdown file that exists.')
  expect(seen.opened).toEqual([])
})

test('choosing a file opens it read-only in Neovim in a tmux popup, as an argv, and closes the pane', async ($, on) => {
  const path = '/tmp/a b; rm -rf ~ $(x).md'
  const seen = world(on, { files: [path], messages: [used('Write', { file_path: path, content: '' })] })

  await $.command.run(md())
  const { ui } = await listed($)
  await ui.press({ key: path })

  expect(seen.runs).toEqual([['tmux', 'display-popup', '-E', '-w', '90%', '-h', '90%', 'nvim', '-R', '--', path]])
  expect(seen.closed).toEqual([PANE])
  expect(seen.toasts).toEqual([])
})

test('the first nine files can be chosen with a digit', async ($, on) => {
  const files = Array.from({ length: 11 }, (_, i) => `/tmp/f${i}.md`)
  world(on, { files, messages: files.map(f => say(f)) })

  await $.command.run(md())
  const { ui } = await listed($)
  const buttons = await ui.findAll({ type: 'Button' })

  expect(buttons.map(b => b.props.hotkey)).toEqual(['1', '2', '3', '4', '5', '6', '7', '8', '9', undefined, undefined])
})

test('outside tmux nothing is run: a toast shows the path instead', async ($, on) => {
  const seen = world(on, { env: {}, files: ['/u/me/r.md'], messages: [say('/u/me/r.md')] })

  await $.command.run(md())
  await (await listed($)).ui.press({ key: '/u/me/r.md' })

  expect(seen.runs).toEqual([])
  expect(seen.toasts).toHaveLength(1)
  expect(seen.toasts[0]).toContain('~/r.md')
})

test('when tmux reports an error, a toast shows the path', async ($, on) => {
  const seen = world(on, {
    files: ['/tmp/r.md'],
    messages: [say('/tmp/r.md')],
    run: () => ({ exitCode: 1, stderr: 'no current client' }),
  })

  await $.command.run(md())
  await (await listed($)).ui.press({ key: '/tmp/r.md' })

  expect(seen.toasts).toHaveLength(1)
  expect(seen.toasts[0]).toContain('/tmp/r.md')
})

test('when tmux cannot start, a toast shows the path', async ($, on) => {
  const seen = world(on, {
    files: ['/tmp/r.md'],
    messages: [say('/tmp/r.md')],
    run: () => {
      throw new Error('spawn tmux ENOENT')
    },
  })

  await $.command.run(md())
  await (await listed($)).ui.press({ key: '/tmp/r.md' })

  expect(seen.toasts).toHaveLength(1)
  expect(seen.toasts[0]).toContain('/tmp/r.md')
})

test('Neovim quitting with an error code is not a tmux failure: no toast', async ($, on) => {
  const seen = world(on, { files: ['/tmp/r.md'], messages: [say('/tmp/r.md')], run: () => ({ exitCode: 1 }) })

  await $.command.run(md())
  await (await listed($)).ui.press({ key: '/tmp/r.md' })

  expect(seen.toasts).toEqual([])
})

test('a popup still open when the wait for it runs out is not a failure: no toast', async ($, on) => {
  const seen = world(on, {
    files: ['/tmp/r.md'],
    messages: [say('/tmp/r.md')],
    run: async (_argv, clock) => {
      await clock.sleep(10 * 60 * 1000)
      throw new Error('timed out')
    },
  })

  await $.command.run(md())
  await (await listed($)).ui.press({ key: '/tmp/r.md' })
  await seen.clock.advance(10 * 60 * 1000)
  await seen.clock.settle()

  expect(seen.runs).toHaveLength(1)
  expect(seen.toasts).toEqual([])
})

test('the same wait running out early is a failure: a toast', async ($, on) => {
  const seen = world(on, {
    files: ['/tmp/r.md'],
    messages: [say('/tmp/r.md')],
    run: async (_argv, clock) => {
      await clock.sleep(1000)
      throw new Error('killed')
    },
  })

  await $.command.run(md())
  await (await listed($)).ui.press({ key: '/tmp/r.md' })
  await seen.clock.advance(1000)
  await seen.clock.settle()

  expect(seen.toasts).toHaveLength(1)
})
