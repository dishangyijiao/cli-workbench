import { expect, test } from 'claude-code/testing'

const TABLE = '| 名称 | 命令 |\n|---|---|\n| tmux | `tmux` |'

test('hands a rewritten text to the engine and keeps the other props', async ($, on) => {
  let seen: { text: string; isFirstOfReply: boolean } | undefined

  on('ui.render', { component: 'AssistantMessage' }, ($, e) => {
    seen = { text: e.props.text, isFirstOfReply: e.props.isFirstOfReply }
    return { type: 'Text', props: {}, children: [e.props.text] }
  })

  await $.ui.render({
    component: 'AssistantMessage',
    surface: 'terminal',
    requestId: 'reply',
    props: { text: '## Title\n\n\n\nbody', isFirstOfReply: true },
  })

  expect(seen).toEqual({ text: '**Title**\n\nbody', isFirstOfReply: true })
})

test('draws headings in the accent colour inside a centered text column', async ($, on) => {
  on('ui.render', { component: 'AssistantMessage' }, () => ({ type: 'Text', props: {}, children: ['engine'] }))

  const tree = await $.ui.render({
    component: 'AssistantMessage',
    surface: 'terminal',
    requestId: 'reply',
    viewport: { columns: 120, rows: 30 },
    props: { text: '# Title\nbody text', isFirstOfReply: true },
  })
  const json = JSON.stringify(tree)

  expect(json).toContain('"color":"cyan"')
  expect(json).toContain('"width":80')
  // The column starts at cell 19; the reply's marker sits two cells to its left.
  expect(json).toContain('"marginLeft":17')
  expect(json).toContain('●')
  expect(json).not.toContain('engine')
})

test('draws list items with an accent bullet and a column of their own', async ($, on) => {
  on('ui.render', { component: 'AssistantMessage' }, () => ({ type: 'Text', props: {}, children: ['engine'] }))

  const tree = await $.ui.render({
    component: 'AssistantMessage',
    surface: 'terminal',
    requestId: 'reply',
    viewport: { columns: 120, rows: 30 },
    props: { text: '- one\n- two\n  - nested', isFirstOfReply: false },
  })
  const json = JSON.stringify(tree)

  expect(json).toContain('"•')
  expect(json).toContain('"◦')
  expect(json).not.toContain('"text":"- one')
})

test('keeps a table no wider than the text column, as a list when it is wider', async ($, on) => {
  on('ui.render', { component: 'AssistantMessage' }, () => ({ type: 'Text', props: {}, children: ['engine'] }))
  const long = '一二三四五六七八九十'.repeat(6)

  const tree = await $.ui.render({
    component: 'AssistantMessage',
    surface: 'terminal',
    requestId: 'reply',
    viewport: { columns: 160, rows: 30 },
    props: { text: `| 名称 | 说明 |\n|---|---|\n| a | ${long} |`, isFirstOfReply: false },
  })
  const json = JSON.stringify(tree)

  expect(json).not.toContain('┌')
  expect(json).toContain('"•')
  expect(json).toContain('**a** —')
})

test('draws a body cell as markdown so a code span keeps its style', async ($, on) => {
  on('ui.render', { component: 'AssistantMessage' }, () => ({ type: 'Text', props: {}, children: ['engine'] }))

  const tree = await $.ui.render({
    component: 'AssistantMessage',
    surface: 'terminal',
    requestId: 'reply',
    viewport: { columns: 120, rows: 30 },
    props: { text: TABLE, isFirstOfReply: false },
  })

  expect(JSON.stringify(tree)).toContain('"text":"`tmux`"')
})

test('starts a reply one blank line below what came before it', async ($, on) => {
  on('ui.render', { component: 'AssistantMessage' }, () => ({ type: 'Text', props: {}, children: ['engine'] }))
  const render = (isFirstOfReply: boolean) =>
    $.ui.render({
      component: 'AssistantMessage',
      surface: 'terminal',
      requestId: 'reply',
      viewport: { columns: 120, rows: 30 },
      props: { text: 'body', isFirstOfReply },
    })

  expect(JSON.stringify(await render(true))).toContain('"marginTop":1')
  expect(JSON.stringify(await render(false))).not.toContain('"marginTop":1')
})

test('draws a table that fits, centered in the measured width', async ($, on) => {
  on('ui.render', { component: 'AssistantMessage' }, () => ({ type: 'Text', props: {}, children: ['engine'] }))

  const tree = await $.ui.render({
    component: 'AssistantMessage',
    surface: 'terminal',
    requestId: 'reply',
    viewport: { columns: 100, rows: 30 },
    props: { text: `intro\n\n${TABLE}`, isFirstOfReply: true },
  })
  const json = JSON.stringify(tree)

  expect(json).toContain('┌')
  expect(json).toContain('"marginLeft":')
  expect(json).not.toContain('engine')
})
