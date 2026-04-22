"use client";

import { useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  BookOpen,
  Menu,
  X,
  Home,
  Target,
  BarChart3,
  Settings,
  CreditCard,
  LogIn,
  Sparkles,
} from "lucide-react";
import { SignInButton, SignUpButton, SignedIn, SignedOut } from "@clerk/nextjs";
import { Button } from "@/components/ui/button";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
  SheetClose,
} from "@/components/ui/sheet";

const navItems = [
  { href: "/", label: "Home", icon: Home },
  { href: "/practice", label: "Practice", icon: BookOpen },
  { href: "/mock-exam", label: "Mock Exam", icon: Target },
  { href: "/dashboard", label: "Dashboard", icon: BarChart3, authRequired: true },
  { href: "/pricing", label: "Pricing", icon: CreditCard },
  { href: "/settings", label: "Settings", icon: Settings, authRequired: true },
];

export function MobileNav() {
  const [open, setOpen] = useState(false);
  const pathname = usePathname();

  return (
    <Sheet open={open} onOpenChange={setOpen}>
      <SheetTrigger asChild>
        <Button
          variant="ghost"
          size="icon"
          className="md:hidden"
          aria-label="Open navigation menu"
        >
          <Menu className="h-5 w-5" />
        </Button>
      </SheetTrigger>
      <SheetContent side="right" className="w-[300px] sm:w-[350px] p-0">
        <SheetHeader className="p-6 border-b bg-gradient-hero">
          <SheetTitle className="flex items-center gap-2.5">
            <div className="bg-gradient-primary p-2 rounded-xl">
              <BookOpen className="h-5 w-5 text-white" />
            </div>
            <span className="font-nunito font-bold">Questionless</span>
          </SheetTitle>
        </SheetHeader>

        <nav className="flex flex-col p-4">
          <SignedOut>
            <div className="flex flex-col gap-2 mb-6 p-4 bg-muted/50 rounded-2xl">
              <p className="text-sm text-muted-foreground mb-2">
                Sign in to track your progress
              </p>
              <SignInButton mode="modal">
                <Button variant="outline" className="w-full justify-start gap-2">
                  <LogIn className="h-4 w-4" />
                  Sign In
                </Button>
              </SignInButton>
              <SignUpButton mode="modal">
                <Button className="w-full justify-start gap-2 bg-gradient-primary text-white border-0">
                  <Sparkles className="h-4 w-4" />
                  Get Started Free
                </Button>
              </SignUpButton>
            </div>
          </SignedOut>

          <div className="space-y-1">
            {navItems.map((item) => {
              // Skip auth-required items for signed-out users
              if (item.authRequired) {
                return (
                  <SignedIn key={item.href}>
                    <MobileNavLink
                      href={item.href}
                      icon={item.icon}
                      isActive={pathname === item.href}
                      onClick={() => setOpen(false)}
                    >
                      {item.label}
                    </MobileNavLink>
                  </SignedIn>
                );
              }

              return (
                <MobileNavLink
                  key={item.href}
                  href={item.href}
                  icon={item.icon}
                  isActive={pathname === item.href}
                  onClick={() => setOpen(false)}
                >
                  {item.label}
                </MobileNavLink>
              );
            })}
          </div>

          <SignedIn>
            <div className="mt-6 pt-6 border-t">
              <p className="text-xs text-muted-foreground uppercase tracking-wider mb-3 px-3">
                Quick Actions
              </p>
              <SheetClose asChild>
                <Link
                  href="/practice/random"
                  className="flex items-center gap-3 p-3 rounded-xl bg-primary/5 text-primary hover:bg-primary/10 transition-colors"
                >
                  <Sparkles className="h-5 w-5" />
                  <div>
                    <div className="font-medium">Quick Practice</div>
                    <div className="text-xs text-muted-foreground">10 random questions</div>
                  </div>
                </Link>
              </SheetClose>
            </div>
          </SignedIn>
        </nav>
      </SheetContent>
    </Sheet>
  );
}

function MobileNavLink({
  href,
  children,
  icon: Icon,
  isActive,
  onClick,
}: {
  href: string;
  children: React.ReactNode;
  icon: React.ElementType;
  isActive: boolean;
  onClick: () => void;
}) {
  return (
    <SheetClose asChild>
      <Link
        href={href}
        onClick={onClick}
        className={`
          flex items-center gap-3 px-3 py-3 rounded-xl transition-all
          ${isActive
            ? "bg-primary/10 text-primary font-medium"
            : "text-muted-foreground hover:bg-muted hover:text-foreground"
          }
        `}
      >
        <Icon className="h-5 w-5" />
        {children}
      </Link>
    </SheetClose>
  );
}
