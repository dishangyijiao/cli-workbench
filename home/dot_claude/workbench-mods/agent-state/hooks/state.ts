// The words ~/.tmux/scripts/agent-state.sh takes, and the keys that tie a wait to its answer.
//   begin  a turn starts      idle  a turn ended          start  a session starts or resumes      end  the session is over
//   wait   the agent needs you; the key names the request      unwait  that request was answered, denied or failed
//   unwait-prefix  every request whose key starts with the given one
export type AgentAction = 'begin' | 'idle' | 'start' | 'end' | 'wait' | 'unwait' | 'unwait-prefix'

// Notification types that ask you something an event of its own does not already say. permission_prompt is a
// PermissionRequest, which carries the tool call; idle_prompt and auth_success only remind or inform, and must not turn
// an idle agent into a waiting one.
const ASKS = ['elicitation_dialog', 'elicitation_url_dialog']

export const NOTIFY_PREFIX = 'notify:'

export const notificationWait = (type?: string): string | null =>
  type !== undefined && ASKS.includes(type) ? `${NOTIFY_PREFIX}${type}` : null

// FNV-1a over the text: short, stable, and enough to tell two tool calls of one pane apart.
const hash = (text: string): string => {
  let h = 0x811c9dc5
  for (let i = 0; i < text.length; i++) {
    h ^= text.charCodeAt(i)
    h = Math.imul(h, 0x01000193) >>> 0
  }
  return h.toString(16).padStart(8, '0')
}

// The permission request and the tool's result of one call name the same tool and carry the same input, which is how a
// result is matched to the request it answers: a request has no call id yet. Parallel calls that differ get other keys, so
// the result of one does not end the wait of another.
export const toolKey = (tool: string, input: unknown): string => {
  const name = tool.replace(/[^A-Za-z0-9_]/g, '_').slice(0, 40)
  const body = input === undefined ? '\u0000undefined' : JSON.stringify(input)
  return `tool:${name}:${hash(`${tool}\n${body}`)}`
}
