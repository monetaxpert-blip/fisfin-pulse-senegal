import logo from "@/assets/fisfin-logo.png";
import { cn } from "@/lib/utils";

/** Official FISFIN logo (unaltered, background removed). Placed on a light surface to keep its original colors. */
export function Logo({ className }: { className?: string }) {
  return <img src={logo} alt="FISFIN — Votre gestion simplifiée" className={cn("h-auto select-none", className)} draggable={false} />;
}

export function LogoBadge({ className }: { className?: string }) {
  return (
    <div className={cn("rounded-xl bg-card px-4 py-3 shadow-card", className)}>
      <Logo className="mx-auto w-32" />
    </div>
  );
}
