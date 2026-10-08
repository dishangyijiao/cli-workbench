import type { Engine, Register } from 'claude-code'

import { asksYou } from './state'
import type { AgentAction } from './state'

// The script is deployed by chezmoi with the tmux scripts. Only the action word reaches the command line, as a separate
// argument; the session id travels on stdin.
const SCRIPT = 'exec "$HOME/.tmux/scripts/agent-state.sh" "$1"'

// The most a hook waits for the script: it takes a few milliseconds, and a slow or stuck one must not hold the chain.
const BUDGET_MS = 1000

// Outside tmux the script does nothing; any failure is dropped. The overview is a hint, so a lost event costs one glance.
const record = async ($: Engine, action: AgentAction) => {
  try {
    await $.process.run(['sh', '-c', SCRIPT, 'sh', action], {
      stdin: JSON.stringify({ session_id: await $.session.id() }),
      timeoutMs: BUDGET_MS,
    })
  } catch {
    // tmux or the script is missing: the overview just does not list this pane.
  }
}

export const register: Register = on => {
  // The main agent's real turns. A turn start is working; any turn end (an answer, an interrupt, a refusal, an API error)
  // is idle. A subagent's turns are not the agent being idle.
  on('turn.start', async ($, e, next) => {
    // A subagent starting must not turn a wait on the main agent back into working.
    if (e.agentId === undefined) await record($, 'working')
    return next(e)
  })
  on('turn.complete', async ($, e, next) => {
    if (e.agentId === undefined) await record($, 'idle')
    return next(e)
  })

  // A compaction fires the session start in the middle of a turn: it is not a new start.
  on('classic.SessionStart', async ($, e, next) => {
    if (e.source !== 'compact') await record($, 'idle')
    return next(e)
  })
  on('classic.SessionEnd', async ($, e, next) => {
    await record($, 'end')
    return next(e)
  })

  // The agent needs you. A subagent's prompt counts too: you are the one who has to answer it.
  on('classic.PermissionRequest', async ($, e, next) => {
    await record($, 'waiting')
    return next(e)
  })
  on('classic.Notification', async ($, e, next) => {
    if (asksYou(e.notification_type)) await record($, 'waiting')
    return next(e)
  })

  // Something ran, failed, was denied or was answered after the wait began: if the pane still says waiting, it is not.
  // No matching of requests to results; a wrong guess is corrected by the next event.
  on('classic.PostToolUse', async ($, e, next) => {
    await record($, 'heal')
    return next(e)
  })
  on('classic.PostToolUseFailure', async ($, e, next) => {
    await record($, 'heal')
    return next(e)
  })
  on('classic.PermissionDenied', async ($, e, next) => {
    await record($, 'heal')
    return next(e)
  })
  on('classic.ElicitationResult', async ($, e, next) => {
    await record($, 'heal')
    return next(e)
  })
}
