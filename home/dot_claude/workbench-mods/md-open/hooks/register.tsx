import { atom, read, update } from 'claude-code'
import type { EngineInterface as Engine, Register } from 'claude-code'

import type { Found } from '../types'
import { mentionsOf, resolve, tilde } from './paths'

const PANE = 'md-open'
const files = atom({ plugin: 'md-open', key: 'files' } as const, [] as Found[])

// The list stops here: a long session can mention hundreds of files, and the newest are the ones wanted.
const MAX = 50

// tmux waits for the popup to close. The engine allows a process ten minutes at most; a popup still open then
// stays open (tmux keeps it when its caller is killed), so a call that ends that late is not a failure.
const POPUP_WAIT_MS = 10 * 60 * 1000
const FAILED_FAST_MS = 5000

// The Markdown files the conversation mentioned that exist, the most recently mentioned first, each once.
const collect = async ($: Engine): Promise<Found[]> => {
  const [messages, cwd, home] = await Promise.all([$.session.messages(), $.session.cwd(), $.env.get('HOME')])
  const isFile = new Map<string, Promise<boolean>>()
  const exists = (path: string) => {
    if (!isFile.has(path)) {
      isFile.set(
        path,
        $.fs.stat(path).then(
          stat => stat.kind === 'file',
          () => false,
        ),
      )
    }
    return isFile.get(path)!
  }

  const found: Found[] = []
  const seen = new Set<string>()
  for (const mention of mentionsOf(messages).reverse()) {
    if (found.length >= MAX) break
    for (const spelling of mention) {
      const path = resolve(spelling, { cwd, home })
      if (path === null || !(await exists(path))) continue
      if (!seen.has(path)) {
        seen.add(path)
        found.push({ path, label: tilde(path, home) })
      }
      break
    }
  }
  return found
}

// Opens the file read-only in Neovim in a tmux popup. The path goes to tmux as one argument of an argv, never into a
// shell string or a tmux format: it comes from conversation text. Outside tmux, or when tmux fails, a toast names it.
const show = async ($: Engine, file: Found) => {
  const fallback = (why: string) => $.ui.toast(`${why} Open it yourself: ${file.label}`, { timeoutMs: 15000 })
  if (!(await $.env.get('TMUX'))) return fallback('Not inside tmux.')

  const started = await $.clock.now()
  try {
    const ran = await $.process.run(['tmux', 'display-popup', '-E', '-w', '90%', '-h', '90%', 'nvim', '-R', '--', file.path], {
      timeoutMs: POPUP_WAIT_MS,
    })
    // Neovim's own exit code comes back too (:cq); only tmux writes to this stderr.
    if (ran.exitCode !== 0 && ran.stderr.trim() !== '') await fallback(`tmux could not open a popup (${ran.stderr.trim()}).`)
  } catch {
    if ((await $.clock.now()) - started < FAILED_FAST_MS) await fallback('tmux could not be started.')
  }
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'md',
      description: 'Pick a Markdown file this conversation mentioned and read it in Neovim',
      immediate: true,
    })
    return next(e)
  })

  on('command.run', { command: 'md' }, async $ => {
    const found = await collect($)
    await update($, files, () => found)
    if (found.length === 0) return { text: 'This conversation mentions no Markdown file that exists.' }

    await $.ui.open({ id: PANE, title: 'Markdown', focus: true, closeOnEscape: true })
    const count = found.length === 1 ? '1 Markdown file' : `${found.length} Markdown files`
    return { text: `${count}: pick one in the pane (Enter or its digit; Esc closes it).` }
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text, Button } = $.ui.resolve(e)
    const list = await read($, files)

    const choose = (file: Found) => () => {
      void (async () => {
        await $.ui.close({ id: PANE })
        await show($, file)
      })()
    }

    return (
      <Box flexDirection="column">
        <Text dimColor>Markdown files in this conversation, newest first</Text>
        {list.map((file, i) => (
          <Button
            key={file.path}
            label={file.label}
            plain
            hotkey={i < 9 ? String(i + 1) : undefined}
            autoFocus={i === 0 ? true : undefined}
            onPress={choose(file)}
          />
        ))}
      </Box>
    )
  })
}
