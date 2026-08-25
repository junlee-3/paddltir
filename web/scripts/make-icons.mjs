import sharp from "sharp";
import { mkdir } from "node:fs/promises";
const out = new URL("../public/icons/", import.meta.url);
await mkdir(out, { recursive: true });
const jobs = [
  ["icon.svg", "icon-192.png", 192], ["icon.svg", "icon-512.png", 512],
  ["icon.svg", "apple-touch-icon.png", 180], ["maskable.svg", "maskable-512.png", 512],
];
for (const [src, name, size] of jobs) {
  await sharp(new URL(src, import.meta.url).pathname).resize(size, size).png().toFile(new URL(name, out).pathname);
  console.log("wrote", name);
}
