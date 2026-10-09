import type { SessionMessage } from 'claude-code'

// Where relative and home paths land: the session's working directory and $HOME (unknown: ~/ paths are skipped).
export type Where = { cwd: string; home: string | undefined }

// One mention of a Markdown file: the spellings to try, the most likely first. The first one that names an existing
// file wins, so a guess that names nothing costs nothing.
export type Mention = string[]

// A run of characters that can be a path, ending in .md. Whitespace, quotes, brackets, shell punctuation and Chinese
// punctuation end it; a colon too, so `x.md:12` is x.md. A further suffix (.mdx, .md.bak) makes it not Markdown.
const PATH = /[^\s'"`()<>[\]{}|;,:*?!#，。、：；（）「」【】《》！？“”‘’]+\.md(?![\w-]|\.\w)/gi

// Text glued to a path without a space, as Chinese prose does ("报告在/tmp/r.md"): offer the path from its first
// slash as well, or from the ~ just before it. Only when what comes before is not plain ASCII, so docs/a.md stays one.
const spellings = (token: string): Mention => {
  const slash = token.indexOf('/')
  if (slash <= 0 || /^[\x21-\x7e]*$/.test(token.slice(0, slash))) return [token]
  const start = token[slash - 1] === '~' ? slash - 1 : slash
  return start === 0 ? [token] : [token, token.slice(start)]
}

export const mentionsIn = (text: string): Mention[] => [...text.matchAll(PATH)].map(m => spellings(m[0]))

// Every mention in the conversation, oldest first: what each message says, and the files its tool calls name.
export const mentionsOf = (messages: readonly SessionMessage[]): Mention[] =>
  messages.flatMap(message => [
    ...mentionsIn(message.text),
    ...message.toolUses.flatMap(use => {
      const { file_path: file, command } = use.input
      return [
        ...(typeof file === 'string' && /\.md$/i.test(file) ? [[file]] : []),
        ...(typeof command === 'string' ? mentionsIn(command) : []),
      ]
    }),
    ...(message.toolResults ?? []).flatMap(result => mentionsIn(result.text)),
  ])

// Folds . and .. in an absolute path.
const fold = (path: string): string => {
  const parts: string[] = []
  for (const part of path.split('/')) {
    if (part === '' || part === '.') continue
    if (part === '..') parts.pop()
    else parts.push(part)
  }
  return `/${parts.join('/')}`
}

// The absolute path a spelling names, or null when it cannot be known (~ with no HOME, another user's ~name).
export const resolve = (spelling: string, where: Where): string | null => {
  if (spelling.startsWith('/')) return fold(spelling)
  if (spelling.startsWith('~')) {
    if (!spelling.startsWith('~/') || where.home === undefined) return null
    return fold(`${where.home}/${spelling.slice(2)}`)
  }
  return fold(`${where.cwd}/${spelling}`)
}

// The path as the list shows it: the home directory as ~.
export const tilde = (path: string, home: string | undefined): string =>
  home !== undefined && home !== '/' && path.startsWith(`${home}/`) ? `~${path.slice(home.length)}` : path
