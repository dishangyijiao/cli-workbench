import type { Drift } from '../types'

const SHOWN = 3

// The line above the prompt while deployed files differ from the source, or null when none do.
export const driftMessage = (rows: Drift): string | null => {
  if (rows.length === 0) return null

  const names = rows
    .slice(0, SHOWN)
    .map(row => row.path)
    .join(', ')
  const more = rows.length > SHOWN ? ` and ${rows.length - SHOWN} more` : ''
  const noun = rows.length === 1 ? 'deployed file differs' : 'deployed files differ'

  return `chezmoi: ${rows.length} ${noun} from the source (${names}${more}). Run chezmoi diff.`
}
