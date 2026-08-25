import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Paddltir", short_name: "Paddltir", description: "Your crew, your seat, your next race.",
    start_url: "/", scope: "/", display: "standalone", orientation: "portrait",
    background_color: "#FAFAFA", theme_color: "#FAFAFA",
    icons: [
      { src: "/icons/icon-192.png", sizes: "192x192", type: "image/png" },
      { src: "/icons/icon-512.png", sizes: "512x512", type: "image/png" },
      { src: "/icons/maskable-512.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
    ],
  };
}
