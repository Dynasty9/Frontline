import { CaretDownIcon, SignOutIcon, UserCircleIcon, UserGearIcon } from "@phosphor-icons/react"
import { Link } from "react-router"
import { InsigniaImg } from "@/components/insignia-img"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { useAccount } from "@/lib/account"
import { rankName, wornInsignia } from "@/lib/insignia"

/**
 * The header's account button. Signed out it's the way to sign in; signed in
 * it's your insignia, callsign and rank, and a menu: your account, signing out.
 */
export function AccountMenu() {
  const { user, signOut } = useAccount()
  if (!user) {
    return (
      <Button variant="ghost" size="sm" asChild className="text-sm text-muted-foreground hover:text-foreground">
        <Link to="/account" aria-label="Sign in">
          <UserCircleIcon />
          <span className="hidden lg:inline">Sign in</span>
        </Link>
      </Button>
    )
  }
  const worn = wornInsignia(user.icon)
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        {/* its name is what it shows, said in full: "Your account: Raven rank 6" */}
        <Button variant="outline" size="sm" className="h-8 gap-2 pr-1.5 pl-1 text-sm">
          {worn && <InsigniaImg id={worn.id} />}
          <span className="sr-only">Your account:</span>
          {/* the callsign only where there's room for it beside the nav (a screen reader always has it) */}
          <span className="sr-only max-w-36 truncate sm:not-sr-only md:sr-only lg:not-sr-only">{user.callsign}</span>
          <span className="sr-only">rank</span>
          <span className="border border-primary/40 px-1 text-[10px] leading-4 font-bold text-primary tabular-nums">
            {user.rank}
          </span>
          <CaretDownIcon className="size-3 text-muted-foreground" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-56">
        <DropdownMenuLabel className="flex items-center gap-2.5 py-2">
          {worn && <InsigniaImg id={worn.id} className="size-8" />}
          <span className="min-w-0">
            <span className="block truncate text-sm font-semibold text-foreground">{user.callsign}</span>
            <span className="block text-[11px] font-bold tracking-[0.12em] text-primary uppercase">
              {rankName(user.rank)}
            </span>
          </span>
        </DropdownMenuLabel>
        <DropdownMenuSeparator />
        <DropdownMenuItem asChild>
          <Link to="/account">
            <UserGearIcon />
            Account and insignia
          </Link>
        </DropdownMenuItem>
        <DropdownMenuItem onSelect={signOut}>
          <SignOutIcon />
          Sign out
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}
