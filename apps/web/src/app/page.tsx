import { screenshots } from "@/lib/screenshots";
import Image from "next/image";
import Link from "next/link";
import { ArrowUpRightIcon, ArrowRightIcon, AppleLogoIcon, GithubLogoIcon, DownloadSimpleIcon, ShieldCheckIcon, CommandIcon, NewspaperIcon, CheckIcon } from "@phosphor-icons/react/dist/ssr";
import { Brand } from "@/components/Brand";
import { ThemeToggle } from "@/components/ThemeToggle";
import { ProductTour, Reveal } from "@/components/ProductTour";
import { site } from "@/lib/site";
import { ToolMarquee } from "@/components/ToolMarquee";

function Download({ className = "button primary" }: { className?: string }) {
  return <a className={className} href={site.download} download><AppleLogoIcon size={21} weight="fill" />Download for Mac<ArrowDown /></a>;
}
function ArrowDown() { return <DownloadSimpleIcon size={18} />; }

export default function Home() {
  return <>
    <a href="#main" className="skip-link">Skip to content</a>
    <header className="site-header wrap"><Brand /><nav aria-label="Main navigation"><a href="#workspace">The workspace</a><a href="#how-it-works">How it works</a><Link href="/press">Press kit</Link></nav><ThemeToggle /><a href={site.download} className="nav-cta" download>Get the app<ArrowUpRightIcon size={15} /></a></header>
    <main id="main">
      <section className="hero wrap">
        <div className="hero-showcase">
          <div className="hero-copy"><p className="eyebrow">A NATIVE HOME FOR YOUR AI TOOLS</p><h1>Your AI tools.<br /><span>All in one place.</span></h1><p className="hero-description">See what’s installed, find your next harness, and stay on top of updates from one simple Mac app.</p><div className="hero-actions"><Download /><a className="hero-source-link" href={site.repository}>Free and open source <ArrowUpRightIcon size={15} /></a></div><div className="hero-availability"><AppleLogoIcon size={15} weight="fill" /> macOS 14 or later <span>·</span> Apple silicon and Intel</div></div>
          <ProductTour />
        </div>
      </section>
      <ToolMarquee />
      <section className="workspace-section wrap section-space" id="workspace">
        <Reveal className="section-heading"><p className="eyebrow">LESS MANAGING. MORE MAKING.</p><h2>A clearer head.<br /><span>A tidier toolbox.</span></h2><p>The tools keep coming. Give them a home that makes sense.</p></Reveal>
        <div className="feature-spread"><Reveal className="discover-feature"><div className="feature-copy"><span className="feature-number">01 / DISCOVER</span><h3>Meet your next<br />favorite tool.</h3><p>Claude Code, Codex, Gemini CLI, and more. Browse the catalog, see your install options, and try something new.</p></div><div className="feature-screen"><Image src={screenshots.discover} alt="Discover screen of the actual Mac app, with logos and install options" width={2400} height={1600} sizes="(max-width: 768px) 90vw, 750px" /></div></Reveal>
        <Reveal className="control-feature"><ShieldCheckIcon size={32} weight="light" /><span className="feature-number">02 / YOUR CALL</span><h3>No mystery<br />commands.</h3><p>Know what needs an update. Review the exact command. Decide when it runs.</p><div className="control-list"><div><CheckIcon /> See installed versions</div><div><CheckIcon /> Compare available updates</div><div><CheckIcon /> Review before running</div></div><a href="#how-it-works" className="text-link">A workflow you can trust <ArrowRightIcon size={17} /></a></Reveal></div>
        <Reveal className="under-the-hood"><div><CommandIcon size={28} weight="light" /><h3>The rest of your setup,<br />in plain sight.</h3><p>See provider configuration, MCP servers, skills, and running processes alongside the tools that use them.</p></div><div className="setup-links"><span>Providers <span>Local configuration signals</span></span><span>MCP servers <span>Your tools’ connections</span></span><span>Skills <span>Reusable instructions</span></span><span>Processes <span>What’s running, and where</span></span></div></Reveal>
      </section>
      <section className="briefing-section" id="news"><div className="wrap briefing-grid"><Reveal className="briefing-copy"><NewspaperIcon size={32} weight="light" /><p className="eyebrow">THE HARNESS BRIEFING</p><h2>Beyond<br />the changelog.</h2><p>New harnesses. Useful ideas. The story behind the release. Keep up with the ecosystem without keeping twenty tabs open.</p><div className="source-types"><span>Publisher news</span><span>Community finds</span><span>Official releases</span></div><p className="small-copy">From OpenAI, Google Developers, Simon Willison, Hacker News, and project releases. Every story links to its source.</p></Reveal><Reveal className="briefing-image"><Image src={screenshots.news} alt="The native news page with sourced harness articles and a source filter" width={2400} height={1600} sizes="(max-width: 768px) 96vw, 850px" /><span>Real articles. Real sources. Read in the app.</span></Reveal></div></section>
      <section className="how-section wrap section-space" id="how-it-works"><Reveal className="section-heading"><p className="eyebrow">AT HOME ON YOUR MAC</p><h2>From download<br /><span>to a little more order.</span></h2></Reveal><div className="steps"><Reveal><span>01</span><h3>Make yourself at home.</h3><p>Download the app, drag it to Applications, and open your new workspace.</p></Reveal><Reveal><span>02</span><h3>See what you already have.</h3><p>Harness Manager finds supported tools and configuration on your Mac.</p></Reveal><Reveal><span>03</span><h3>Take it from there.</h3><p>Discover a tool, review an update, or catch up on the latest. You’re in control.</p></Reveal></div></section>
      <section className="open-source wrap"><GithubLogoIcon size={40} weight="light" /><div><h3>Made for you. Open to everyone.</h3><p>Free to use, inspect, and make your own. Licensed under Apache 2.0.</p></div><a href={site.repository} className="text-link">Explore the source <ArrowUpRightIcon size={17} /></a></section>
      <section className="download-section wrap" id="install"><Reveal><Image src="/brand/app-icon.png" alt="Harness Manager app icon" width={96} height={96} /><h2>A home for<br />your next great idea.</h2><p>Start with a tidier toolbox.</p><Download /><div className="download-meta">macOS 14+ · Apple silicon & Intel · v{site.version}</div><p className="release-note">Early preview. This build is not yet notarized.<br />macOS may require approval in Privacy & Security on first launch.</p></Reveal></section>
    </main>
    <footer className="site-footer wrap"><Brand /><p>A little more order for the way you build.</p><div><a href={site.repository}>GitHub <ArrowUpRightIcon size={13} /></a><Link href="/press">Press kit</Link><Link href="/privacy">Privacy</Link></div></footer>
  </>;
}
