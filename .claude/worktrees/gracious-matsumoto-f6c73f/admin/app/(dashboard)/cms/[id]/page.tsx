"use client";

import { use } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { ArrowLeft, Loader2, Globe } from "lucide-react";
import Link from "next/link";
import { useRouter } from "next/navigation";

import api, { apiErrorMessage } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import type { ApiResponse, CmsArticle } from "@/types";

const articleSchema = z.object({
  title: z.string().min(3, "Title is required"),
  summary: z.string().optional(),
  content: z.string().min(10, "Content is required"),
  category: z.string().optional(),
  tags: z.string().optional(), // comma-separated
  cover_image_url: z.string().optional(),
  status: z.enum(["draft", "published", "archived"]),
});

type ArticleForm = z.infer<typeof articleSchema>;

export default function CmsArticlePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const router = useRouter();
  const qc = useQueryClient();
  const isNew = id === "new";

  const { data: article, isLoading } = useQuery({
    queryKey: ["cms-article", id],
    queryFn: async () => {
      const res = await api.get<ApiResponse<CmsArticle>>(`/admin/cms/articles/${id}`);
      return res.data.data;
    },
    enabled: !isNew,
  });

  const {
    register,
    handleSubmit,
    setValue,
    watch,
    formState: { errors, isSubmitting },
  } = useForm<ArticleForm>({
    resolver: zodResolver(articleSchema),
    defaultValues: { status: "draft" },
    values: article
      ? {
          title: article.title,
          summary: article.summary ?? "",
          content: article.content ?? "",
          category: article.category ?? "",
          tags: article.tags?.join(", ") ?? "",
          cover_image_url: article.cover_image_url ?? "",
          status: article.status,
        }
      : undefined,
  });

  const mutation = useMutation({
    mutationFn: (data: ArticleForm) => {
      const payload = {
        ...data,
        tags: data.tags ? data.tags.split(",").map((t) => t.trim()).filter(Boolean) : [],
      };
      return isNew
        ? api.post("/admin/cms/articles", payload)
        : api.put(`/admin/cms/articles/${id}`, payload);
    },
    onSuccess: () => {
      toast.success(isNew ? "Article created." : "Article saved.");
      qc.invalidateQueries({ queryKey: ["cms-articles"] });
      router.push("/cms");
    },
    onError: (err) => toast.error(apiErrorMessage(err)),
  });

  const publishMutation = useMutation({
    mutationFn: () => api.post(`/admin/cms/articles/${id}/publish`),
    onSuccess: () => {
      toast.success("Article published.");
      qc.invalidateQueries({ queryKey: ["cms-article", id] });
      qc.invalidateQueries({ queryKey: ["cms-articles"] });
    },
    onError: (err) => toast.error(apiErrorMessage(err)),
  });

  if (!isNew && isLoading) {
    return (
      <div className="p-4 md:p-6 space-y-4">
        <Skeleton className="h-8 w-32" />
        <Skeleton className="h-96" />
      </div>
    );
  }

  const currentStatus = watch("status");

  return (
    <div className="p-4 md:p-6 space-y-4 max-w-3xl">
      <div className="flex items-center justify-between">
        <Button variant="ghost" size="sm" asChild>
          <Link href="/cms">
            <ArrowLeft size={14} className="mr-1" /> Articles
          </Link>
        </Button>
        {!isNew && article?.status !== "published" && (
          <Button
            size="sm"
            className="gap-1.5 bg-green-600 hover:bg-green-700"
            onClick={() => publishMutation.mutate()}
            disabled={publishMutation.isPending}
          >
            <Globe size={13} /> Publish
          </Button>
        )}
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-sm">
            {isNew ? "New Article" : "Edit Article"}
          </CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit((d) => mutation.mutate(d))} className="space-y-4">
            {/* Title */}
            <div className="space-y-1.5">
              <Label htmlFor="title">Title *</Label>
              <Input id="title" {...register("title")} aria-invalid={!!errors.title} />
              {errors.title && (
                <p className="text-xs text-destructive">{errors.title.message}</p>
              )}
            </div>

            {/* Summary */}
            <div className="space-y-1.5">
              <Label htmlFor="summary">Summary</Label>
              <Textarea id="summary" rows={2} {...register("summary")} />
            </div>

            {/* Content */}
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

            {/* Category, Tags, Cover */}
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-1.5">
                <Label htmlFor="category">Category</Label>
                <Input id="category" placeholder="e.g. Conservation" {...register("category")} />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="tags">Tags (comma-separated)</Label>
                <Input id="tags" placeholder="butterfly, india, nature" {...register("tags")} />
              </div>
              <div className="space-y-1.5 col-span-2">
                <Label htmlFor="cover_image_url">Cover Image URL</Label>
                <Input
                  id="cover_image_url"
                  type="url"
                  placeholder="https://…"
                  {...register("cover_image_url")}
                />
              </div>
            </div>

            {/* Status */}
            <div className="space-y-1.5">
              <Label>Status</Label>
              <Select
                value={currentStatus}
                onValueChange={(v) => setValue("status", v as ArticleForm["status"])}
              >
                <SelectTrigger className="w-36 h-8 text-xs">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="draft">Draft</SelectItem>
                  <SelectItem value="published">Published</SelectItem>
                  <SelectItem value="archived">Archived</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="flex gap-2 pt-2">
              <Button type="submit" disabled={isSubmitting || mutation.isPending} size="sm">
                {(isSubmitting || mutation.isPending) && (
                  <Loader2 size={13} className="mr-1.5 animate-spin" />
                )}
                {isNew ? "Create Article" : "Save Changes"}
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
