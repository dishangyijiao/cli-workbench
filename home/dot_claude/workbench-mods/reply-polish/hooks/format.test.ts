import { expect, test } from 'claude-code/testing'

import { displayWidth, drawTable, layout, polish, reflow, wrapLine } from './format'

const SMALL_TABLE = ['| 名称 | 命令 |', '|---|---|', '| tmux | `tmux` |', '| zellij | `zellij` |'].join('\n')

const WIDE_ROW = '| Feature that needs a long name | An even longer description that goes on and on past the limit |'

test('turns a wide table into a bullet list', () => {
  const text = [WIDE_ROW, '|---|---|', '| alpha | first thing |', '| beta | second thing |'].join('\n')

  expect(polish(text)).toBe('- **alpha** — first thing\n- **beta** — second thing')
})

test('puts each cell of a table with more than two columns on its own line', () => {
  const text = ['| Name | Value | Scope | Notes |', '|---|---|---|---|', '| a | 1 | user |  |'].join('\n')

  expect(polish(text)).toBe('- **a**\n  - Value: 1\n  - Scope: user')
})

test('leaves a small table alone', () => {
  const text = ['| a | b |', '|---|---|', '| 1 | 2 |'].join('\n')

  expect(polish(text)).toBe(text)
})

test('turns headings into bold lines with a blank line before a top-level one', () => {
  expect(polish('intro\n## Title\ntext\n### Sub\nmore')).toBe('intro\n\n**Title**\ntext\n**Sub**\nmore')
})

test('collapses runs of blank lines', () => {
  expect(polish('a\n\n\n\nb')).toBe('a\n\nb')
})

test('shortens a code block longer than the limit and says how much is hidden', () => {
  const body = Array.from({ length: 40 }, (_, k) => `line ${k + 1}`)
  const out = polish(['```ts', ...body, '```'].join('\n')).split('\n')

  expect(out[0]).toBe('```ts')
  expect(out[12]).toBe('line 12')
  expect(out[13]).toContain('28 more lines hidden')
  expect(out[out.length - 1]).toBe('```')
})

test('does not touch headings, tables or blank runs inside a code block', () => {
  const text = ['```md', '# not a heading', '', '', '| a | b |', '|---|---|', '```'].join('\n')

  expect(polish(text)).toBe(text)
})

test('leaves an unfinished code block whole while the reply is still streaming', () => {
  const body = Array.from({ length: 40 }, (_, k) => `line ${k + 1}`)
  const text = ['```ts', ...body].join('\n')

  expect(polish(text)).toBe(text)
})

test('counts Chinese characters as two cells', () => {
  expect(displayWidth('tmux')).toBe(4)
  expect(displayWidth('名称')).toBe(4)
})

test('draws a table whose lines are all the same width, Chinese included', () => {
  const { lines, width } = drawTable(['名称', '命令'], [['tmux', '`tmux`'], ['zellij', '**zellij**']])

  expect(lines.map(displayWidth)).toEqual(lines.map(() => width))
  expect((lines[0] ?? '').startsWith('┌')).toBe(true)
  expect(lines[1]).toContain('名称')
  expect(lines[3] ?? '').toContain('│ tmux   │ tmux   │')
})

test('gives the cells of each table line, null for a rule', () => {
  const { cells } = drawTable(['a', 'b'], [['1', '2']])

  expect(cells).toEqual([null, ['a', 'b'], null, ['1', '2'], null])
})

test('keeps the markdown of each cell for drawing', () => {
  const { sources, widths } = drawTable(['名称', '命令'], [['tmux', '`tmux ls`']])

  expect(sources).toEqual([null, ['名称', '命令'], null, ['tmux', '`tmux ls`'], null])
  expect(widths).toEqual([4, 7])
})

test('puts a rule between the rows of a long table only', () => {
  const body = (count: number) => Array.from({ length: count }, (_, k) => [`r${k}`, 'x'])
  const rules = (count: number) => drawTable(['a', 'b'], body(count)).lines.filter(line => line.startsWith('├')).length

  expect(rules(6)).toBe(1)
  expect(rules(7)).toBe(7)
})

test('returns headings as blocks of their own when the width is known', () => {
  const segments = layout('intro\n## Title\ntext\n### Sub\nmore', 100)

  expect(segments).toEqual([
    { kind: 'text', text: 'intro' },
    { kind: 'heading', level: 2, text: 'Title' },
    { kind: 'text', text: 'text' },
    { kind: 'heading', level: 3, text: 'Sub' },
    { kind: 'text', text: 'more' },
  ])
})

