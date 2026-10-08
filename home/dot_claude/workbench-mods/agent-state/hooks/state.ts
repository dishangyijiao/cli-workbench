// The words ~/.tmux/scripts/agent-state.sh takes:
//   working  a turn starts      waiting  the agent needs you      idle  a turn ended or a session starts
//   heal     waiting becomes working, anything else stays (something ran or was answered, so you must have answered)
//   end      the session is over
export type AgentAction = 'working' | 'waiting' | 'idle' | 'heal' | 'end'

// Notification types that ask you something. The others (idle_prompt, auth_success) only remind or inform, and must not
// turn an idle agent into a waiting one.
const ASKS = ['permission_prompt', 'elicitation_dialog', 'elicitation_url_dialog']

export const asksYou = (type?: string): boolean => type !== undefined && ASKS.includes(type)
