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

const articleSchema = z.object({
  title: z.string().min(3, "Title is required"),
  summary: z.string().optional(),
  content: z.string().min(10, "Content is required"),
  category: z.string().optional(),
  tags: z.string().optional(),
  cover_image_url: z.string().optional(),
});

type ArticleForm = z.infer<typeof articleSchema>;

export default function NewArticlePage() {
  const router = useRouter();
  const qc = useQueryClient();

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<ArticleForm>({ resolver: zodResolver(articleSchema) });

  const mutation = useMutation({
    mutationFn: (data: ArticleForm) =>
      api.post("/admin/cms/articles", {
        ...data,
        tags: data.tags ? data.tags.split(",").map((t) => t.trim()).filter(Boolean) : [],
        status: "draft",
      }),
    onSuccess: () => {
      toast.success("Article created.");
      qc.invalidateQueries({ queryKey: ["cms-articles"] });
      router.push("/cms");
    },
    onError: (err) => toast.error(apiErrorMessage(err)),
  });

  return (
    <div className="p-4 md:p-6 space-y-4 max-w-3xl">
      <Button variant="ghost" size="sm" asChild>
        <Link href="/cms">
          <ArrowLeft size={14} className="mr-1" /> Articles
        </Link>
      </Button>

      <Card>
        <CardHeader>
          <CardTitle className="text-sm">New Article</CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit((d) => mutation.mutate(d))} className="space-y-4">
            <div className="space-y-1.5">
              <Label htmlFor="title">Title *</Label>
              <Input id="title" {...register("title")} aria-invalid={!!errors.title} />
              {errors.title && <p className="text-xs text-destructive">{errors.title.message}</p>}
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="summary">Summary</Label>
              <Textarea id="summary" rows={2} {...register("summary")} />
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="content">Content * (HTML supported)</Label>
              <Textarea
                id="content"
                rows={12}
                className="font-mono text-xs"
                {...register("content")}
                aria-invalid={!!errors.content}
              />
              {errors.content && (
                <p className="text-xs text-destructive">{errors.content.message}</p>
              )}
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-1.5">
                <Label htmlFor="category">Category</Label>
                <Input id="category" placeholder="Conservation" {...register("category")} />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="tags">Tags (comma-separated)</Label>
                <Input id="tags" placeholder="butterfly, india" {...register("tags")} />
              </div>
              <div className="col-span-2 space-y-1.5">
                <Label htmlFor="cover_image_url">Cover Image URL</Label>
                <Input id="cover_image_url" type="url" {...register("cover_image_url")} />
              </div>
            </div>

            <div className="flex gap-2 pt-2">
              <Button type="submit" disabled={isSubmitting || mutation.isPending} size="sm">
                {(isSubmitting || mutation.isPending) && (
                  <Loader2 size={13} className="mr-1.5 animate-spin" />
                )}
                Create Article
              </Button>
              <Button variant="outline" size="sm" asChild>
                <Link href="/cms">Cancel</Link>
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
