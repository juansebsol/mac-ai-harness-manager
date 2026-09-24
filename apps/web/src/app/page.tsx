import { screenshots } from "@/lib/screenshots";
import Image from "next/image";
import Link from "next/link";
import { ArrowUpRightIcon, ArrowRightIcon, AppleLogoIcon, GithubLogoIcon, DownloadSimpleIcon, ShieldCheckIcon, CommandIcon, NewspaperIcon, CheckIcon } from "@phosphor-icons/react/dist/ssr";
import { Brand } from "@/components/Brand";
import { ProductTour, Reveal } from "@/components/ProductTour";
import { site } from "@/lib/site";
import { ToolMarquee } from "@/components/ToolMarquee";
import { RankingsShowcase } from "@/components/RankingsShowcase";

function Download({ className = "button primary" }: { className?: string }) {
  return <a className={className} href={site.download} download><AppleLogoIcon size={21} weight="fill" />Download for Mac<ArrowDown /></a>;
}
function ArrowDown() { return <DownloadSimpleIcon size={18} />; }

export default function Home() {
  return <>
    <a href="#main" className="skip-link">Skip to content</a>
    <header className="site-header wrap"><Brand /><nav aria-label="Main navigation"><a href="#workspace">The workspace</a><a href="#benchmarks">Rankings</a><a href="#how-it-works">How it works</a><Link href="/press">Press kit</Link></nav><a href={site.repository} className="nav-cta github-cta" target="_blank" rel="noreferrer"><GithubLogoIcon size={16} /><span>Star on GitHub</span></a><a href={site.download} className="nav-cta" download>Get the app<ArrowUpRightIcon size={15} /></a></header>
    <main id="main">
      <section className="hero wrap">
        <div className="hero-showcase">
          <div className="hero-copy"><p className="eyebrow">THE MAC APP FOR YOUR AI STACK</p><h1>Your AI stack.<br /><span>Under control.</span></h1><p className="hero-description">Manage your coding tools, discover skills and MCPs, and compare models. One native Mac app. Free and open source.</p><div className="hero-actions"><Download /></div><div className="hero-availability"><AppleLogoIcon size={15} weight="fill" /> macOS 14 or later <span>·</span> Apple silicon and Intel</div></div>
          <ProductTour />
        </div>
      </section>
      <ToolMarquee />
      <section className="workspace-section wrap section-space" id="workspace">
        <Reveal className="section-heading"><h2>Less setup to manage.<br /><span>More space to build.</span></h2><p>Your tools, connections, and updates. Together, where you can see them.</p></Reveal>
        <div className="feature-spread"><Reveal className="discover-feature"><div className="feature-copy"><h3>Find the next piece<br />of your workflow.</h3><p>Browse harnesses, MCPs, and skills by popularity. From Claude Code and Codex to the tools you haven’t tried yet.</p></div><div className="feature-screen"><Image src={screenshots.discover} alt="Discover screen of the actual Mac app, with logos and install options" width={2400} height={1600} sizes="(max-width: 768px) 90vw, 750px" /></div></Reveal>
        <Reveal className="control-feature"><ShieldCheckIcon size={32} weight="light" /><h3>Your updates.<br />Your call.</h3><p>See what needs an update, review the command, and decide when it runs.</p><div className="control-list"><div><CheckIcon /> See installed versions</div><div><CheckIcon /> Compare available updates</div><div><CheckIcon /> Review before running</div></div><a href="#how-it-works" className="text-link">See how it works <ArrowRightIcon size={17} /></a></Reveal></div>
        <Reveal className="under-the-hood"><div><CommandIcon size={28} weight="light" /><h3>The rest of your setup,<br />in plain sight.</h3><p>See provider configuration, MCP servers, skills, and running processes alongside the tools that use them.</p></div><div className="setup-links"><span>Providers <span>Local configuration signals</span></span><span>MCP servers <span>Your tools’ connections</span></span><span>Skills <span>Reusable instructions</span></span><span>Processes <span>What’s running, and where</span></span></div></Reveal>
      </section>
      <section className="rankings-section" id="benchmarks" aria-labelledby="rankings-heading"><div className="wrap">
        <Reveal className="rankings-heading"><p className="eyebrow">BENCHMARKS & RANKINGS</p><h2 id="rankings-heading">Compare models.<br /><span>Find your next fit.</span></h2><p>Coding, design, reasoning, local models. Compare the options for the work you actually do, right alongside your tools.</p></Reveal>
        <Reveal><RankingsShowcase /></Reveal>
      </div></section>
      <section className="briefing-section" id="news"><div className="wrap briefing-grid"><Reveal className="briefing-copy"><NewspaperIcon size={32} weight="light" /><p className="eyebrow">THE HARNESS BRIEFING</p><h2>Beyond<br />the changelog.</h2><p>New harnesses. Useful ideas. The story behind the release. Keep up with the ecosystem without keeping twenty tabs open.</p><div className="source-types"><span>Publisher news</span><span>Community finds</span><span>Official releases</span></div><p className="small-copy">From OpenAI, Google Developers, Simon Willison, Hacker News, and project releases. Every story links to its source.</p></Reveal><Reveal className="briefing-image"><Image src={screenshots.news} alt="The native news page with sourced harness articles and a source filter" width={2400} height={1600} sizes="(max-width: 768px) 96vw, 850px" /><span>Real articles. Real sources. Read in the app.</span></Reveal></div></section>
      <section className="how-section wrap section-space" id="how-it-works"><Reveal className="section-heading"><h2>Bring your tools.<br /><span>We’ll help you keep track.</span></h2></Reveal><div className="steps"><Reveal><span>01</span><h3>Download. Drag. Open.</h3><p>Move Harness Manager to Applications and open your workspace. No build tools required.</p></Reveal><Reveal><span>02</span><h3>See your existing stack.</h3><p>Find supported tools and configuration already on your Mac, together in one view.</p></Reveal><Reveal><span>03</span><h3>Make your next move.</h3><p>Review an update, discover a skill, or compare models for your next project.</p></Reveal></div></section>
      <section className="open-source wrap"><GithubLogoIcon size={40} weight="light" /><div><h3>Made for you. Open to everyone.</h3><p>Free to use, inspect, and make your own. Licensed under Apache 2.0. If Harness Manager helps you keep your stack moving, give the project a star on GitHub.</p></div><a href={site.repository} className="text-link" target="_blank" rel="noreferrer">Star on GitHub <ArrowUpRightIcon size={17} /></a></section>
      <section className="download-section wrap" id="install"><Reveal><Image src="/brand/app-icon.png" alt="Harness Manager app icon" width={96} height={96} /><h2>Your stack, sorted.<br /><span>Back to building.</span></h2><p>One workspace for your AI tools. Free and open source.</p><Download /><a className="download-product-hunt" href={site.productHuntUrl} target="_blank" rel="noopener noreferrer"><span>Find us on Product Hunt</span><img alt="Harness Manager — featured on Product Hunt" width="250" height="54" src={site.productHuntBadge} /></a><div className="download-meta">macOS 14+ · Apple silicon & Intel</div><p className="release-note">Early preview. This build is not yet notarized.<br />macOS may require approval in Privacy & Security on first launch.</p></Reveal></section>
    </main>
    <footer className="site-footer wrap"><Brand /><p>The Mac workspace for your AI stack.</p><div><a href={site.repository}>GitHub <ArrowUpRightIcon size={13} /></a><Link href="/press">Press kit</Link><Link href="/privacy">Privacy</Link></div></footer>
  </>;
}
