import type { Metadata } from "next";
import { Nunito, Nunito_Sans } from "next/font/google";
import {
  ClerkProvider,
  SignInButton,
  SignUpButton,
  SignedIn,
  SignedOut,
  UserButton,
} from "@clerk/nextjs";
import Link from "next/link";
import { BookOpen, Sparkles } from "lucide-react";
import { Button } from "@/components/ui/button";
import { MobileNav } from "@/components/layout/MobileNav";
import "./globals.css";

const nunito = Nunito({
  subsets: ["latin"],
  variable: "--font-nunito",
  display: "swap",
});

const nunitoSans = Nunito_Sans({
  subsets: ["latin"],
  variable: "--font-nunito-sans",
  display: "swap",
});

export const metadata: Metadata = {
  title: {
    default: "Questionless — AI-Powered UK Exam Practice",
    template: "%s | Questionless",
  },
  description:
    "Free AI-powered practice tests for UK public exams. Life in the UK, Driving Theory, CSCS, and more. Pass your exam with confidence using smart spaced repetition.",
  keywords: [
    "life in the uk test",
    "uk citizenship test",
    "driving theory test",
    "cscs test",
    "uk exam practice",
    "british citizenship",
    "exam preparation",
    "practice questions",
    "mock exam",
    "spaced repetition",
  ],
  authors: [{ name: "Questionless" }],
  openGraph: {
    type: "website",
    locale: "en_GB",
    url: "https://question.uk",
    siteName: "Questionless",
    title: "Questionless — AI-Powered UK Exam Practice",
    description:
      "Free AI-powered practice tests for UK public exams. Pass with confidence using smart spaced repetition.",
    images: [
      {
        url: "https://question.uk/og-image.png",
        width: 1200,
        height: 630,
        alt: "Questionless — AI-Powered UK Exam Practice",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "Questionless — AI-Powered UK Exam Practice",
    description:
      "Free AI-powered practice tests for UK public exams. Pass with confidence.",
    images: ["https://question.uk/og-image.png"],
  },
  metadataBase: new URL("https://question.uk"),
  alternates: {
    canonical: "https://question.uk",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <ClerkProvider>
      <html lang="en" className={`${nunito.variable} ${nunitoSans.variable}`}>
        <body className="min-h-screen flex flex-col font-sans antialiased">
          <a href="#main-content" className="skip-link">
            Skip to main content
          </a>
          <Header />
          <div id="main-content" className="flex-1">
            {children}
          </div>
          <Footer />
        </body>
      </html>
    </ClerkProvider>
  );
}

function Header() {
  return (
    <header className="sticky top-0 z-50 border-b bg-white/80 backdrop-blur-lg supports-[backdrop-filter]:bg-white/60">
      <nav className="container mx-auto px-4 h-16 flex items-center justify-between">
        <Link
          href="/"
          className="flex items-center gap-2.5 font-bold text-xl group"
        >
          <div className="relative">
            <div className="absolute inset-0 bg-primary/20 rounded-xl blur-lg group-hover:bg-primary/30 transition-colors" />
            <div className="relative bg-gradient-primary p-2 rounded-xl">
              <BookOpen className="h-5 w-5 text-white" />
            </div>
          </div>
          <span className="font-nunito tracking-tight">Questionless</span>
        </Link>

        <div className="hidden md:flex items-center gap-8">
          <NavLink href="/exams">Exams</NavLink>
          <NavLink href="/practice">Practice</NavLink>
          <NavLink href="/pricing">Pricing</NavLink>
        </div>

        <div className="flex items-center gap-3">
          <SignedOut>
            <SignInButton mode="modal">
              <Button variant="ghost" size="sm" className="hidden sm:flex">
                Sign In
              </Button>
            </SignInButton>
            <SignUpButton mode="modal">
              <Button
                size="sm"
                className="btn-clay bg-gradient-primary text-white border-0"
              >
                <Sparkles className="h-4 w-4 mr-1.5" />
                Get Started
              </Button>
            </SignUpButton>
          </SignedOut>

          <SignedIn>
            <Link
              href="/dashboard"
              className="hidden md:flex items-center gap-1.5 text-muted-foreground hover:text-foreground transition-colors font-medium"
            >
              Dashboard
            </Link>
            <UserButton
              afterSignOutUrl="/"
              appearance={{
                elements: {
                  avatarBox: "w-9 h-9 ring-2 ring-primary/20",
                },
              }}
            />
          </SignedIn>

          <MobileNav />
        </div>
      </nav>
    </header>
  );
}

function NavLink({
  href,
  children,
}: {
  href: string;
  children: React.ReactNode;
}) {
  return (
    <Link
      href={href}
      className="relative text-muted-foreground hover:text-foreground transition-colors font-medium group"
    >
      {children}
      <span className="absolute -bottom-1 left-0 w-0 h-0.5 bg-primary rounded-full group-hover:w-full transition-all duration-300" />
    </Link>
  );
}

function Footer() {
  return (
    <footer className="border-t bg-muted/30">
      <div className="container mx-auto px-4 py-12">
        <div className="grid grid-cols-2 md:grid-cols-4 gap-8 mb-10">
          {/* Brand */}
          <div className="col-span-2 md:col-span-1">
            <Link href="/" className="flex items-center gap-2 mb-4">
              <div className="bg-gradient-primary p-1.5 rounded-lg">
                <BookOpen className="h-4 w-4 text-white" />
              </div>
              <span className="font-semibold font-nunito">Questionless</span>
            </Link>
            <p className="text-sm text-muted-foreground leading-relaxed">
              AI-powered practice tests for UK public exams. Study smarter, pass
              faster.
            </p>
          </div>

          {/* Product */}
          <div>
            <h4 className="font-semibold font-nunito mb-4 text-sm">Product</h4>
            <ul className="space-y-2.5">
              <FooterLink href="/practice">Practice</FooterLink>
              <FooterLink href="/pricing">Pricing</FooterLink>
              <FooterLink href="/dashboard">Dashboard</FooterLink>
            </ul>
          </div>

          {/* Exams */}
          <div>
            <h4 className="font-semibold font-nunito mb-4 text-sm">Exams</h4>
            <ul className="space-y-2.5">
              <FooterLink href="/exams">All Exams</FooterLink>
              <FooterLink href="/practice">Life in the UK</FooterLink>
              <FooterLink href="/exams">Driving Theory</FooterLink>
              <FooterLink href="/exams">CSCS</FooterLink>
            </ul>
          </div>

          {/* Company */}
          <div>
            <h4 className="font-semibold font-nunito mb-4 text-sm">Company</h4>
            <ul className="space-y-2.5">
              <FooterLink href="/about">About</FooterLink>
              <FooterLink href="/privacy">Privacy</FooterLink>
              <FooterLink href="/terms">Terms</FooterLink>
            </ul>
          </div>
        </div>

        {/* Bottom bar */}
        <div className="border-t pt-6 flex flex-col md:flex-row justify-between items-center gap-4">
          <p className="text-xs text-muted-foreground">
            &copy; {new Date().getFullYear()} Questionless. All rights reserved.
          </p>
          <p className="text-xs text-muted-foreground">
            Made with care for UK exam takers
          </p>
        </div>
      </div>
    </footer>
  );
}

function FooterLink({
  href,
  children,
}: {
  href: string;
  children: React.ReactNode;
}) {
  return (
    <li>
      <Link
        href={href}
        className="text-sm text-muted-foreground hover:text-foreground transition-colors"
      >
        {children}
      </Link>
    </li>
  );
}
