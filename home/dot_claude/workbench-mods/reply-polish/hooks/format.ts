// Pure text rewriting for an assistant reply. The result is still markdown: the engine's own
// renderer draws it, so themes, links and code highlighting are kept.

export const MAX_CODE_LINES = 30
export const KEEP_CODE_LINES = 12
// Without a measured width, a table stays a table when its widest row fits and it has few columns.
export const WIDE_TABLE = 72
export const MAX_COLUMNS = 3
// A table segment carries what `drawTable` returns, line by line (see there).
export type ListItem = { depth: number; marker: string; text: string }

export type Segment =
  | { kind: 'text'; text: string }
  | { kind: 'heading'; level: number; text: string }
  | { kind: 'list'; items: ListItem[] }
  | ({ kind: 'table' } & Drawn)

const OPEN_FENCE = /^\s*(`{3,}|~{3,})/
const LIST_ITEM = /^(\s*)([-*+]|\d{1,3}[.)])\s+(.*)$/
const BULLETS = ['•', '◦', '▪']
// Characters that may not start a line (closing punctuation) or end one (opening punctuation).
const NO_START = '，。、；：！？）】》」』”’…%,.;:!?)]}'
const NO_END = '（【《「『“‘([{'
const HEADING = /^(#{1,6})\s+(.*?)\s*#*\s*$/
const SEPARATOR = /^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$/

const PIPE = '\u0000'

const cells = (line: string): string[] =>
  line
    .trim()
    .replace(/\\\|/g, PIPE)
    .replace(/^\|/, '')
    .replace(/\|$/, '')
    .split('|')
    .map(cell => cell.split(PIPE).join('|').trim())

const closesFence = (line: string, marker: string): boolean => {
  const text = line.trim()
  const mark = text[0] ?? ''
  return text.length >= marker.length && mark === marker[0] && text === mark.repeat(text.length)
}

const isTableStart = (lines: string[], i: number): boolean => {
  const line = lines[i] ?? ''
  const next = lines[i + 1]
  return (
    next !== undefined &&
    line.includes('|') &&
    next.includes('|') &&
    SEPARATOR.test(next) &&
    cells(line).length >= 2 &&
    cells(line).length === cells(next).length
  )
}

const isWide = (cp: number): boolean =>
  (cp >= 0x1100 && cp <= 0x115f) ||
  (cp >= 0x2e80 && cp <= 0xa4cf) ||
  (cp >= 0xac00 && cp <= 0xd7a3) ||
  (cp >= 0xf900 && cp <= 0xfaff) ||
  (cp >= 0xfe30 && cp <= 0xfe6f) ||
  (cp >= 0xff00 && cp <= 0xff60) ||
  (cp >= 0xffe0 && cp <= 0xffe6) ||
  (cp >= 0x1f300 && cp <= 0x1faff)

// Terminal cells a string takes: CJK and emoji are two cells wide.
export const displayWidth = (text: string): number => {
  let width = 0
  for (const char of text) width += isWide(char.codePointAt(0) ?? 0) ? 2 : 1
  return width
}

// A cell or a heading is drawn as plain text, so inline markdown is reduced to what it shows.
const plain = (cell: string): string =>
  cell
    .replace(/\*\*(.+?)\*\*/g, '$1')
    .replace(/`([^`]+)`/g, '$1')
    .replace(/\[([^\]]+)\]\([^)]*\)/g, '$1')

