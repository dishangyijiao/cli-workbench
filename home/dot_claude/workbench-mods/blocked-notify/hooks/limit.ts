// What a background session's state and its transcript say, and how the notification words it.

// The states of `claude agents --json` in which the session needs the owner: stopped (a usage limit, a failure), asking, waiting.
const WAITING = ['blocked', 'needs_input', 'waiting']

export const isWaiting = (state?: string): boolean => state !== undefined && WAITING.includes(state)

// Claude Code keeps a session's transcript in ~/.claude/projects/<working directory with each non-alphanumeric as "-">/.
export const projectDir = (cwd: string): string => cwd.replace(/[^A-Za-z0-9]/g, '-')

export type Limit = { kind: 'session' | 'weekly'; resets: string | undefined }

// The last assistant text in the end of a transcript (JSON lines; the first line may be cut): when it says a usage limit was
// hit ("You've hit your session limit · resets 8:20pm (Asia/Tokyo)"), which limit and when it resets. An older limit line
// that the session has moved past is stale, so only the last text counts.
export const resetFrom = (tail: string): Limit | undefined => {
  let last: string | undefined
  for (const raw of tail.split('\n')) {
    let row: { type?: unknown; message?: { content?: unknown } }
    try {
      row = JSON.parse(raw)
    } catch {
      continue
    }
    if (row === null || typeof row !== 'object' || row.type !== 'assistant') continue
    const content = row.message?.content
    if (!Array.isArray(content)) continue
    const text = content
      .filter((b): b is { type: string; text: string } => b?.type === 'text' && typeof b.text === 'string')
      .map(b => b.text)
      .join('\n')
    if (text !== '') last = text
  }
  const hit = last?.match(/hit your (session|weekly) limit(?:[^\n]*?resets ([^\n]*?))?(?: \(error[^\n]*)?$/m)
  if (hit === null || hit === undefined) return undefined
  return { kind: hit[1] as Limit['kind'], resets: hit[2]?.trim() || undefined }
}

export const wording = (name: string, state: string, limit: Limit | undefined): string => {
  if (limit !== undefined) return `${name} hit the ${limit.kind} limit${limit.resets === undefined ? '' : `, resets ${limit.resets}`}`
  if (state === 'needs_input') return `${name} needs your input`
  if (state === 'waiting') return `${name} is waiting for you`
  return `${name} is blocked`
}
