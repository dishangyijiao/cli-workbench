// What each Claude Code hook event says about the agent, as the word ~/.tmux/scripts/agent-state.sh takes:
//   working  the agent is busy        waiting  it needs you        idle  it is done and waits for a prompt
//   resume   a tool finished: waiting becomes working, anything else stays as it is
//   end      the session is over
// null means the event is not recorded.
export type AgentState = 'working' | 'waiting' | 'idle' | 'resume' | 'end'

// Notification types that ask you something. The others (idle_prompt, auth_success) only remind or inform, and must
// not turn an idle agent into a waiting one.
const ASKS = ['permission_prompt', 'elicitation_dialog']

export const stateFor = (event: string, notificationType?: string): AgentState | null => {
  switch (event) {
    case 'UserPromptSubmit':
      return 'working'
    case 'PostToolUse':
      return 'resume'
    case 'PermissionRequest':
      return 'waiting'
    case 'Notification':
      return notificationType !== undefined && ASKS.includes(notificationType) ? 'waiting' : null
    case 'Stop':
    case 'SessionStart':
      return 'idle'
    case 'SessionEnd':
      return 'end'
    default:
      return null
  }
}
