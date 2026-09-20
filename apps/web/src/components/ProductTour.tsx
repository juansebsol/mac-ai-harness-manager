"use client";
import { screenshots } from "@/lib/screenshots";
import Image from "next/image";
import { useEffect, useRef, useState } from "react";
import { AnimatePresence, motion, useInView, useReducedMotion } from "motion/react";
import { PauseIcon, PlayIcon, ArrowRightIcon } from "@phosphor-icons/react";
import { tour } from "@/lib/site";

export function ProductTour() {
  const [active, setActive] = useState(0);
  const [playing, setPlaying] = useState(false);
  const reduce = useReducedMotion();
  const ref = useRef<HTMLDivElement>(null);
  const inView = useInView(ref, { amount: 0.25 });
  useEffect(() => {
    if (!playing || reduce || !inView) return;
    const timer = setInterval(() => {
      if (!document.hidden) setActive(i => (i + 1) % tour.length);
    }, 6500);
    return () => clearInterval(timer);
  }, [playing, reduce, inView]);
  const choose = (i: number) => { setActive(i); setPlaying(false); };
  return <div className="product-tour" ref={ref}>
    <div className="tour-topline"><div role="tablist" aria-label="Explore the app" className="tour-tabs">
      {tour.map((item, i) => <button key={item.id} id={`tab-${item.id}`} role="tab" aria-selected={i === active} aria-controls="tour-panel" tabIndex={i === active ? 0 : -1} onClick={() => choose(i)} onKeyDown={e => {
        const next = e.key === "ArrowRight" ? (active + 1) % tour.length : e.key === "ArrowLeft" ? (active + tour.length - 1) % tour.length : e.key === "Home" ? 0 : e.key === "End" ? tour.length - 1 : undefined;
        if (next !== undefined) { e.preventDefault(); choose(next); document.getElementById(`tab-${tour[next].id}`)?.focus(); }
      }}>{item.label}{i === active && <motion.span className="tab-underline" layoutId="tour-underline" transition={{ duration: reduce ? 0 : .3 }} />}</button>)}
    </div><button className="tour-play" aria-label={playing && !reduce ? "Pause app tour" : "Play app tour"} aria-pressed={playing && !reduce} onClick={() => setPlaying(!playing)} disabled={!!reduce}>{playing && !reduce ? <PauseIcon size={15} weight="fill" /> : <PlayIcon size={15} weight="fill" />}</button></div>
    <div className="tour-stage" id="tour-panel" role="tabpanel" aria-labelledby={`tab-${tour[active].id}`}>
      <AnimatePresence initial={false} mode="wait">
        <motion.div key={tour[active].id} className="native-window" initial={{ opacity: 0, y: reduce ? 0 : 12 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: reduce ? 0 : -8 }} transition={{ duration: reduce ? 0 : .28 }}>
          <Image src={screenshots[tour[active].id]} alt={tour[active].alt} width={2400} height={1600} sizes="(max-width: 768px) 96vw, 1060px" priority={active === 0} fetchPriority={active === 0 ? "high" : "auto"} />
        </motion.div>
      </AnimatePresence>
    </div>
    <div className="tour-caption"><div><strong>{tour[active].title}</strong><p>{tour[active].description}</p></div><span>Actual Mac app · Sample workspace</span><a className="tour-full" href={`/screenshots/${tour[active].id}.png`} target="_blank" rel="noreferrer">View full size <ArrowRightIcon size={15} /></a></div>
  </div>;
}

export function Reveal({ children, className = "" }: { children: React.ReactNode; className?: string }) {
  const reduce = useReducedMotion();
  return <motion.div className={className} initial={false} whileInView={{ opacity: [0.65, 1], y: reduce ? [0, 0] : [22, 0] }} viewport={{ once: true, amount: 0.12 }} transition={{ duration: reduce ? 0 : .65, ease: [.2, .65, .3, 1] }}>{children}</motion.div>;
}
