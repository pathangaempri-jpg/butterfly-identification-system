"use client";

import { use } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { ArrowLeft, Loader2 } from "lucide-react";
import Link from "next/link";
import { useRouter } from "next/navigation";

import api, { apiErrorMessage } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import type { ApiResponse, Species } from "@/types";

const speciesSchema = z.object({
  common_name: z.string().min(2, "Required"),
  scientific_name: z.string().min(4, "Required"),
  family: z.string().min(2, "Required"),
  genus: z.string().optional(),
  species_name: z.string().optional(),
  description: z.string().optional(),
  habitat: z.string().optional(),
  flight_period: z.string().optional(),
  conservation_status: z.string().optional(),
  image_url: z.string().optional(),
  thumbnail_url: z.string().optional(),
});

type SpeciesForm = z.infer<typeof speciesSchema>;

export default function SpeciesEditPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const router = useRouter();
  const qc = useQueryClient();
  const isNew = id === "new";

  const { data: species, isLoading } = useQuery({
    queryKey: ["species-detail", id],
    queryFn: async () => {
      const res = await api.get<ApiResponse<Species>>(`/admin/species/${id}`);
      return res.data.data;
    },
    enabled: !isNew,
  });

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<SpeciesForm>({
    resolver: zodResolver(speciesSchema),
    values: species
      ? {
          common_name: species.common_name,
          scientific_name: species.scientific_name,
          family: species.family,
          genus: species.genus ?? "",
          species_name: species.species_name ?? "",
          description: species.description ?? "",
          habitat: species.habitat ?? "",
          flight_period: species.flight_period ?? "",
          conservation_status: species.conservation_status ?? "",
          image_url: species.image_url ?? "",
          thumbnail_url: species.thumbnail_url ?? "",
        }
      : undefined,
  });

  const mutation = useMutation({
    mutationFn: (data: SpeciesForm) =>
      isNew
        ? api.post("/admin/species", data)
        : api.put(`/admin/species/${id}`, data),
    onSuccess: () => {
      toast.success(isNew ? "Species created." : "Species updated.");
      qc.invalidateQueries({ queryKey: ["species"] });
      router.push("/species");
    },
    onError: (err) => toast.error(apiErrorMessage(err)),
  });

  if (!isNew && isLoading) {
    return (
      <div className="p-4 md:p-6 space-y-4">
        <Skeleton className="h-8 w-32" />
        <Skeleton className="h-64" />
      </div>
    );
  }

  const fields: Array<{ name: keyof SpeciesForm; label: string; multi?: boolean }> = [
    { name: "common_name", label: "Common Name" },
    { name: "scientific_name", label: "Scientific Name" },
    { name: "family", label: "Family" },
    { name: "genus", label: "Genus" },
    { name: "species_name", label: "Species Epithet" },
    { name: "conservation_status", label: "Conservation Status" },
    { name: "flight_period", label: "Flight Period" },
    { name: "image_url", label: "Image URL" },
    { name: "thumbnail_url", label: "Thumbnail URL" },
    { name: "habitat", label: "Habitat", multi: true },
    { name: "description", label: "Description", multi: true },
  ];

  return (
    <div className="p-4 md:p-6 space-y-4 max-w-2xl">
      <div className="flex items-center gap-2">
        <Button variant="ghost" size="sm" asChild>
          <Link href="/species">
            <ArrowLeft size={14} className="mr-1" /> Species
          </Link>
        </Button>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-sm">
            {isNew ? "Add New Species" : "Edit Species"}
          </CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit((d) => mutation.mutate(d))} className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              {fields.map(({ name, label, multi }) => (
                <div
                  key={name}
                  className={multi ? "col-span-2 space-y-1.5" : "space-y-1.5"}
                >
                  <Label htmlFor={name}>{label}</Label>
                  {multi ? (
                    <Textarea
                      id={name}
                      rows={3}
                      {...register(name)}
                      aria-invalid={!!errors[name]}
                    />
                  ) : (
                    <Input
                      id={name}
                      {...register(name)}
                      aria-invalid={!!errors[name]}
                    />
                  )}
                  {errors[name] && (
                    <p className="text-xs text-destructive">{errors[name]?.message}</p>
                  )}
                </div>
              ))}
            </div>

            <div className="flex gap-2 pt-2">
              <Button
                type="submit"
                disabled={isSubmitting || mutation.isPending}
                size="sm"
              >
                {(isSubmitting || mutation.isPending) && (
                  <Loader2 size={13} className="mr-1.5 animate-spin" />
                )}
                {isNew ? "Create Species" : "Save Changes"}
              </Button>
              <Button variant="outline" size="sm" asChild>
                <Link href="/species">Cancel</Link>
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
