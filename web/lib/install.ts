export type NudgeKind = "ios" | "prompt" | "none";
export function shouldShowNudge(i: { standalone: boolean; dismissed: boolean; isIOS: boolean; canPrompt: boolean }): NudgeKind {
  if (i.standalone || i.dismissed) return "none";
  if (i.isIOS) return "ios";
  return i.canPrompt ? "prompt" : "none";
}
