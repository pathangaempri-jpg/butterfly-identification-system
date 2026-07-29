"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { formatDistanceToNow } from "date-fns";
import { MoreHorizontal, Plus, Globe, EyeOff, Trash2, Pencil } from "lucide-react";
import Link from "next/link";

import api, { apiErrorMessage } from "@/lib/api";
import { DataTable, type Column } from "@/components/shared/data-table";
import { SearchInput } from "@/components/shared/search-input";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import type { ApiResponse, CmsArticle, PaginationMeta } from "@/types";

const STATUS_STYLES: Record<string, string> = {
  published: "bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-300",
  draft: "bg-yellow-100 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-300",
  archived: "bg-muted text-muted-foreground",
};

export default function CmsPage() {
  const qc = useQueryClient();
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("all");
  const [deleteId, setDeleteId] = useState<string | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ["cms-articles", page, search, status],
    queryFn: async () => {
      const params = new URLSearchParams({
        page: String(page),
        per_page: "20",
        ...(search && { search }),
        ...(status !== "all" && { status }),
      });
      const res = await api.get<ApiResponse<CmsArticle[]>>(`/admin/cms/articles?${params}`);
      return { articles: res.data.data, meta: res.data.meta as PaginationMeta };
    },
  });

  const publishMutation = useMutation({
    mutationFn: (id: string) => api.post(`/admin/cms/articles/${id}/publish`),
    onSuccess: () => {
      toast.success("Article published.");
      qc.invalidateQueries({ queryKey: ["cms-articles"] });
    },
    onError: (err) => toast.error(apiErrorMessage(err)),
  });

  const unpublishMutation = useMutation({
    mutationFn: (id: string) => api.put(`/admin/cms/articles/${id}`, { status: "draft" }),
    onSuccess: () => {
      toast.success("Article unpublished.");
      qc.invalidateQueries({ queryKey: ["cms-articles"] });
    },
    onError: (err) => toast.error(apiErrorMessage(err)),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => api.delete(`/admin/cms/articles/${id}`),
    onSuccess: () => {
      toast.success("Article deleted.");
      qc.invalidateQueries({ queryKey: ["cms-articles"] });
      setDeleteId(null);
    },
    onError: (err) => toast.error(apiErrorMessage(err)),
  });

  const columns: Column<CmsArticle>[] = [
    {
      key: "title",
      header: "Article",
      cell: (a) => (
        <div>
          <p className="text-sm font-medium line-clamp-1">{a.title}</p>
          <p className="text-xs text-muted-foreground">
            by {a.author?.full_name ?? "Unknown"} ·{" "}
            {formatDistanceToNow(new Date(a.created_at), { addSuffix: true })}
          </p>
        </div>
      ),
    },
    {
      key: "category",
      header: "Category",
      cell: (a) => a.category ? (
        <Badge variant="outline" className="text-xs">{a.category}</Badge>
      ) : <span className="text-xs text-muted-foreground">—</span>,
    },
    {
      key: "status",
      header: "Status",
      cell: (a) => (
        <span className={`text-[11px] font-medium px-2 py-0.5 rounded-full capitalize ${STATUS_STYLES[a.status]}`}>
          {a.status}
        </span>
      ),
    },
    {
      key: "actions",
      header: "",
      className: "w-10",
      cell: (a) => (
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" size="icon-sm">
              <MoreHorizontal size={14} />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuItem asChild>
              <Link href={`/cms/${a.id}`} className="gap-2">
                <Pencil size={13} /> Edit
              </Link>
            </DropdownMenuItem>
            <DropdownMenuSeparator />
            {a.status !== "published" ? (
              <DropdownMenuItem
                className="gap-2 text-green-600 focus:text-green-600"
                onClick={() => publishMutation.mutate(a.id)}
              >
                <Globe size={13} /> Publish
              </DropdownMenuItem>
            ) : (
              <DropdownMenuItem
                className="gap-2"
                onClick={() => unpublishMutation.mutate(a.id)}
              >
                <EyeOff size={13} /> Unpublish
              </DropdownMenuItem>
            )}
            <DropdownMenuSeparator />
            <DropdownMenuItem
              className="gap-2 text-destructive focus:text-destructive"
              onClick={() => setDeleteId(a.id)}
            >
              <Trash2 size={13} /> Delete
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      ),
    },
  ];

  return (
    <div className="p-4 md:p-6 space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-base font-semibold">CMS Articles</h2>
          <p className="text-xs text-muted-foreground">
            {data?.meta?.total?.toLocaleString() ?? "—"} articles
          </p>
        </div>
        <Button size="sm" asChild>
          <Link href="/cms/new">
            <Plus size={14} className="mr-1.5" /> New Article
          </Link>
        </Button>
      </div>

      <div className="flex items-center gap-2">
        <SearchInput
          value={search}
          onChange={(v) => { setSearch(v); setPage(1); }}
          placeholder="Search title…"
          className="max-w-72"
        />
        <Select value={status} onValueChange={(v) => { setStatus(v); setPage(1); }}>
          <SelectTrigger className="h-8 w-32 text-xs">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All</SelectItem>
            <SelectItem value="published">Published</SelectItem>
            <SelectItem value="draft">Draft</SelectItem>
            <SelectItem value="archived">Archived</SelectItem>
          </SelectContent>
        </Select>
      </div>

      <DataTable
        columns={columns}
        data={data?.articles ?? []}
        loading={isLoading}
        meta={data?.meta}
        onPageChange={setPage}
        emptyMessage="No articles found."
      />

      <AlertDialog open={!!deleteId} onOpenChange={() => setDeleteId(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Delete article?</AlertDialogTitle>
            <AlertDialogDescription>This action cannot be undone.</AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction
              onClick={() => deleteId && deleteMutation.mutate(deleteId)}
              className="bg-destructive text-white hover:bg-destructive/90"
            >
              Delete
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
