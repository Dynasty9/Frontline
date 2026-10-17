import {
  CaretDownIcon,
  GlobeHemisphereWestIcon,
  IdentificationBadgeIcon,
  SignOutIcon,
  TrophyIcon,
  UserCircleIcon,
} from "@phosphor-icons/react"
import { Link } from "react-router"
import { PlayerAvatar } from "@/components/player-avatar"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { openSignIn } from "@/hooks/use-sign-in-dialog"
import { pictureOf, useAccount } from "@/lib/account"
import { rankName } from "@/lib/insignia"
import { playerPath } from "@/lib/players"

/**
 * The header's account button. Signed out it opens the sign-in dialog, on
 * whatever page you're on; signed in it's your insignia, callsign and rank,
 * and a menu: your profile, signing out.
 */
export function AccountMenu() {
  const { user, signOut } = useAccount()
  if (!user) {
    return (
      <Button
        variant="ghost"
        size="sm"
        onClick={openSignIn}
        aria-label="Sign in"
        className="text-sm text-muted-foreground hover:text-foreground"
      >
        <UserCircleIcon />
        <span className="hidden lg:inline">Sign in</span>
      </Button>
    )
  }
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        {/* its name is what it shows, said in full: "Your account: Raven rank 6" */}
        <Button variant="outline" size="sm" className="h-8 gap-2 pr-1.5 pl-1 text-sm">
          <PlayerAvatar icon={user.icon} avatar={pictureOf(user)} />
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
          <PlayerAvatar icon={user.icon} avatar={pictureOf(user)} className="size-8" />
          <span className="min-w-0">
            <span className="block truncate text-sm font-semibold text-foreground">{user.callsign}</span>
            <span className="block text-[11px] font-bold tracking-[0.12em] text-primary uppercase">
              {rankName(user.rank)}
            </span>
          </span>
        </DropdownMenuLabel>
        <DropdownMenuSeparator />
        <DropdownMenuItem asChild>
          <Link to="/profile">
            <IdentificationBadgeIcon />
            Your profile
          </Link>
        </DropdownMenuItem>
        <DropdownMenuItem asChild>
          <Link to={playerPath(user.callsign)}>
            <GlobeHemisphereWestIcon />
            Your public page
          </Link>
        </DropdownMenuItem>
        <DropdownMenuItem asChild>
          <Link to="/leaderboards">
            <TrophyIcon />
            Leaderboards
          </Link>
        </DropdownMenuItem>
        <DropdownMenuSeparator />
        <DropdownMenuItem onSelect={signOut}>
          <SignOutIcon />
          Sign out
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}
