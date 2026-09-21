"use client";

import Image from "next/image";
import { useState } from "react";
import { PauseIcon, PlayIcon } from "@phosphor-icons/react";
import { tools } from "@/lib/site";

export function ToolMarquee() {
  const [paused, setPaused] = useState(false);

  return <section className="tool-marquee wrap" aria-label="Supported harnesses and meta harnesses">
    <div className="marquee-heading">
      <p>Your favorites. <strong>And your next favorites.</strong></p>
      <button className="marquee-toggle" aria-label={paused ? "Play scrolling logos" : "Pause scrolling logos"} aria-pressed={paused} onClick={() => setPaused(value => !value)}>
        {paused ? <PlayIcon size={16} weight="fill" /> : <PauseIcon size={16} weight="fill" />}
      </button>
    </div>
    <div className="marquee-viewport">
      <div className="marquee-track" data-paused={paused}>
        {[0, 1].map(copy => <ul className="marquee-group" key={copy} aria-hidden={copy === 1 ? true : undefined}>
          {tools.map(tool => <li key={tool.id}><Image src={`/tools/${tool.id}.png`} alt="" width={56} height={56} sizes="56px" /><span>{tool.name}</span></li>)}
        </ul>)}
      </div>
    </div>
  </section>;
}
