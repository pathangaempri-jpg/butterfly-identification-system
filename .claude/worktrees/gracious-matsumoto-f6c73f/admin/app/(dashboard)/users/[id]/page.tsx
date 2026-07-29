"use client";

import { use } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { format } from "date-fns";
import { ArrowLeft, ShieldCheck, UserX, UserCheck } from "lucide-react";
import Link from "next/link";

import api, { apiErrorMessage } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Separator } from "@/components/ui/separator";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import type { ApiResponse, User } from "@/types";

export default function UserDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const qc = useQueryClient();

  const { data: user, isLoading } = useQuery({
    queryKey: ["user", id],
    queryFn: async () => {
      const res = await api.get<ApiResponse<User>>(`/admin/users/${id}`);
      return res.data.data;
    },
  });

  const suspendMutation = useMutation({
    mutationFn: (suspend: boolean) =>
      api.post(`/admin/users/${id}/${suspend ? "suspend" : "unsuspend"}`),
    onSuccess: () => {
      toast.success("User status updated.");
      qc.invalidateQueries({ queryKey: ["user", id] });
    },
    onError: (err) => toast.error(apiErrorMessage(err)),
  });

  const roleMutation = useMutation({
    mutationFn: (roleName: string) =>
      api.post(`/admin/users/${id}/role`, { role: roleName }),
    onSuccess: () => {
      toast.success("Role updated.");
      qc.invalidateQueries({ queryKey: ["user", id] });
    },
    onError: (err) => toast.error(apiErrorMessage(err)),
  });

  if (isLoading) {
    return (
      <div className="p-4 md:p-6 space-y-4">
        <Skeleton className="h-8 w-32" />
        <div className="grid md:grid-cols-3 gap-4">
          <Skeleton className="h-48" />
          <Skeleton className="h-48 md:col-span-2" />
        </div>
      </div>
    );
  }

  if (!user) return <div className="p-6 text-muted-foreground">User not found.</div>;

  return (
    <div className="p-4 md:p-6 space-y-4">
      <div className="flex items-center gap-2">
        <Button variant="ghost" size="sm" asChild>
          <Link href="/users">
            <ArrowLeft size={14} className="mr-1" /> Users
          </Link>
        </Button>
      </div>

      <div className="grid md:grid-cols-3 gap-4">
        {/* Profile card */}
        <Card>
          <CardContent className="pt-6 text-center space-y-3">
            <Avatar className="size-20 mx-auto">
              <AvatarImage src={user.avatar_url} />
              <AvatarFallback className="text-xl">
                {user.full_name?.slice(0, 2).toUpperCase()}
              </AvatarFallback>
            </Avatar>
            <div>
              <p className="font-semibold">{user.full_name}</p>
              <p className="text-sm text-muted-foreground">@{user.username}</p>
              <p className="text-xs text-muted-foreground mt-0.5">{user.email}</p>
            </div>
            <Badge variant={user.is_active ? "default" : "secondary"}>
              {user.is_active ? "Active" : "Suspended"}
            </Badge>
            {user.bio && <p className="text-xs text-muted-foreground">{user.bio}</p>}
            {user.location && (
              <p className="text-xs text-muted-foreground">📍 {user.location}</p>
            )}
          </CardContent>
        </Card>

        {/* Details */}
        <div className="md:col-span-2 space-y-4">
          {/* Stats */}
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm">Activity Stats</CardTitle>
            </CardHeader>
            <CardContent className="grid grid-cols-2 gap-4">
              {[
                ["Observations", user.stats?.total_observations ?? 0],
                ["Identifications", user.stats?.total_identifications ?? 0],
                ["Current Streak", `${user.stats?.observation_streak ?? 0} days`],
                ["Longest Streak", `${user.stats?.longest_streak ?? 0} days`],
              ].map(([label, val]) => (
                <div key={String(label)}>
                  <p className="text-xs text-muted-foreground">{label}</p>
                  <p className="text-xl font-bold">{val}</p>
                </div>
              ))}
            </CardContent>
          </Card>

          {/* Actions */}
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm">Admin Actions</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              {/* Role change */}
              <div className="flex items-center gap-2">
                <ShieldCheck size={14} className="text-muted-foreground shrink-0" />
                <span className="text-sm flex-1">Role</span>
                <Select
                  value={user.role ?? "user"}
                  onValueChange={(v) => roleMutation.mutate(v)}
                >
                  <SelectTrigger className="h-8 w-36 text-xs">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {["user", "researcher", "moderator", "admin"].map((r) => (
                      <SelectItem key={r} value={r} className="text-xs capitalize">
                        {r}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              <Separator />

              {/* Suspend/Unsuspend */}
              {user.is_active ? (
                <Button
                  variant="destructive"
                  size="sm"
                  className="w-full gap-2"
                  onClick={() => suspendMutation.mutate(true)}
                  disabled={suspendMutation.isPending}
                >
                  <UserX size={14} /> Suspend User
                </Button>
              ) : (
                <Button
                  variant="outline"
                  size="sm"
                  className="w-full gap-2"
                  onClick={() => suspendMutation.mutate(false)}
                  disabled={suspendMutation.isPending}
                >
                  <UserCheck size={14} /> Unsuspend User
                </Button>
              )}
            </CardContent>
          </Card>

          {/* Meta */}
          <Card>
            <CardContent className="pt-4 space-y-1">
              {[
                ["User ID", user.id],
                ["Joined", format(new Date(user.created_at), "dd MMM yyyy HH:mm")],
                ["Email Verified", user.is_verified ? "Yes" : "No"],
              ].map(([label, val]) => (
                <div key={String(label)} className="flex justify-between text-xs">
                  <span className="text-muted-foreground">{label}</span>
                  <span className="font-mono">{val}</span>
                </div>
              ))}
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}
