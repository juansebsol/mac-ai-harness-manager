import { screenshots } from "@/lib/screenshots";
import Image from "next/image";
import Link from "next/link";
import { Brand } from "@/components/Brand";
import { slides } from "@/lib/site";
export const metadata = { title: "Press kit" };
export default function Press() {
  return <main className="press-page wrap">
    <Brand /><h1>Your AI stack. Under control.</h1>
    <p>Harness Manager is a free, open-source Mac workspace for AI tools, MCPs, skills, updates, and model rankings. These seven slides show the actual SwiftUI app. Workspace data is illustrative; model rankings are real Modelgrep results at capture time.</p>
    <div className="gallery-index">{slides.map(s => <Link href={`/press/gallery/${s.id}`} key={s.id}>
      <div className="press-thumbnail"><Image src={screenshots[s.view]} alt={`Native ${s.name} screen`} width={600} height={400} /></div>
      <span>{s.id} / {s.name}</span><h2>{s.title.replace("\n", " ")}</h2><p>{s.description}</p>
    </Link>)}</div>
    <div className="press-download"><Image src="/brand/app-icon.png" alt="Harness Manager app icon" width={80} height={80} /><div><h2>The app icon</h2><p>Graphite, ivory, and a little orange.</p><a className="text-link" href="/brand/app-icon.png" download="harness-manager-icon.png">Download PNG</a></div></div>
    <div className="press-download"><div><h2>Native screenshots</h2><p>Full resolution captures, exactly as rendered by the app.</p>
      {Object.keys(screenshots).map(id => <p key={id}><a className="text-link" href={`/screenshots/${id}.png`} download>Download {id.replaceAll("-", " ")} PNG</a></p>)}
    </div></div>
  </main>;
}
