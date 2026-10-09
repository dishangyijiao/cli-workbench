// A Markdown file the conversation mentioned: where it is, and how the list shows it.
export type Found = { path: string; label: string }

declare module 'claude-code' {
  interface PluginState {
    'md-open': { files: Found[] }
  }
}
