import { useEffect, useRef, useState, type ReactNode } from "react";
import { cn } from "@/lib/utils";

/** Fades content in once it enters the viewport. CSS honours prefers-reduced-motion. */
export function useInView<T extends Element>(threshold = 0.15) {
  const ref = useRef<T>(null);
  const [visible, setVisible] = useState(false);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    if (!("IntersectionObserver" in window)) return setVisible(true);
    const io = new IntersectionObserver(([e]) => { if (e?.isIntersecting) { setVisible(true); io.disconnect(); } }, { threshold });
    io.observe(el);
    return () => io.disconnect();
  }, [threshold]);
  return { ref, visible };
}

export function Reveal({ children, className, delay = 0 }: { children: ReactNode; className?: string; delay?: number }) {
  const { ref, visible } = useInView<HTMLDivElement>();
  return (
    <div ref={ref} data-visible={visible} style={{ transitionDelay: `${delay}ms` }} className={cn("reveal", className)}>
      {children}
    </div>
  );
}
