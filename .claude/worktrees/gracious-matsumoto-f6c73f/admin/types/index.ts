// ── Auth ───────────────────────────────────────────────────────────────────────
export type UserRole = "user" | "researcher" | "moderator" | "admin" | "super_admin";

export interface LoginResponse {
  access_token: string;
  refresh_token: string;
  user: User;
}

// ── Users ──────────────────────────────────────────────────────────────────────
export interface User {
  id: string;
  email: string;
  full_name: string;
  username: string;
  role: UserRole | null;
  is_active: boolean;
  is_verified: boolean;
  bio?: string;
  location?: string;
  avatar_url?: string;
  fcm_token?: string;
  created_at: string;
  updated_at?: string;
  stats?: UserStats;
}

export interface UserStats {
  total_observations: number;
  total_identifications: number;
  observation_streak: number;
  longest_streak: number;
}

// ── Species ────────────────────────────────────────────────────────────────────
export interface Species {
  id: string;
  common_name: string;
  scientific_name: string;
  family: string;
  genus: string;
  species_name: string;
  description?: string;
  habitat?: string;
  flight_period?: string;
  conservation_status?: string;
  color_tags?: string[];
  thumbnail_url?: string;
  image_url?: string;
  is_active: boolean;
  created_at: string;
  updated_at?: string;
}

// ── Geography ──────────────────────────────────────────────────────────────────
export interface State {
  id: number;
  name: string;
  code: string;
  region?: string;
}

// ── Observations ───────────────────────────────────────────────────────────────
export type VerificationStatus =
  | "pending"
  | "ai_identified"
  | "expert_verified"
  | "community_verified"
  | "rejected";

export type ObservationPrivacy = "public" | "private" | "anonymous";

export interface ObservationImage {
  id: number;
  original_url: string;
  optimized_url?: string;
  thumbnail_url?: string;
  is_primary: boolean;
  file_size_bytes?: number;
  width?: number;
  height?: number;
}

export interface Observation {
  id: string;
  user_id: string;
  user?: Pick<User, "id" | "username" | "full_name" | "avatar_url">;
  species_id?: string;
  species?: Pick<Species, "id" | "common_name" | "scientific_name" | "thumbnail_url">;
  state_id: number;
  state?: State;
  latitude?: number;
  longitude?: number;
  location_name?: string;
  title?: string;
  notes?: string;
  observed_at?: string;
  privacy: ObservationPrivacy;
  verification_status: VerificationStatus;
  is_active: boolean;
  created_at: string;
  updated_at?: string;
  images?: ObservationImage[];
}

// ── Identifications ────────────────────────────────────────────────────────────
export interface IdentificationMatch {
  id: number;
  rank: number;
  confidence_score: number;
  matched_common_name: string;
  matched_scientific_name: string;
  species_id?: string;
  species?: Pick<Species, "id" | "common_name" | "scientific_name">;
  is_accepted: boolean;
  admin_notes?: string;
}

export interface IdentificationResult {
  id: string;
  observation_id: string;
  status: "pending" | "processing" | "completed" | "failed";
  error_message?: string;
  processing_time_ms?: number;
  gemini_model_version?: string;
  created_at: string;
  completed_at?: string;
  matches: IdentificationMatch[];
}

// ── CMS ────────────────────────────────────────────────────────────────────────
export interface CmsArticle {
  id: string;
  title: string;
  slug: string;
  summary?: string;
  content?: string;
  cover_image_url?: string;
  author_id: string;
  author?: Pick<User, "id" | "username" | "full_name">;
  status: "draft" | "published" | "archived";
  category?: string;
  tags?: string[];
  published_at?: string;
  created_at: string;
  updated_at?: string;
}

// ── Reports ────────────────────────────────────────────────────────────────────
export interface Report {
  id: string;
  reporter_id: string;
  reporter?: Pick<User, "id" | "username" | "full_name">;
  target_type: "observation" | "user" | "comment";
  target_id: string;
  reason: string;
  description?: string;
  status: "open" | "resolved" | "dismissed";
  resolved_by?: string;
  created_at: string;
}

// ── Dashboard ──────────────────────────────────────────────────────────────────
export interface DashboardStats {
  total_users: number;
  total_observations: number;
  total_species: number;
  total_identifications: number;
  pending_observations: number;
  new_users_this_month: number;
  new_observations_this_month: number;
}

// ── API helpers ────────────────────────────────────────────────────────────────
export interface ApiResponse<T> {
  success: boolean;
  data: T;
  message?: string;
  meta?: PaginationMeta;
  errors?: Record<string, string[]>;
}

export interface PaginationMeta {
  page: number;
  per_page: number;
  total: number;
  pages: number;
  has_next: boolean;
  has_prev: boolean;
}

export interface ListParams {
  page?: number;
  per_page?: number;
  search?: string;
  status?: string;
  [key: string]: string | number | boolean | undefined;
}
