import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";

export default function HomeLoading() {
  return (
    <main className="min-h-screen">
      {/* Hero Section Skeleton */}
      <section className="bg-gradient-to-b from-blue-50 to-white">
        <div className="container mx-auto px-4 py-20 text-center">
          <Skeleton className="h-6 w-48 mx-auto mb-4" />
          <Skeleton className="h-12 w-96 mx-auto mb-6" />
          <Skeleton className="h-6 w-[500px] mx-auto mb-8" />
          <div className="flex gap-4 justify-center">
            <Skeleton className="h-12 w-44" />
            <Skeleton className="h-12 w-36" />
          </div>
        </div>
      </section>

      {/* Features Section Skeleton */}
      <section className="container mx-auto px-4 py-16">
        <Skeleton className="h-9 w-64 mx-auto mb-12" />
        <div className="grid md:grid-cols-3 gap-8">
          {Array.from({ length: 3 }).map((_, i) => (
            <Card key={i} className="text-center">
              <CardHeader>
                <Skeleton className="h-14 w-14 rounded-xl mx-auto" />
                <Skeleton className="h-7 w-40 mx-auto mt-4" />
              </CardHeader>
              <CardContent>
                <Skeleton className="h-5 w-full" />
                <Skeleton className="h-5 w-3/4 mx-auto mt-2" />
              </CardContent>
            </Card>
          ))}
        </div>
      </section>

      {/* Topics Section Skeleton */}
      <section className="bg-gray-50 py-16">
        <div className="container mx-auto px-4">
          <Skeleton className="h-9 w-48 mx-auto mb-4" />
          <Skeleton className="h-5 w-96 mx-auto mb-12" />
          <div className="grid grid-cols-2 md:grid-cols-3 gap-4 max-w-4xl mx-auto">
            {Array.from({ length: 9 }).map((_, i) => (
              <Card key={i}>
                <CardContent className="p-4 text-center">
                  <Skeleton className="h-9 w-9 rounded-lg mx-auto mb-2" />
                  <Skeleton className="h-5 w-24 mx-auto" />
                </CardContent>
              </Card>
            ))}
          </div>
        </div>
      </section>
    </main>
  );
}
