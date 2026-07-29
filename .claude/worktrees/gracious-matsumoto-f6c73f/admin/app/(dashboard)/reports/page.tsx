"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { formatDistanceToNow } from "date-fns";
import { CheckCircle2, XCircle, ExternalLink } from "lucide-react";
import Link from "next/link";

import api, { apiErrorMessage } from "@/lib/api";
import { DataTable, type Column } from "@/components/shared/data-table";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import type { ApiResponse, Report, PaginationMeta } from "@/types";

const STATUS_STYLES: Record<string, string> = {
  open: "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-300",
  resolved: "bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-300",
  dismissed: "bg-muted text-muted-foreground",
};

export default function ReportsPage() {
  const qc = useQueryClient();
  const [page, setPage] = useState(1);
  const [status, setStatus] = useState("open");

  const { data, isLoading } = useQuery({
    queryKey: ["reports", page, status],
    queryFn: async () => {
      const params = new URLSearchParams({
        page: String(page),
        per_page: "20",
        ...(status !== "all" && { status }),
      });
      const res = await api.get<ApiResponse<Report[]>>(`/admin/reports?${params}`);
      return { reports: res.data.data, meta: res.data.meta as PaginationMeta };
    },
  });

  const resolveMutation = useMutation({
    mutationFn: ({ id, dismiss }: { id: string; dismiss: boolean }) =>
      api.post(`/admin/reports/${id}/${dismiss ? "dismiss" : "resolve"}`),
    onSuccess: () => {
      toast.success("Report updated.");
      qc.invalidateQueries({ queryKey: ["reports"] });
    },
    onError: (err) => toast.error(apiErrorMessage(err)),
  });

  const columns: Column<Report>[] = [
    {
      key: "report",
      header: "Report",
      cell: (r) => (
        <div>
          <p className="text-sm font-medium capitalize">{r.reason.replace("_", " ")}</p>
          {r.description && (
            <p className="text-xs text-muted-foreground line-clamp-2">{r.description}</p>
          )}
          <p className="text-xs text-muted-foreground mt-0.5">
            by @{r.reporter?.username ?? "unknown"}
          </p>
        </div>
      ),
    },
    {
      key: "target",
      header: "Target",
      cell: (r) => (
        <div className="flex items-center gap-1.5">
          <Badge variant="outline" className="text-xs capitalize">{r.target_type}</Badge>
          {r.target_type === "observation" && (
            <Button variant="ghost" size="icon-xs" asChild>
              <Link href={`/observations/${r.target_id}`}>
                <ExternalLink size={11} />
              </Link>
            </Button>
          )}
        </div>
      ),
    },
    {
      key: "status",
      header: "Status",
      cell: (r) => (
        <span className={`text-[11px] font-medium px-2 py-0.5 rounded-full capitalize ${STATUS_STYLES[r.status]}`}>
          {r.status}
        </span>
      ),
    },
    {
      key: "date",
      header: "Submitted",
      cell: (r) => (
        <span className="text-xs text-muted-foreground">
          {formatDistanceToNow(new Date(r.created_at), { addSuffix: true })}
        </span>
      ),
    },
    {
      key: "actions",
      header: "",
      className: "w-28",
      cell: (r) =>
        r.status === "open" ? (
          <div className="flex items-center gap-1">
            <Button
              size="xs"
              variant="outline"
              className="gap-1 text-green-600 border-green-200 hover:bg-green-50"
              onClick={() => resolveMutation.mutate({ id: r.id, dismiss: false })}
            >
              <CheckCircle2 size={11} /> Resolve
            </Button>
            <Button
              size="xs"
              variant="ghost"
              className="gap-1 text-muted-foreground"
              onClick={() => resolveMutation.mutate({ id: r.id, dismiss: true })}
            >
              <XCircle size={11} /> Dismiss
            </Button>
          </div>
        ) : null,
    },
  ];

  return (
    <div className="p-4 md:p-6 space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-base font-semibold">Reports</h2>
          <p className="text-xs text-muted-foreground">
            {data?.meta?.total?.toLocaleString() ?? "—"} reports
          </p>
        </div>
        <Select value={status} onValueChange={(v) => { setStatus(v); setPage(1); }}>
          <SelectTrigger className="h-8 w-32 text-xs">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All</SelectItem>
            <SelectItem value="open">Open</SelectItem>
            <SelectItem value="resolved">Resolved</SelectItem>
            <SelectItem value="dismissed">Dismissed</SelectItem>
          </SelectContent>
        </Select>
      </div>

      <DataTable
        columns={columns}
        data={data?.reports ?? []}
        loading={isLoading}
        meta={data?.meta}
        onPageChange={setPage}
        emptyMessage="No reports found."
      />
    </div>
  );
}
