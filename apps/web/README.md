# Harness Manager website

Next.js 16, React 19, Geist, Phosphor icons, and Motion. A download-first, responsive product site with a user-controlled native screenshot tour, light/dark themes, and press assets.

```sh
npm ci
npm run dev
npm run lint
npm run build
```

Before the production build, run `make package` from the repository root or configure `NEXT_PUBLIC_DOWNLOAD_URL` with a real published HTTPS download. The build fails if no download is available.

Refresh app imagery with root `make native-shots`. All site and press images import the real native captures from `public/screenshots`. Use `make gallery PORT=3000` to export the six press layouts.

No accounts, forms, analytics, or remote app control. Native installation and updates happen only inside the Mac app.
