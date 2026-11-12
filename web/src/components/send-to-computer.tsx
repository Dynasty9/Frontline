import { CheckIcon, PaperPlaneTiltIcon } from "@phosphor-icons/react"
import { useState } from "react"
import { Button } from "@/components/ui/button"
import { platformList } from "@/lib/releases"
import { cn } from "@/lib/utils"

/**
 * For a visitor on a phone or tablet, where Frontline doesn't run: send the
 * download page to their computer instead of a download they can't use. The
 * phone's own share sheet (mail it, message it to yourself), or, without one,
 * the link copied to paste wherever.
 */
export function SendToComputer({ className, size = "lg" }: { className?: string; size?: "lg" | "default" }) {
  const [done, setDone] = useState<"shared" | "copied" | "failed" | null>(null)
  const url = `${window.location.origin}/play#download`
  const send = async () => {
    const share = { title: "Frontline", text: `Frontline: free squad tactics for ${platformList()}.`, url }
    try {
      if (navigator.share && (!navigator.canShare || navigator.canShare(share))) {
        await navigator.share(share)
        setDone("shared")
        return
      }
    } catch (error) {
      // closing the share sheet isn't a failure
      if (error instanceof DOMException && error.name === "AbortError") return
    }
    try {
      await navigator.clipboard.writeText(url)
      setDone("copied")
    } catch {
      setDone("failed")
    }
  }
  return (
    <div className={cn("flex flex-col items-start gap-2", className)}>
      <Button
        size={size}
        variant="outline"
        onClick={send}
        className="h-12 border-white/25 bg-black/30 px-6 text-sm font-bold tracking-wider uppercase backdrop-blur-sm"
      >
        <PaperPlaneTiltIcon weight="bold" />
        Send to my computer
      </Button>
      <output className="block min-h-4 text-xs text-muted-foreground">
        {done === "copied" ? (
          <span className="inline-flex items-center gap-1.5 text-good">
            <CheckIcon weight="bold" className="size-3.5" />
            Link copied: open it on your computer
          </span>
        ) : done === "shared" ? (
          <span className="inline-flex items-center gap-1.5 text-good">
            <CheckIcon weight="bold" className="size-3.5" />
            Sent: open it on your computer
          </span>
        ) : done === "failed" ? (
          <>
            On your computer, go to <span className="font-mono text-foreground">{url.replace(/^https?:\/\//, "")}</span>
          </>
        ) : null}
      </output>
    </div>
  )
}
