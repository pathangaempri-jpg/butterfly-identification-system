"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { formatDistanceToNow } from "date-fns";
import { CheckCircle2, Eye, Clock, Cpu, AlertCircle } from "lucide-react";
import Link from "next/link";

import api, { apiErrorMessage } from "@/lib/api";
import { SearchInput } from "@/components/shared/search-input";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Progress } from "@/components/ui/progress";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import type { ApiResponse, IdentificationResult, PaginationMeta } from "@/types";

// The backend returns identifications via the admin observations endpoint with results embedded
// We fetch all completed identifications from /admin/observations?has_result=true
export default function IdentificationsPage() {
  const qc = useQueryClient();
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("completed");

  const { data, isLoading } = useQuery({
    queryKey: ["identifications", page, search, status],
    queryFn: async () => {
      const params = new URLSearchParams({
        page: String(page),
        per_page: "20",
        ...(status !== "all" && { status }),
        ...(search && { search }),
      });
      // Fetch all identification results from admin endpoint
      const res = await api.get<ApiResponse<IdentificationResult[]>>(
        `/admin/identifications?${params}`
      );
      return { results: res.data.data, meta: res.data.meta as PaginationMeta };
    },
  });

  const acceptMutation = useMutation({
    mutationFn: ({ resultId, matchId }: { resultId: string; matchId: number }) =>
      api.post(`/identifications/results/${resultId}/matches/${matchId}/accept`),
    onSuccess: () => {
      toast.success("Match accepted.");
      qc.invalidateQueries({ queryKey: ["identifications"] });
    },
    onError: (err) => toast.error(apiErrorMessage(err)),
  });

  const results = data?.results ?? [];

  function StatusIcon({ status }: { status: string }) {
    if (status === "completed") return <CheckCircle2 size={14} className="text-green-500" />;
    if (status === "failed") return <AlertCircle size={14} className="text-red-500" />;
    if (status === "processing") return <Cpu size={14} className="text-blue-500 animate-pulse" />;
    return <Clock size={14} className="text-muted-foreground" />;
  }

  return (
    <div className="p-4 md:p-6 space-y-4">
      <div>
        <h2 className="text-base font-semibold">AI Identifications</h2>
        <p className="text-xs text-muted-foreground">
          Gemini Vision identification results · {data?.meta?.total?.toLocaleString() ?? "—"} total
        </p>
      </div>

      <div className="flex items-center gap-2">
        <SearchInput
          value={search}
          onChange={(v) => { setSearch(v); setPage(1); }}
          placeholder="Search observation ID…"
          className="max-w-72"
        />
        <Select value={status} onValueChange={(v) => { setStatus(v); setPage(1); }}>
          <SelectTrigger className="h-8 w-36 text-xs">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All</SelectItem>
            <SelectItem value="completed">Completed</SelectItem>
            <SelectItem value="failed">Failed</SelectItem>
            <SelectItem value="processing">Processing</SelectItem>
          </SelectContent>
        </Select>
      </div>

      {isLoading ? (
        <div className="space-y-3">
          {Array.from({ length: 5 }).map((_, i) => (
            <Skeleton key={i} className="h-24" />
          ))}
        </div>
      ) : results.length === 0 ? (
        <div className="text-center text-muted-foreground py-16">
          No identification results found.
        </div>
      ) : (
        <div className="space-y-3">
          {results.map((result) => (
            <Card key={result.id}>
              <CardHeader className="pb-2 pt-4 px-4">
                <div className="flex items-center justify-between gap-2">
                  <div className="flex items-center gap-2">
                    <StatusIcon status={result.status} />
                    <span className="text-xs font-mono text-muted-foreground">
                      obs: {result.observation_id.slice(0, 8)}…
                    </span>
                  </div>
                  <div className="flex items-center gap-2">
                    {result.processing_time_ms && (
                      <span className="text-[10px] text-muted-foreground">
                        {result.processing_time_ms}ms
                      </span>
                    )}
                    <Badge variant="outline" className="text-xs capitalize">
                      {result.status}
                    </Badge>
                    <Button variant="ghost" size="icon-xs" asChild>
                      <Link href={`/observations/${result.observation_id}`}>
                        <Eye size={12} />
                      </Link>
                    </Button>
                  </div>
                </div>
              </CardHeader>
              <CardContent className="px-4 pb-4 space-y-2">
                {result.error_message && (
                  <p className="text-xs text-destructive bg-destructive/10 px-2 py-1 rounded">
                    {result.error_message}
                  </p>
                )}
                {result.matches.length > 0 ? (
                  result.matches.map((m) => (
                    <div
                      key={m.id}
                      className={`flex items-center gap-3 p-2 rounded-lg border text-xs ${
                        m.is_accepted ? "border-green-300 bg-green-50 dark:border-green-700 dark:bg-green-900/20" : "border-border"
                      }`}
                    >
                      <span className="text-muted-foreground w-5 text-center font-medium">
                        #{m.rank}
                      </span>
                      <div className="flex-1 min-w-0">
                        <p className="font-medium truncate">{m.matched_common_name}</p>
                        <p className="text-muted-foreground italic truncate">
                          {m.matched_scientific_name}
                        </p>
                      </div>
                      <div className="flex items-center gap-2 shrink-0">
                        <div className="w-16">
                          <Progress value={m.confidence_score * 100} className="h-1.5" />
                        </div>
                        <span className="w-10 text-right font-semibold">
                          {Math.round(m.confidence_score * 100)}%
                        </span>
                        {!m.is_accepted ? (
                          <Button
                            size="xs"
                            variant="outline"
                            onClick={() =>
                              acceptMutation.mutate({
                                resultId: result.id,
                                matchId: m.id,
                              })
                            }
                          >
                            Accept
                          </Button>
                        ) : (
                          <Badge className="text-[10px] bg-green-600">✓</Badge>
                        )}
                      </div>
                    </div>
                  ))
                ) : (
                  <p className="text-xs text-muted-foreground">No matches returned.</p>
                )}
                <p className="text-[10px] text-muted-foreground">
                  {result.gemini_model_version} ·{" "}
                  {formatDistanceToNow(new Date(result.created_at), { addSuffix: true })}
                </p>
              </CardContent>
            </Card>
          ))}

          {/* Pagination */}
          {data?.meta && data.meta.pages > 1 && (
            <div className="flex justify-center gap-2 pt-2">
              <Button
                variant="outline"
                size="sm"
                disabled={!data.meta.has_prev}
                onClick={() => setPage((p) => p - 1)}
              >
                Previous
              </Button>
              <span className="flex items-center px-3 text-sm">
                {data.meta.page} / {data.meta.pages}
              </span>
              <Button
                variant="outline"
                size="sm"
                disabled={!data.meta.has_next}
                onClick={() => setPage((p) => p + 1)}
              >
                Next
              </Button>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
