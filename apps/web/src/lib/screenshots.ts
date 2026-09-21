// Static imports give each native capture a content hash, so updated screenshots
// cannot be confused with an older image in Next's optimization cache.
import workspace from "../../public/screenshots/workspace.png";
import discover from "../../public/screenshots/discover.png";
import updates from "../../public/screenshots/updates.png";
import providers from "../../public/screenshots/providers.png";
import processes from "../../public/screenshots/processes.png";
import news from "../../public/screenshots/news.png";
import benchmarks from "../../public/screenshots/benchmarks.png";
import rankingsCoding from "../../public/screenshots/rankings-coding.png";
import rankingsDesign from "../../public/screenshots/rankings-design.png";
import type { StaticImageData } from "next/image";
export const screenshots: Record<string, StaticImageData> = { workspace, discover, updates, providers, processes, news, benchmarks, "rankings-coding": rankingsCoding, "rankings-design": rankingsDesign };
