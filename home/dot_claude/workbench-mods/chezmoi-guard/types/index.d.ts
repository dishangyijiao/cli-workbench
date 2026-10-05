export type Drift = { status: string; path: string }[]

declare module 'claude-code' {
  interface PluginState {
    'chezmoi-guard': { drift: Drift }
  }
}
