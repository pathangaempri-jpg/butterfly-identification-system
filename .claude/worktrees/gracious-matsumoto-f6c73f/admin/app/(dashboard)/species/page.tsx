"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { MoreHorizontal, Plus, Trash2, Pencil } from "lucide-react";
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
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import type { ApiResponse, Species, PaginationMeta } from "@/types";

export default function SpeciesPage() {
  const qc = useQueryClient();
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [deleteId, setDeleteId] = useState<string | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ["species", page, search],
    queryFn: async () => {
      const params = new URLSearchParams({
        page: String(page),
        per_page: "20",
        ...(search && { search }),
      });
      const res = await api.get<ApiResponse<Species[]>>(`/species/?${params}`);
      return { species: res.data.data, meta: res.data.meta as PaginationMeta };
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => api.delete(`/admin/species/${id}`),
    onSuccess: () => {
      toast.success("Species deleted.");
      qc.invalidateQueries({ queryKey: ["species"] });
      setDeleteId(null);
    },
    onError: (err) => toast.error(apiErrorMessage(err)),
  });

  const columns: Column<Species>[] = [
    {
      key: "image",
      header: "",
      className: "w-10",
      cell: (s) => (
        <div className="size-9 rounded-lg bg-muted overflow-hidden shrink-0">
          {s.thumbnail_url ? (
            <img src={s.thumbnail_url} alt={s.common_name} className="size-full object-cover" />
          ) : (
            <div className="size-full flex items-center justify-center text-base">🦋</div>
          )}
        </div>
      ),
    },
    {
      key: "name",
      header: "Species",
      cell: (s) => (
        <div>
          <p className="text-sm font-medium">{s.common_name}</p>
          <p className="text-xs text-muted-foreground italic">{s.scientific_name}</p>
        </div>
      ),
    },
    {
      key: "family",
      header: "Family",
      cell: (s) => <span className="text-xs text-muted-foreground">{s.family}</span>,
    },
    {
      key: "status",
      header: "Conservation",
      cell: (s) => s.conservation_status ? (
        <Badge variant="outline" className="text-xs">{s.conservation_status}</Badge>
      ) : <span className="text-xs text-muted-foreground">—</span>,
    },
    {
      key: "active",
      header: "Status",
      cell: (s) => (
        <Badge variant={s.is_active ? "default" : "secondary"} className="text-xs">
          {s.is_active ? "Active" : "Hidden"}
        </Badge>
      ),
    },
    {
      key: "actions",
      header: "",
      className: "w-10",
      cell: (s) => (
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" size="icon-sm">
              <MoreHorizontal size={14} />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuItem asChild>
              <Link href={`/species/${s.id}`} className="gap-2">
                <Pencil size={13} /> Edit
              </Link>
            </DropdownMenuItem>
            <DropdownMenuSeparator />
            <DropdownMenuItem
              className="gap-2 text-destructive focus:text-destructive"
              onClick={() => setDeleteId(s.id)}
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
          <h2 className="text-base font-semibold">Species</h2>
          <p className="text-xs text-muted-foreground">
            {data?.meta?.total?.toLocaleString() ?? "—"} species in database
          </p>
        </div>
        <Button size="sm" asChild>
          <Link href="/species/new">
            <Plus size={14} className="mr-1.5" /> Add Species
          </Link>
        </Button>
      </div>

      <SearchInput
        value={search}
        onChange={(v) => { setSearch(v); setPage(1); }}
        placeholder="Search common or scientific name…"
        className="max-w-72"
      />

      <DataTable
        columns={columns}
        data={data?.species ?? []}
        loading={isLoading}
        meta={data?.meta}
        onPageChange={setPage}
        emptyMessage="No species found."
      />

      <AlertDialog open={!!deleteId} onOpenChange={() => setDeleteId(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Delete species?</AlertDialogTitle>
            <AlertDialogDescription>
              This will permanently delete this species record. Observations linked to it will lose
              their species association.
            </AlertDialogDescription>
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