// A line cut to `width` cells. A Latin word or number stays with the Chinese character after it
// ("20个"), closing punctuation never starts a line and opening punctuation never ends one.
export const wrapLine = (line: string, width: number): string[] => {
  if (displayWidth(line) <= width) return [line]

  const pieces: string[] = []
  let run = ''
  for (const char of line) {
    if (char === ' ') {
      if (run !== '') pieces.push(run)
      run = ''
      pieces.push(' ')
    } else if (isWide(char.codePointAt(0) ?? 0)) {
      pieces.push(run + char)
      run = ''
    } else {
      run += char
    }
  }
  if (run !== '') pieces.push(run)

  const units: string[] = []
  for (const piece of pieces) {
    const prev = units[units.length - 1]
    const isGlued =
      prev !== undefined &&
      prev !== ' ' &&
      piece !== ' ' &&
      (NO_START.includes(piece.charAt(0)) || NO_END.includes(prev.charAt(prev.length - 1)))
    if (isGlued) units[units.length - 1] = prev + piece
    else units.push(piece)
  }

  const out: string[] = []
  let current = ''
  let used = 0
  // Backticks are never shown; `**` is hidden as bold markup, but shown inside a code span.
  let isInCode = false
  for (const unit of units) {
    if (unit === ' ') {
      if (current !== '') {
        current += ' '
        used += 1
      }
      continue
    }
    const ticks = (unit.match(/`/g) ?? []).length
    const shown = isInCode || ticks > 0 ? unit.replace(/`/g, '') : unit.replace(/\*\*/g, '')
    if (ticks % 2 === 1) isInCode = !isInCode
    const size = displayWidth(shown)
    if (used + size > width && current.trim() !== '') {
      out.push(current.trimEnd())
      current = ''
      used = 0
    }
    current += unit
    used += size
  }
  if (current.trim() !== '') out.push(current.trimEnd())

  return out
}

// Paragraph lines cut to `width`; code, quotes, tables and indented lines are left as written.
export const reflow = (text: string, width: number): string => {
  let isFenced = false

  return text
    .split('\n')
    .flatMap(raw => {
      if (OPEN_FENCE.test(raw)) {
        isFenced = !isFenced
        return [raw]
      }
      // One to three leading spaces mean nothing in markdown; four or more make a code block.
      const line = isFenced || !/^ {1,3}\S/.test(raw) ? raw : raw.trimStart()
      return isFenced || /^(\s|>|\||<)/.test(line) ? [line] : wrapLine(line, width)
    })
    .join('\n')
}

// A table with this many body rows or more gets a rule between its rows, so a long table stays readable.
export const ROW_RULES_FROM = 7
// A column is never squeezed below this many cells; a table that needs less goes to a list.
export const MIN_COLUMN = 4

type Drawn = {
  lines: string[]
  // Per line: the padded plain cells of a content line, null for a rule.
  cells: (string[] | null)[]
  // Per line: the cells as written in markdown (code spans, bold), null for a rule.
  sources: (string[] | null)[]
  widths: number[]
  width: number
  // How many lines the header takes, from line 1 on; a wrapped header takes more than one.
  headerLines: number
}

// Cuts at most `width` cells off the front of `text`, ignoring the markup that is not shown.
const hardSplit = (text: string, width: number): string[] => {
  const out: string[] = []
  let current = ''
  let used = 0
  let i = 0
  while (i < text.length) {
    const isMark = text[i] === '`' || text.startsWith('**', i)
    const step = text.startsWith('**', i) ? 2 : 1
    const char = isMark ? text.slice(i, i + step) : String.fromCodePoint(text.codePointAt(i) ?? 32)
    const size = isMark ? 0 : displayWidth(char)
    if (used + size > width && current !== '') {
      out.push(current)
      current = ''
      used = 0
    }
    current += char
    used += size
    i += char.length
  }
  if (current !== '') out.push(current)
  return out
}

// A cell as lines of at most `width` cells. A code span or bold run cut by a line break is closed
// at the end of its line and opened again at the start of the next, so each line draws on its own.
export const wrapCell = (source: string, width: number): string[] => {
  const text = source.replace(/\[([^\]]+)\]\([^)]*\)/g, '$1')
  if (text === '') return ['']

  const lines = wrapLine(text, width).flatMap(line => (displayWidth(line.replace(/`|\*\*/g, '')) > width ? hardSplit(line, width) : [line]))
  let isCode = false
  let isBold = false

  return lines.map(line => {
    const prefix = (isCode ? '`' : '') + (isBold ? '**' : '')
    for (const part of line.split(/(`|\*\*)/)) {
      if (part === '`') isCode = !isCode
      else if (part === '**' && !isCode) isBold = !isBold
    }
    return prefix + line + (isBold ? '**' : '') + (isCode ? '`' : '')
  })
}

// The widest column width `cap` such that the columns, each cut to `cap`, fit in `available`.
const capColumns = (natural: number[], available: number): number[] | null => {
  if (natural.reduce((sum, width) => sum + width, 0) <= available) return natural
  for (let cap = Math.max(...natural) - 1; cap >= MIN_COLUMN; cap -= 1) {
    const widths = natural.map(width => Math.min(width, cap))
    if (widths.reduce((sum, width) => sum + width, 0) <= available) return widths
  }
  return null
}

// The table as box-drawing lines, columns sized to their widest cell. Line 1 is the header. With
// `maxWidth`, the widest columns are narrowed and their cells wrap onto more lines; null when even
// the narrowest columns do not fit.
export const drawTable = (header: string[], rows: string[][], maxWidth?: number): Drawn | null => {
  const raw = [header, ...rows.map(row => header.map((_, k) => row[k] ?? ''))]
  const grid = raw.map(row => row.map(plain))
  const natural = header.map((_, k) => Math.max(...grid.map(row => displayWidth(row[k] ?? ''))))
  const widths = maxWidth === undefined ? natural : capColumns(natural, maxWidth - (3 * header.length + 1))
  if (widths === null) return null

  const pad = (text: string, width: number) => text + ' '.repeat(Math.max(0, width - displayWidth(text)))
  const rule = (left: string, mid: string, right: string) =>
    left + widths.map(width => '─'.repeat(width + 2)).join(mid) + right
  const [top, middle, bottom] = [rule('┌', '┬', '┐'), rule('├', '┼', '┤'), rule('└', '┴', '┘')]

  // Each table row as visual lines: [sources of each cell] per line.
  const wrapped = raw.map(row => {
    const pieces = row.map((cell, k) => (displayWidth(plain(cell)) <= (widths[k] ?? 0) ? [cell] : wrapCell(cell, widths[k] ?? 0)))
    const height = Math.max(...pieces.map(cell => cell.length))
    return Array.from({ length: height }, (_, line) => pieces.map(cell => cell[line] ?? ''))
  })
  const isWrapped = wrapped.some(row => row.length > 1)
  const hasRowRules = rows.length >= ROW_RULES_FROM || isWrapped

  type Entry = { rule: string } | { source: string[] }
  const entries: Entry[] = [{ rule: top }]
  wrapped.forEach((row, r) => {
    entries.push(...row.map(source => ({ source })))
    if (r === 0 || (hasRowRules && r < wrapped.length - 1)) entries.push({ rule: middle })
  })
  entries.push({ rule: bottom })

  const padded = (source: string[]) => source.map((cell, k) => pad(plain(cell), widths[k] ?? 0))

  return {
    lines: entries.map(entry => ('rule' in entry ? entry.rule : '│ ' + padded(entry.source).join(' │ ') + ' │')),
    cells: entries.map(entry => ('rule' in entry ? null : padded(entry.source))),
    sources: entries.map(entry => ('rule' in entry ? null : entry.source)),
    widths,
    width: displayWidth(top),
    headerLines: wrapped[0]?.length ?? 1,
  }
}

// Two columns: one bullet per row, "- **first** — second".
// More columns: a bullet per row with one sub-bullet per cell, "  - head: cell".
// Returns null when the table is small enough to stay as it is, unless `force` is set.
const tableItems = (header: string[], rows: string[][]): ListItem[] =>
  rows.flatMap((row): ListItem[] => {
    const [first = '', ...rest] = header.map((_, k) => row[k] ?? '')
    const title = first === '' ? '' : first.includes('**') ? first : `**${first}**`

    if (rest.length === 1) {
      const only = rest[0] ?? ''
      return [{ depth: 0, marker: '•', text: `${title}${title !== '' && only !== '' ? ' — ' : ''}${only}` }]
    }

    const parts = rest.flatMap((cell, k): ListItem[] =>
      cell === '' ? [] : [{ depth: 1, marker: '◦', text: `${header[k + 1] ?? ''}: ${cell}` }],
    )
    return [{ depth: 0, marker: '•', text: title }, ...parts]
  })

const tableToList = (header: string[], rows: string[][], rawLines: string[], force = false): string[] | null => {
  const widest = Math.max(...rawLines.map(line => line.length))
  if (!force && widest <= WIDE_TABLE && header.length <= MAX_COLUMNS) return null

  return tableItems(header, rows).map(item => `${'  '.repeat(item.depth)}- ${item.text}`)
}

// The reply as text blocks, headings and tables. With `width` (the cells a table may take, the text
// column's) a table that fits is returned as a table to draw and one that does not becomes a list,
// and headings are blocks of their own; without it, only a wide table becomes a list, headings
// become bold lines and the rest stays markdown for the engine.
export const layout = (text: string, width?: number): Segment[] => {
  const lines = text.split('\n')
  const out: string[] = []
  const segments: Segment[] = []
  const lastIsBlank = () => out.length > 0 && (out[out.length - 1] ?? '').trim() === ''
  const flush = () => {
    const block = out.join('\n').replace(/^\n+|\n+$/g, '')
    if (block !== '') segments.push({ kind: 'text', text: block })
    out.length = 0
  }
  let i = 0

  while (i < lines.length) {
    const line = lines[i] ?? ''
    const fence = OPEN_FENCE.exec(line)

    if (fence) {
      const marker = fence[1] ?? '```'
      let end = i + 1
      while (end < lines.length && !closesFence(lines[end] ?? '', marker)) end += 1
      const isClosed = end < lines.length
      const body = lines.slice(i + 1, end)

      out.push(line)
      if (isClosed && body.length > MAX_CODE_LINES) {
        out.push(...body.slice(0, KEEP_CODE_LINES))
        out.push(`… ${body.length - KEEP_CODE_LINES} more lines hidden (ctrl+o shows the whole reply)`)
      } else {
        out.push(...body)
      }
      if (isClosed) out.push(lines[end] ?? '')
      i = isClosed ? end + 1 : lines.length
      continue
    }

    if (isTableStart(lines, i)) {
      let end = i + 2
      while (end < lines.length && (lines[end] ?? '').trim() !== '' && (lines[end] ?? '').includes('|')) end += 1
      const raw = lines.slice(i, end)
      const header = cells(line)
      const rows = lines.slice(i + 2, end).map(cells)
      const drawn = width === undefined ? null : drawTable(header, rows, width)

      if (drawn !== null) {
        flush()
        segments.push({ kind: 'table', ...drawn })
      } else if (width !== undefined) {
        flush()
        segments.push({ kind: 'list', items: tableItems(header, rows) })
      } else {
        out.push(...(tableToList(header, rows, raw) ?? raw))
      }
      i = end
      continue
    }

    const heading = HEADING.exec(line)
    if (heading) {
      const level = (heading[1] ?? '#').length
      const title = (heading[2] ?? '').replace(/^\*\*(.+)\*\*$/, '$1')

      if (width !== undefined) {
        flush()
        segments.push({ kind: 'heading', level, text: plain(title) })
      } else {
        if (level <= 2 && out.length > 0 && !lastIsBlank()) out.push('')
        out.push(`**${title}**`)
      }
      i += 1
      continue
    }

    if (width !== undefined && LIST_ITEM.test(line)) {
      flush()
      const items: ListItem[] = []
      const indents: number[] = []
      let end = i

      while (end < lines.length) {
        const current = lines[end] ?? ''
        const item = LIST_ITEM.exec(current)

        if (item) {
          const indent = (item[1] ?? '').length
          while (indents.length > 0 && indent < (indents[indents.length - 1] ?? 0)) indents.pop()
          if (indents.length === 0 || indent > (indents[indents.length - 1] ?? 0)) indents.push(indent)
          const depth = Math.min(indents.length - 1, BULLETS.length - 1)
          const mark = item[2] ?? '-'
          items.push({
            depth,
            marker: /^\d/.test(mark) ? mark : (BULLETS[depth] ?? '•'),
            text: (item[3] ?? '').trim(),
          })
        } else if (items.length > 0 && /^\s{2,}\S/.test(current) && !OPEN_FENCE.test(current)) {
          const last = items[items.length - 1]
          if (last !== undefined) last.text += ' ' + current.trim()
        } else {
          break
        }
        end += 1
      }

      segments.push({ kind: 'list', items })
      i = end
      continue
    }

    if (line.trim() === '') {
      if (!lastIsBlank()) out.push('')
    } else {
      out.push(line)
    }
    i += 1
  }

  flush()
  return segments.length > 0 ? segments : [{ kind: 'text', text: '' }]
}

// The reply as one markdown string, for a surface that cannot be measured.
export const polish = (text: string): string =>
  layout(text)
    .map(segment => {
      if (segment.kind === 'text') return segment.text
      if (segment.kind === 'heading') return `**${segment.text}**`
      if (segment.kind === 'list') return segment.items.map(item => `${item.marker} ${item.text}`).join('\n')
      return segment.lines.join('\n')
    })
    .join('\n')
