import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTS from "eslint-config-next/typescript";
export default defineConfig([...nextVitals, ...nextTS, globalIgnores([".next/**", "next-env.d.ts"])]);
