"use client";

import Image from "next/image";
import { useState } from "react";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { ArrowUpRightIcon, ArrowRightIcon, PlusIcon, CodeIcon, PaletteIcon, BrainIcon } from "@phosphor-icons/react";
import { screenshots } from "@/lib/screenshots";
import { rankingGroups } from "@/lib/site";

const examples = [
  { id: "coding", label: "Coding", icon: CodeIcon, image: "rankings-coding", title: "A better starting point for your next build.", copy: "Compare coding models, then dig into agents, tool calling, full-stack apps, and more. Find a shortlist that fits the work.", alt: "Actual Harness Manager Benchmarks page: Coding rankings with model scores, comparison chart, and collection navigation" },
  { id: "design", label: "Design", icon: PaletteIcon, image: "rankings-design", title: "Give your next interface the right model.", copy: "Explore design rankings, with separate collections for UI components, data visualization, SVG, and 3D available in the app.", alt: "Actual Harness Manager Benchmarks page: Design rankings with published scores and model comparison chart" },
  { id: "intelligence", label: "Intelligence", icon: BrainIcon, image: "benchmarks", title: "See how the leading models compare.", copy: "Start with intelligence. Explore reasoning, math, science, and writing when your next task calls for something more specific.", alt: "Actual Harness Manager Benchmarks page: Smartest collection with intelligence scores and ranked models" },
];

export function RankingsShowcase() {
  const [active, setActive] = useState(0);
  const reduce = useReducedMotion();
  const item = examples[active];
  return <div className="rankings-showcase">
    <div className="rankings-toolbar">
      <div className="rankings-tabs" role="tablist" aria-label="Preview model rankings">
        {examples.map((example, index) => <button key={example.id} type="button" role="tab" id={`ranking-tab-${example.id}`} aria-selected={active === index} aria-controls="ranking-preview" tabIndex={active === index ? 0 : -1}
          onClick={() => setActive(index)} onKeyDown={event => {
            const next = event.key === "ArrowRight" ? (index + 1) % examples.length : event.key === "ArrowLeft" ? (index + examples.length - 1) % examples.length : event.key === "Home" ? 0 : event.key === "End" ? examples.length - 1 : undefined;
            if (next !== undefined) { event.preventDefault(); setActive(next); document.getElementById(`ranking-tab-${examples[next].id}`)?.focus(); }
          }}><example.icon size={19} weight={active === index ? "fill" : "regular"} />{example.label}</button>)}
      </div>
      <span className="rankings-preview-label">Inside the Mac app</span>
    </div>
    <div className="rankings-preview" id="ranking-preview" role="tabpanel" aria-labelledby={`ranking-tab-${item.id}`} tabIndex={0}>
      <div className="rankings-screen">
        <AnimatePresence initial={false} mode="wait">
          <motion.div key={item.id} initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={{ duration: reduce ? 0 : .15 }}>
            <a href={`/screenshots/${item.image}.png`} target="_blank" rel="noreferrer" aria-label={`Open full-size ${item.label.toLowerCase()} screenshot`}>
              <Image src={screenshots[item.image]} alt={item.alt} sizes="(max-width: 768px) 94vw, (max-width: 1100px) 90vw, 970px" />
            </a>
          </motion.div>
        </AnimatePresence>
      </div>
      <div className="rankings-context">
        <h3>{item.title}</h3><p>{item.copy}</p>
        <dl className="rankings-stats"><div><dt>Ranked collections</dt><dd>31</dd></div><div><dt>Comparison metrics</dt><dd>7</dd></div></dl>
        <a className="text-link" href="#install">Find your next model <ArrowRightIcon size={17} /></a>
      </div>
    </div>
    <div className="rankings-provenance"><p>Real app captures. Rankings change as the data updates.</p><a href="https://modelgrep.com" target="_blank" rel="noreferrer">Data by Modelgrep <ArrowUpRightIcon size={13} /></a></div>
    <details className="rankings-collections">
      <summary><span>From coding to creative work.<strong>See all 31 ranking collections</strong></span><PlusIcon size={22} /></summary>
      <div className="rankings-group-grid">{rankingGroups.map(group => <div key={group.name}><h3>{group.name}</h3><ul>{group.collections.map(collection => <li key={collection}>{collection}</li>)}</ul></div>)}</div>
      <p className="rankings-method">Browse these collections in the app. Compare individual metrics including intelligence, coding, agentic performance, design, speed, latency, and context. Rankings are a starting point; results depend on your task.</p>
    </details>
  </div>;
}
