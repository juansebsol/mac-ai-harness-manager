"use client";
import { MoonIcon, SunIcon } from "@phosphor-icons/react";
import { useState } from "react";
export function ThemeToggle() {
  const [dark, setDark] = useState(false);
  return <button className="theme-toggle" aria-label={dark ? "Switch to light theme" : "Switch to dark theme"} onClick={() => {
    setDark(!dark);
    document.documentElement.dataset.theme = dark ? "light" : "dark";
  }}>{dark ? <SunIcon size={18} /> : <MoonIcon size={18} />}</button>;
}
