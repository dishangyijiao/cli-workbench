import { atom, read, update } from 'claude-code'
import type { Engine, Register } from 'claude-code'

import type { Drift } from '../types'

const drift = atom({ plugin: 'chezmoi-guard', key: 'drift' } as const, [] as Drift)

const SHOWN = 3

// chezmoi prints "<status> <path>" per drifted target; fail open when it cannot run.
const refresh = async ($: Engine) => {
  try {
    const { exitCode, stdout } = await $.process.run(['chezmoi', 'status'], { timeoutMs: 15000 })
    if (exitCode !== 0) return
    const rows: Drift = stdout
      .split('\n')
      .filter(line => line.trim() !== '')
      .map(line => ({ status: line.slice(0, 2), path: line.slice(3) }))
    await update($, drift, () => rows)
  } catch {
    // chezmoi missing or too slow: keep the last answer.
  }
}

// The chezmoi source file behind a deployed path, or null when chezmoi does not manage it.
const sourceOf = async ($: Engine, path: string): Promise<string | null> => {
  try {
    const { exitCode, stdout } = await $.process.run(['chezmoi', 'source-path', path])
    return exitCode === 0 ? stdout.trim() : null
  } catch {
    return null
  }
}

export const register: Register = on => {
  for (const tool of ['Edit', 'Write', 'NotebookEdit'] as const) {
    on('tool.call', { tool }, async ($, e, next) => {
      const path = e.tool === 'NotebookEdit' ? e.notebook_path : e.file_path
      const source = await sourceOf($, path)

      return source === null
        ? next(e)
        : {
            deny:
              `${path} is deployed by chezmoi and is overwritten on the next apply. ` +
              `Edit its source instead: ${source}. Then run chezmoi diff, chezmoi apply and chezmoi verify.`,
          }
    })
  }

  on('session.start', async ($, e, next) => {
    await refresh($)
    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    await refresh($)
    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const rows = await read($, drift)
    if (e.props.hasSurvey || rows.length === 0) return next(e)

    const { Box, Text } = $.ui.resolve(e)
    const names = rows.slice(0, SHOWN).map(row => row.path).join(', ')
    const more = rows.length > SHOWN ? ` and ${rows.length - SHOWN} more` : ''

    return (
      <Box>
        <Text color="yellow">
          chezmoi: {rows.length} deployed file{rows.length === 1 ? '' : 's'} differ from the source ({names}
          {more}). Run chezmoi diff.
        </Text>
      </Box>
    )
  })
}
