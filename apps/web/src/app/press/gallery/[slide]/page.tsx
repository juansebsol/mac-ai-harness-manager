import { screenshots } from "@/lib/screenshots";
import Image from "next/image";
import { notFound } from "next/navigation";
import { Brand } from "@/components/Brand";
import { slides } from "@/lib/site";
export const dynamicParams = false;
export function generateStaticParams() { return slides.map(s => ({ slide: s.id })); }
export default async function GallerySlide({ params }: { params: Promise<{ slide: string }> }) {
  const { slide } = await params;
  const item = slides.find(s => s.id === slide);
  if (!item) notFound();
  return <main className={`gallery-canvas gallery-${slide}`}><header className="gallery-header"><Brand /><span>Free. Open source. Native to your Mac.</span></header><div className="gallery-body"><div className="gallery-copy"><p className="eyebrow">{item.label}</p><h1>{item.title}</h1><p>{item.description}</p></div><div className="gallery-product"><Image src={screenshots[item.view]} alt={`Harness Manager native ${item.name} screen`} width={2400} height={1600} priority unoptimized /></div></div><footer className="gallery-footer"><span>Harness Manager for macOS</span><span>Actual app · Sample workspace</span><span>{item.id} / 06</span></footer></main>;
}
