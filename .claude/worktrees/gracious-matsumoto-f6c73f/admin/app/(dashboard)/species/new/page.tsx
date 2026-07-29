"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { ArrowLeft, Loader2 } from "lucide-react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useMutation, useQueryClient } from "@tanstack/react-query";

import api, { apiErrorMessage } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

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

export default function NewSpeciesPage() {
  const router = useRouter();
  const qc = useQueryClient();

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<SpeciesForm>({ resolver: zodResolver(speciesSchema) });

  const mutation = useMutation({
    mutationFn: (data: SpeciesForm) => api.post("/admin/species", data),
    onSuccess: () => {
      toast.success("Species created successfully.");
      qc.invalidateQueries({ queryKey: ["species"] });
      router.push("/species");
    },
    onError: (err) => toast.error(apiErrorMessage(err)),
  });

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
      <Button variant="ghost" size="sm" asChild>
        <Link href="/species">
          <ArrowLeft size={14} className="mr-1" /> Species
        </Link>
      </Button>

      <Card>
        <CardHeader>
          <CardTitle className="text-sm">Add New Species</CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit((d) => mutation.mutate(d))} className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              {fields.map(({ name, label, multi }) => (
                <div key={name} className={multi ? "col-span-2 space-y-1.5" : "space-y-1.5"}>
                  <Label htmlFor={name}>{label}</Label>
                  {multi ? (
                    <Textarea id={name} rows={3} {...register(name)} aria-invalid={!!errors[name]} />
                  ) : (
                    <Input id={name} {...register(name)} aria-invalid={!!errors[name]} />
                  )}
                  {errors[name] && (
                    <p className="text-xs text-destructive">{errors[name]?.message}</p>
                  )}
                </div>
              ))}
            </div>
            <div className="flex gap-2 pt-2">
              <Button type="submit" disabled={isSubmitting || mutation.isPending} size="sm">
                {(isSubmitting || mutation.isPending) && (
                  <Loader2 size={13} className="mr-1.5 animate-spin" />
                )}
                Create Species
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
