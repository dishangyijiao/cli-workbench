import type { Engine, Register } from 'claude-code'

import { stateFor } from './state'
import type { AgentState } from './state'

// The script is deployed by chezmoi with the tmux scripts. The state word is the only thing from the event that
// reaches the command line, as a separate argument; the session id travels on stdin.
const SCRIPT = 'exec "$HOME/.tmux/scripts/agent-state.sh" "$1"'

// A hook must never slow the agent or break its chain: the script outside tmux does nothing, and any failure is dropped.
const record = async ($: Engine, state: AgentState, sessionId: string) => {
  try {
    await $.process.run(['sh', '-c', SCRIPT, 'sh', state], {
      stdin: JSON.stringify({ session_id: sessionId }),
      timeoutMs: 5000,
    })
  } catch {
    // tmux or the script is missing: the overview just does not list this pane.
  }
}

export const register: Register = on => {
  on('classic.UserPromptSubmit', async ($, e, next) => {
    await record($, 'working', e.session_id)
    return next(e)
  })
  on('classic.PostToolUse', async ($, e, next) => {
    await record($, 'resume', e.session_id)
    return next(e)
  })
  on('classic.PermissionRequest', async ($, e, next) => {
    await record($, 'waiting', e.session_id)
    return next(e)
  })
  on('classic.Notification', async ($, e, next) => {
    const state = stateFor('Notification', e.notification_type)
    if (state !== null) await record($, state, e.session_id)
    return next(e)
  })
  on('classic.Stop', async ($, e, next) => {
    await record($, 'idle', e.session_id)
    return next(e)
  })
  on('classic.SessionStart', async ($, e, next) => {
    await record($, 'idle', e.session_id)
    return next(e)
  })
  on('classic.SessionEnd', async ($, e, next) => {
    await record($, 'end', e.session_id)
    return next(e)
  })
}
