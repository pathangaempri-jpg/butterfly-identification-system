"use client";

import { use } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { format } from "date-fns";
import { ArrowLeft, CheckCircle2, XCircle, Cpu } from "lucide-react";
import Link from "next/link";

import api, { apiErrorMessage } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { Separator } from "@/components/ui/separator";
import type { ApiResponse, Observation, IdentificationResult } from "@/types";

const STATUS_COLORS: Record<string, string> = {
  pending: "bg-yellow-100 text-yellow-800",
  ai_identified: "bg-blue-100 text-blue-800",
  expert_verified: "bg-green-100 text-green-800",
  community_verified: "bg-emerald-100 text-emerald-800",
  rejected: "bg-red-100 text-red-800",
};

export default function ObservationDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const qc = useQueryClient();

  const { data: obs, isLoading } = useQuery({
    queryKey: ["observation", id],
    queryFn: async () => {
      const res = await api.get<ApiResponse<Observation>>(`/admin/observations/${id}`);
      return res.data.data;
    },
  });

  const { data: idResult } = useQuery({
    queryKey: ["id-result", id],
    queryFn: async () => {
      try {
        const res = await api.get<ApiResponse<IdentificationResult>>(
          `/identifications/observations/${id}/result`
        );
        return res.data.data;
      } catch {
        return null;
      }
    },
    enabled: !!obs,
  });

  const verifyMutation = useMutation({
    mutationFn: () => api.post(`/admin/observations/${id}/verify`),
    onSuccess: () => {
      toast.success("Observation verified.");
      qc.invalidateQueries({ queryKey: ["observation", id] });
    },
    onError: (err) => toast.error(apiErrorMessage(err)),
  });

  const rejectMutation = useMutation({
    mutationFn: () => api.post(`/admin/observations/${id}/reject`),
    onSuccess: () => {
      toast.success("Observation rejected.");
      qc.invalidateQueries({ queryKey: ["observation", id] });
    },
    onError: (err) => toast.error(apiErrorMessage(err)),
  });

  const acceptMatchMutation = useMutation({
    mutationFn: ({ resultId, matchId }: { resultId: string; matchId: number }) =>
      api.post(`/identifications/results/${resultId}/matches/${matchId}/accept`, {
        admin_notes: "Accepted via admin dashboard",
      }),
    onSuccess: () => {
      toast.success("Match accepted. Species updated.");
      qc.invalidateQueries({ queryKey: ["id-result", id] });
      qc.invalidateQueries({ queryKey: ["observation", id] });
    },
    onError: (err) => toast.error(apiErrorMessage(err)),
  });

  if (isLoading) {
    return (
      <div className="p-4 md:p-6 space-y-4">
        <Skeleton className="h-8 w-32" />
        <div className="grid md:grid-cols-3 gap-4">
          <Skeleton className="h-64 md:col-span-2" />
          <Skeleton className="h-64" />
        </div>
      </div>
    );
  }

  if (!obs) return <div className="p-6 text-muted-foreground">Observation not found.</div>;

  const statusInfo = STATUS_COLORS[obs.verification_status] ?? "";

  return (
    <div className="p-4 md:p-6 space-y-4">
      <Button variant="ghost" size="sm" asChild>
        <Link href="/observations">
          <ArrowLeft size={14} className="mr-1" /> Observations
        </Link>
      </Button>

      <div className="grid md:grid-cols-3 gap-4">
        {/* Main info */}
        <div className="md:col-span-2 space-y-4">
          {/* Images */}
          {obs.images && obs.images.length > 0 && (
            <Card>
              <CardContent className="pt-4">
                <div className="flex gap-2 overflow-x-auto">
                  {obs.images.map((img) => (
                    <img
                      key={img.id}
                      src={img.optimized_url ?? img.original_url}
                      alt="Observation"
                      className="h-48 w-auto rounded-lg object-cover shrink-0"
                    />
                  ))}
                </div>
              </CardContent>
            </Card>
          )}

          {/* Details */}
          <Card>
            <CardHeader className="pb-2">
              <div className="flex items-start justify-between gap-2">
                <CardTitle className="text-sm">
                  {obs.title ?? obs.species?.common_name ?? "Unidentified Observation"}
                </CardTitle>
                <span className={`text-[11px] font-medium px-2 py-0.5 rounded-full shrink-0 ${statusInfo}`}>
                  {obs.verification_status.replace("_", " ")}
                </span>
              </div>
            </CardHeader>
            <CardContent className="space-y-2 text-sm">
              {obs.notes && <p className="text-muted-foreground">{obs.notes}</p>}
              <Separator />
              <div className="grid grid-cols-2 gap-y-1.5 text-xs">
                {[
                  ["Observer", `@${obs.user?.username ?? "unknown"}`],
                  ["Location", obs.location_name ?? `State ${obs.state_id}`],
                  ["Coordinates", obs.latitude ? `${obs.latitude.toFixed(4)}, ${obs.longitude?.toFixed(4)}` : "—"],
                  ["Privacy", obs.privacy],
                  ["Observed", obs.observed_at ? format(new Date(obs.observed_at), "dd MMM yyyy") : "—"],
                  ["Submitted", format(new Date(obs.created_at), "dd MMM yyyy HH:mm")],
                ].map(([k, v]) => (
                  <div key={k}>
                    <span className="text-muted-foreground">{k}: </span>
                    <span className="font-medium capitalize">{v}</span>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>

          {/* AI Identification result */}
          {idResult && (
            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm flex items-center gap-2">
                  <Cpu size={14} /> AI Identification
                  <Badge variant="outline" className="text-xs ml-auto">
                    {idResult.status}
                  </Badge>
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-2">
                {idResult.error_message && (
                  <p className="text-xs text-destructive">{idResult.error_message}</p>
                )}
                {idResult.matches.map((match) => (
                  <div
                    key={match.id}
                    className={`flex items-center justify-between p-2.5 rounded-lg border text-xs ${
                      match.is_accepted ? "bg-green-50 border-green-200 dark:bg-green-900/20 dark:border-green-800" : ""
                    }`}
                  >
                    <div>
                      <p className="font-medium">
                        #{match.rank} {match.matched_common_name}
                      </p>
                      <p className="text-muted-foreground italic">{match.matched_scientific_name}</p>
                    </div>
                    <div className="flex items-center gap-2">
                      <span className="font-semibold text-primary">
                        {Math.round(match.confidence_score * 100)}%
                      </span>
                      {!match.is_accepted && (
                        <Button
                          size="xs"
                          variant="outline"
                          onClick={() =>
                            acceptMatchMutation.mutate({
                              resultId: idResult.id,
                              matchId: match.id,
                            })
                          }
                        >
                          Accept
                        </Button>
                      )}
                      {match.is_accepted && (
                        <Badge className="text-[10px] bg-green-600">Accepted</Badge>
                      )}
                    </div>
                  </div>
                ))}
                {idResult.processing_time_ms && (
                  <p className="text-[10px] text-muted-foreground">
                    Processed in {idResult.processing_time_ms}ms · {idResult.gemini_model_version}
                  </p>
                )}
              </CardContent>
            </Card>
          )}
        </div>

        {/* Actions */}
        <div className="space-y-4">
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm">Actions</CardTitle>
            </CardHeader>
            <CardContent className="space-y-2">
              {obs.species && (
                <div className="p-2.5 bg-muted rounded-lg">
                  <p className="text-xs text-muted-foreground">Identified Species</p>
                  <p className="text-sm font-medium">{obs.species.common_name}</p>
                  <p className="text-xs text-muted-foreground italic">
                    {obs.species.scientific_name}
                  </p>
                </div>
              )}

              <Button
                size="sm"
                className="w-full gap-2 bg-green-600 hover:bg-green-700"
                onClick={() => verifyMutation.mutate()}
                disabled={verifyMutation.isPending || obs.verification_status === "expert_verified"}
              >
                <CheckCircle2 size={14} />
                {obs.verification_status === "expert_verified" ? "Already Verified" : "Verify Observation"}
              </Button>

              <Button
                variant="destructive"
                size="sm"
                className="w-full gap-2"
                onClick={() => rejectMutation.mutate()}
                disabled={rejectMutation.isPending || obs.verification_status === "rejected"}
              >
                <XCircle size={14} />
                {obs.verification_status === "rejected" ? "Already Rejected" : "Reject Observation"}
              </Button>
            </CardContent>
          </Card>

          <Card>
            <CardContent className="pt-4 space-y-1">
              {[
                ["ID", obs.id.slice(0, 8) + "…"],
                ["User ID", obs.user_id.slice(0, 8) + "…"],
                ["Images", obs.images?.length ?? 0],
              ].map(([k, v]) => (
                <div key={String(k)} className="flex justify-between text-xs">
                  <span className="text-muted-foreground">{k}</span>
                  <span className="font-mono">{v}</span>
                </div>
              ))}
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}
