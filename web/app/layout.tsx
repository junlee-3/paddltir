import type { Metadata, Viewport } from "next";
import { Inter_Tight } from "next/font/google";
import "./globals.css";
import { RegisterServiceWorker } from "@/components/RegisterServiceWorker";

const interTight = Inter_Tight({ subsets: ["latin"], variable: "--font-inter-tight", display: "swap" });

export const metadata: Metadata = {
  title: { default: "Paddltir", template: "%s · Paddltir" },
  applicationName: "Paddltir",
  description: "Your crew, your seat, your next race.",
  appleWebApp: { capable: true, statusBarStyle: "default", title: "Paddltir" },
  icons: { apple: "/icons/apple-touch-icon.png" },
};

export const viewport: Viewport = {
  themeColor: "#FAFAFA",
  colorScheme: "light",
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={interTight.variable}>
      <body className="min-h-dvh bg-bg text-ink">
        {children}
        <RegisterServiceWorker />
      </body>
    </html>
  );
}
