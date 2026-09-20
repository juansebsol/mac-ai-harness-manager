import { existsSync } from 'node:fs';
// Fail the deployment instead of quietly shipping a dead download button.
if (!process.env.NEXT_PUBLIC_DOWNLOAD_URL?.startsWith('https://') && !existsSync(new URL('../public/downloads/Harness-Manager.dmg', import.meta.url))) {
  console.error('Missing Mac download. Run make package from the repository root, or set NEXT_PUBLIC_DOWNLOAD_URL to a published HTTPS release asset.');
  process.exit(1);
}
