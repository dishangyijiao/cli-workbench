import type { Engine, Register } from 'claude-code'

import { NOTIFY_PREFIX, notificationWait, toolKey } from './state'
import type { AgentAction } from './state'

// The script is deployed by chezmoi with the tmux scripts. Only the action word reaches the command line, as a separate
// argument; the session id, the event time and the key travel on stdin.
const SCRIPT = 'exec "$HOME/.tmux/scripts/agent-state.sh" "$1"'

// The most a hook waits for the script: it takes a few milliseconds, and a slow or stuck one must not hold the chain.
const BUDGET_MS = 1000

// Every event gets a time of its own, strictly after the last one, so the script can drop an event that arrives late.
let last = 0
const stamp = (): number => (last = Math.max(Date.now(), last + 1))

// A hook must never slow the agent for long or break its chain: outside tmux the script does nothing, and any failure is dropped.
const record = async ($: Engine, action: AgentAction, key?: string) => {
  try {
    await $.process.run(['sh', '-c', SCRIPT, 'sh', action], {
      stdin: JSON.stringify({ session_id: await $.session.id(), ts: stamp(), ...(key === undefined ? {} : { key }) }),
      timeoutMs: BUDGET_MS,
    })
  } catch {
    // tmux or the script is missing: the overview just does not list this pane.
  }
}

export const register: Register = on => {
  // The main agent's real turns: a turn start is working, any turn end (an answer, an interrupt, a refusal, an API error)
  // is idle. A subagent's turns are not the agent being idle.
  on('turn.start', async ($, e, next) => {
    await record($, 'begin')
    return next(e)
  })
  on('turn.complete', async ($, e, next) => {
    if (e.agentId === undefined) await record($, 'idle')
    return next(e)
  })

  // A compaction restarts the session's start event in the middle of a turn: it is not a new start.
  on('classic.SessionStart', async ($, e, next) => {
    if (e.source !== 'compact') await record($, 'start')
    return next(e)
  })
  on('classic.SessionEnd', async ($, e, next) => {
    await record($, 'end')
    return next(e)
  })

  // A permission prompt is a wait on that tool call; the call finishing, failing or being denied answers it.
  on('classic.PermissionRequest', async ($, e, next) => {
    await record($, 'wait', toolKey(e.tool_name, e.tool_input))
    return next(e)
  })
  on('classic.PostToolUse', async ($, e, next) => {
    await record($, 'unwait', toolKey(e.tool_name, e.tool_input))
    return next(e)
  })
  on('classic.PostToolUseFailure', async ($, e, next) => {
    await record($, 'unwait', toolKey(e.tool_name, e.tool_input))
    return next(e)
  })
  on('classic.PermissionDenied', async ($, e, next) => {
    await record($, 'unwait', toolKey(e.tool_name, e.tool_input))
    return next(e)
  })

  // A question from an MCP server: the dialog's result answers it.
  on('classic.Notification', async ($, e, next) => {
    const key = notificationWait(e.notification_type)
    if (key !== null) await record($, 'wait', key)
    return next(e)
  })
  on('classic.ElicitationResult', async ($, e, next) => {
    await record($, 'unwait-prefix', NOTIFY_PREFIX)
    return next(e)
  })
}
