import { Link } from "@tanstack/react-router";
import logo from "@/assets/fisfin-logo.png";
import { cn } from "@/lib/utils";

/** Official FISFIN logo (unaltered, background removed, original proportions kept). */
export function Logo({ className }: { className?: string }) {
  return <img src={logo} alt="FISFIN, votre gestion simplifiée" width={600} height={557} className={cn("h-auto w-auto select-none", className)} draggable={false} />;
}

/** Logo on a light surface (keeps its original colors on dark backgrounds), linking to the home page. */
export function LogoLink({ className, imgClassName, surface = true }: { className?: string; imgClassName?: string; surface?: boolean }) {
  return (
    <Link
      to="/"
      aria-label="FISFIN, retour à l'accueil"
      className={cn(
        "inline-flex shrink-0 items-center justify-center rounded-xl transition-opacity hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2",
        surface && "bg-card px-2.5 py-1 shadow-card",
        className,
      )}
    >
      <Logo className={cn("h-12", imgClassName)} />
    </Link>
  );
}
