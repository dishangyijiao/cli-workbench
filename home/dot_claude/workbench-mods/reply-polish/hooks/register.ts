import type { Register, RenderElement } from 'claude-code'

import { displayWidth, layout, polish, reflow } from './format'
import type { Segment } from './format'

// Layout rules, in the order of the four design principles.
//
// Contrast:    headings are bold, the first two levels in the accent colour; table borders are dim,
//              the table header takes the accent colour; body text stays plain.
// Repetition:  one accent colour, one heading style per level, one table style, one reply marker.
// Alignment:   one left edge for everything: text, headings and tables start at the same cell, and a
//              table is never wider than the text column. The column itself is centred on the screen.
// Proximity:   a heading sits right above what it introduces and a blank line apart from what came
//              before; other blocks are one blank line apart.
const ACCENT = 'cyan'
// Cells across the text column: about 40 Chinese characters or 80 Latin ones, a comfortable measure.
const MEASURE = 80
// The column takes at most this share of the window.
const FILL = 0.72
// A nested list item moves in by this many cells.
const INDENT = 2
// One Markdown block is at most this long, or the whole tree is refused.
const MAX_BLOCK = 10000
// The reply's own marker (the bullet) takes this many cells at the left.
const MARKER = 2

const text = (props: Record<string, unknown>, content: string): RenderElement =>
  ({ type: 'Text', props: { wrap: 'truncate-end', ...props }, children: [content] }) as RenderElement

const box = (props: Record<string, unknown>, children: RenderElement[]): RenderElement =>
  ({ type: 'Box', props, children }) as RenderElement

export const register: Register = on => {
  // A rewrite changes the drawing only; the stored reply, and ctrl+o, keep the original.
  on('ui.render', { component: 'AssistantMessage' }, ($, e, next) => {
    const columns = e.viewport?.columns
    // At most MEASURE cells, and a share of a narrow window, so the margins on both sides stay visible.
    const measure = columns === undefined ? undefined : Math.max(30, Math.min(MEASURE, Math.floor(columns * FILL)))
    const segments = measure === undefined ? [] : layout(e.props.text, measure)
    const isDrawable = segments.every(segment => segment.kind !== 'text' || segment.text.length <= MAX_BLOCK) &&
      segments.every(segment => segment.kind !== 'list' || segment.items.every(item => item.text.length <= MAX_BLOCK))

    if (columns === undefined || measure === undefined || !isDrawable) {
      const rewritten = polish(e.props.text)
      return next(rewritten === e.props.text ? e : { ...e, props: { ...e.props, text: rewritten } })
    }

    const left = Math.max(0, Math.floor((columns - MARKER - measure) / 2))

    const draw = (segment: Segment): RenderElement => {
      if (segment.kind === 'text') {
        return { type: 'Markdown', props: { text: reflow(segment.text, measure) } } as RenderElement
      }

      if (segment.kind === 'list') {
        // Markers share one column so the item texts line up; each text hangs after its marker.
        const markerWidth = Math.max(...segment.items.map(item => displayWidth(item.marker))) + 1

        return box(
          { flexDirection: 'column' },
          segment.items.map(item => {
            const indent = INDENT * item.depth
            const itemWidth = measure - indent - markerWidth

            return box({ flexDirection: 'row', marginLeft: indent }, [
              text({ color: ACCENT }, item.marker.padEnd(markerWidth)),
              box({ width: itemWidth }, [
                { type: 'Markdown', props: { text: reflow(item.text, itemWidth) } } as RenderElement,
              ]),
            ])
          }),
        )
      }

      if (segment.kind === 'heading') {
        const isTop = segment.level <= 2
        const title = text({ bold: true, ...(isTop ? { color: ACCENT } : {}) }, segment.text)
        const rule = text({ dimColor: true }, '─'.repeat(Math.min(displayWidth(segment.text), measure)))

        return box({ flexDirection: 'column' }, segment.level === 1 ? [title, rule] : [title])
      }

      return box(
        { flexDirection: 'column' },
        segment.cells.map((row, k) => {
          if (row === null) return text({ dimColor: true }, segment.lines[k] ?? '')

          const isHeader = k === 1
          const sources = segment.sources[k] ?? []
          // A body cell is drawn as markdown in a box of the column's width, so code spans and bold keep
          // their style; the header is plain text in the accent colour.
          const draw = (cell: string, c: number): RenderElement => {
            const source = sources[c] ?? ''
            if (isHeader) return text({ bold: true, color: ACCENT }, cell)
            if (source === '') return text({}, cell)
            return box({ width: segment.widths[c] ?? 0 }, [
              { type: 'Markdown', props: { text: source } } as RenderElement,
            ])
          }
          const pieces = row.flatMap((cell, c) => [text({ dimColor: true }, c === 0 ? '│ ' : ' │ '), draw(cell, c)])

          return box({ flexDirection: 'row' }, [...pieces, text({ dimColor: true }, ' │')])
        }),
      )
    }

    const children = segments.map((segment, i) => {
      const isFirst = i === 0 && e.props.isFirstOfReply
      const isTight = (i === 0 && !isFirst) || (i > 0 && segments[i - 1]?.kind === 'heading')
      // The marker of a reply is kept: it sits in the gutter just left of the text column.
      const hasMarker = isFirst && left >= MARKER
      const block = box({ width: measure }, [draw(segment)])

      // A reply starts one blank line below whatever came before it, a hook's notice for one.
      return box(
        { flexDirection: 'row', marginLeft: hasMarker ? left - MARKER : left, marginTop: isTight ? 0 : 1 },
        hasMarker ? [text({}, '● '), block] : [block],
      )
    })

    return box({ flexDirection: 'column' }, children)
  })
}