test('returns a table to draw when it fits the width', () => {
  const segments = layout(`before\n\n${SMALL_TABLE}\n\nafter`, 100)

  expect(segments.map(segment => segment.kind)).toEqual(['text', 'table', 'text'])
})

test('turns a table that does not fit the width into a list', () => {
  const segments = layout(SMALL_TABLE, 12)

  expect(segments).toEqual([
    {
      kind: 'list',
      items: [
        { depth: 0, marker: '•', text: '**tmux** — `tmux`' },
        { depth: 0, marker: '•', text: '**zellij** — `zellij`' },
      ],
    },
  ])
})

test('leaves a small table to the engine when the width is unknown', () => {
  expect(polish(SMALL_TABLE)).toBe(SMALL_TABLE)
})

test('keeps a number with the unit after it when a line is cut', () => {
  // "20个" is five cells wide: the cut falls before it, not between 20 and 个.
  const lines = wrapLine('已经改好类型检查校验都通过20个测试全部通过', 36)

  expect(lines.every(line => !line.endsWith('20'))).toBe(true)
  expect(lines.join('')).toBe('已经改好类型检查校验都通过20个测试全部通过')
})

test('never starts a line with closing punctuation or ends one with opening punctuation', () => {
  const lines = wrapLine('一二三四五六七八九十，一二三四五六七八九十（一二三四五六七八九十）', 20)

  expect(lines.every(line => !'，。）'.includes(line.charAt(0)))).toBe(true)
  expect(lines.every(line => !'（'.includes(line.charAt(line.length - 1)))).toBe(true)
})

test('keeps every line within the width', () => {
  const lines = wrapLine('这是一个很长的句子，需要被切成几行，每一行都不能超过给定的宽度，否则就会溢出。', 24)

  expect(lines.every(line => displayWidth(line) <= 26)).toBe(true)
})

test('counts the asterisks inside a code span, which are shown', () => {
  const text = '折行是我自己按字符宽度算的，行内的 `**加粗**` 和链接地址会让计算略有偏差，可能个别行偏短一点。'
  const lines = wrapLine(text, 40)

  // Backticks are hidden, everything else is drawn: no line may be wider than the column.
  expect(lines.every(line => displayWidth(line.replace(/`/g, '')) <= 40)).toBe(true)
  expect(lines.length).toBeGreaterThan(1)
})

test('leaves code, quotes and indented lines alone when reflowing', () => {
  const long = '一二三四五六七八九十'.repeat(5)
  const text = ['```', long, '```', `> ${long}`, `    ${long}`].join('\n')

  expect(reflow(text, 20)).toBe(text)
})

test('drops one to three leading spaces of a paragraph line but keeps a code block', () => {
  expect(reflow('   一段话', 40)).toBe('一段话')
  expect(reflow('    code', 40)).toBe('    code')
})

test('turns a list into items with a bullet, nesting and numbers kept', () => {
  const segments = layout('- one\n- two with **bold**\n  - nested\n1. first\n2. second', 80)

  expect(segments).toEqual([
    {
      kind: 'list',
      items: [
        { depth: 0, marker: '•', text: 'one' },
        { depth: 0, marker: '•', text: 'two with **bold**' },
        { depth: 1, marker: '◦', text: 'nested' },
        { depth: 0, marker: '1.', text: 'first' },
        { depth: 0, marker: '2.', text: 'second' },
      ],
    },
  ])
})

test('joins a wrapped list item and ends the list at a blank line', () => {
  const segments = layout('- first line\n  continued\n\nafter', 80)

  expect(segments).toEqual([
    { kind: 'list', items: [{ depth: 0, marker: '•', text: 'first line continued' }] },
    { kind: 'text', text: 'after' },
  ])
})

test('does not read a list inside a code block', () => {
  const text = ['```', '- not a list', '```'].join('\n')

  expect(layout(text, 80)).toEqual([{ kind: 'text', text }])
})

test('is stable when applied twice', () => {
  const text = ['## Title', '', '', WIDE_ROW, '|---|---|', '| a | b |'].join('\n')

  expect(polish(polish(text))).toBe(polish(text))
})
