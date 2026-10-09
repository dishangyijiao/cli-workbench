import { expect, test } from 'claude-code/testing'

import { mentionsIn, resolve, tilde } from './paths'

const where = { cwd: '/work/proj', home: '/u/me' }

test('finds absolute, home and relative Markdown paths in text, in the order written', () => {
  const text = 'Wrote /tmp/report.md, see ~/notes/plan.md and docs/a.md, also ./b.md and ../c.md.'

  expect(mentionsIn(text).map(m => m[0])).toEqual(['/tmp/report.md', '~/notes/plan.md', 'docs/a.md', './b.md', '../c.md'])
})

test('a path inside backticks, quotes, a Markdown link or parentheses is found without them', () => {
  const text = "`/a/x.md` \"/a/y.md\" '/a/z.md' [plan](docs/plan.md) (/a/w.md)"

  expect(mentionsIn(text).map(m => m[0])).toEqual(['/a/x.md', '/a/y.md', '/a/z.md', 'docs/plan.md', '/a/w.md'])
})

test('other suffixes are not Markdown files: .mdx, .md.bak, .mdown', () => {
  expect(mentionsIn('/a/x.mdx /a/y.md.bak /a/z.mdown')).toEqual([])
})

test('a line number after the path is not part of it', () => {
  expect(mentionsIn('/a/x.md:12 and /a/y.md#heading').map(m => m[0])).toEqual(['/a/x.md', '/a/y.md'])
})

test('Chinese text glued to a path: the path itself is offered as a second spelling', () => {
  expect(mentionsIn('报告在/tmp/r.md里，计划见~/p.md。')).toEqual([
    ['报告在/tmp/r.md', '/tmp/r.md'],
    ['计划见~/p.md', '~/p.md'],
  ])
  expect(mentionsIn('见 /tmp/r.md。').map(m => m[0])).toEqual(['/tmp/r.md'])
})

test('text with no Markdown path finds nothing', () => {
  expect(mentionsIn('nothing here, just README and main.ts')).toEqual([])
})

test('resolve: absolute paths are kept, with . and .. folded', () => {
  expect(resolve('/a/./b/../c.md', where)).toBe('/a/c.md')
})

test('resolve: ~/ is the home directory, and nothing when HOME is unknown', () => {
  expect(resolve('~/notes/plan.md', where)).toBe('/u/me/notes/plan.md')
  expect(resolve('~/notes/plan.md', { cwd: '/work/proj', home: undefined })).toBeNull()
})

test("resolve: a relative path is taken from the session's working directory", () => {
  expect(resolve('docs/a.md', where)).toBe('/work/proj/docs/a.md')
  expect(resolve('./b.md', where)).toBe('/work/proj/b.md')
  expect(resolve('../c.md', where)).toBe('/work/c.md')
})

test("resolve: another user's home (~bob/x.md) is not guessed", () => {
  expect(resolve('~bob/x.md', where)).toBeNull()
})

test('tilde: the home directory is shown as ~, only as a whole directory', () => {
  expect(tilde('/u/me/notes/plan.md', '/u/me')).toBe('~/notes/plan.md')
  expect(tilde('/u/meg/plan.md', '/u/me')).toBe('/u/meg/plan.md')
  expect(tilde('/tmp/r.md', undefined)).toBe('/tmp/r.md')
})
