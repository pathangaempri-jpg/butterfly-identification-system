"""CMS articles and banners — via Supabase PostgREST."""
import uuid

import bleach
from datetime import datetime, timezone
from slugify import slugify

from app.supabase_client import get_supabase
from app.services.user_repo import user_to_dict

ALLOWED_TAGS = [
    "p", "br", "strong", "em", "u", "h2", "h3", "h4",
    "ul", "ol", "li", "a", "blockquote", "img", "figure", "figcaption",
]
ALLOWED_ATTRS = {
    "a": ["href", "title", "target"],
    "img": ["src", "alt", "width", "height"],
}

ARTICLE_SELECT = "*, users(*, roles(name))"


class CmsError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        self.message = message
        self.status_code = status_code
        super().__init__(message)


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _sanitize(html: str) -> str:
    return bleach.clean(html, tags=ALLOWED_TAGS, attributes=ALLOWED_ATTRS, strip=True)


def _article_to_dict(a: dict, include_content: bool = False) -> dict:
    author = a.get("users")
    if isinstance(author, list):
        author = author[0] if author else None
    data = {
        "id": a["id"],
        "title": a["title"],
        "slug": a["slug"],
        "excerpt": a.get("excerpt"),
        "cover_image_url": a.get("cover_image_url"),
        "article_type": a.get("article_type"),
        "status": a.get("status"),
        "author": user_to_dict(author) if author else None,
        "published_at": a.get("published_at"),
        "created_at": a.get("created_at"),
    }
    if include_content:
        data["content"] = a.get("content")
    return data


def _banner_to_dict(b: dict) -> dict:
    return {
        "id": b["id"],
        "title": b["title"],
        "image_url": b["image_url"],
        "link_url": b.get("link_url"),
        "placement": b.get("placement"),
        "is_active": b.get("is_active"),
        "display_order": b.get("display_order"),
    }


def _make_unique_slug(title: str, exclude_id: str = None) -> str:
    sb = get_supabase()
    base = slugify(title)
    slug = base
    counter = 1
    while True:
        q = sb.table("cms_articles").select("id").eq("slug", slug)
        if exclude_id:
            q = q.neq("id", exclude_id)
        if not q.execute().data:
            return slug
        slug = f"{base}-{counter}"
        counter += 1


def _fetch_article(article_id: str) -> dict | None:
    sb = get_supabase()
    res = sb.table("cms_articles").select(ARTICLE_SELECT).eq("id", article_id).execute()
    return res.data[0] if res.data else None


# ── Public API ─────────────────────────────────────────────────────────────────

def list_articles(page: int, per_page: int, article_type: str = None) -> tuple:
    sb = get_supabase()
    query = sb.table("cms_articles").select(ARTICLE_SELECT, count="exact").eq("status", "published")
    if article_type:
        query = query.eq("article_type", article_type)
    start = (page - 1) * per_page
    res = query.order("published_at", desc=True).range(start, start + per_page - 1).execute()
    return [_article_to_dict(a, include_content=False) for a in res.data], res.count or 0


def get_article(slug: str) -> dict:
    sb = get_supabase()
    res = sb.table("cms_articles").select(ARTICLE_SELECT).eq("slug", slug).eq("status", "published").execute()
    if not res.data:
        raise CmsError("Article not found.", 404)
    return _article_to_dict(res.data[0], include_content=True)


def list_banners(placement: str = None) -> list:
    sb = get_supabase()
    query = sb.table("cms_banners").select("*").eq("is_active", True)
    if placement:
        query = query.eq("placement", placement)
    res = query.order("display_order").execute()
    return [_banner_to_dict(b) for b in res.data]


# ── Admin API ──────────────────────────────────────────────────────────────────

def admin_list_articles(page: int, per_page: int, status: str = None, article_type: str = None) -> tuple:
    sb = get_supabase()
    query = sb.table("cms_articles").select(ARTICLE_SELECT, count="exact")
    if status:
        query = query.eq("status", status)
    if article_type:
        query = query.eq("article_type", article_type)
    start = (page - 1) * per_page
    res = query.order("created_at", desc=True).range(start, start + per_page - 1).execute()
    return [_article_to_dict(a, include_content=False) for a in res.data], res.count or 0


def create_article(data: dict, author_id: str) -> dict:
    sb = get_supabase()
    status = data.get("status", "draft")
    article_id = str(uuid.uuid4())
    now = _now()
    sb.table("cms_articles").insert({
        "id": article_id,
        "title": data["title"],
        "slug": _make_unique_slug(data["title"]),
        "content": _sanitize(data["content"]),
        "excerpt": data.get("excerpt"),
        "article_type": data.get("article_type", "educational"),
        "status": status,
        "author_id": author_id,
        "published_at": now if status == "published" else None,
        "created_at": now,
        "updated_at": now,
    }).execute()
    return _article_to_dict(_fetch_article(article_id), include_content=True)


def update_article(article_id: str, data: dict) -> dict:
    sb = get_supabase()
    article = _fetch_article(article_id)
    if not article:
        raise CmsError("Article not found.", 404)

    fields = {}
    if "title" in data:
        fields["title"] = data["title"]
        fields["slug"] = _make_unique_slug(data["title"], exclude_id=article_id)
    if "content" in data:
        fields["content"] = _sanitize(data["content"])
    for field in ("excerpt", "article_type"):
        if field in data:
            fields[field] = data[field]
    if "status" in data:
        fields["status"] = data["status"]
        if data["status"] == "published" and article.get("status") != "published":
            fields["published_at"] = _now()

    if fields:
        fields["updated_at"] = _now()
        sb.table("cms_articles").update(fields).eq("id", article_id).execute()

    return _article_to_dict(_fetch_article(article_id), include_content=True)


def delete_article(article_id: str) -> None:
    sb = get_supabase()
    article = sb.table("cms_articles").select("id").eq("id", article_id).execute()
    if not article.data:
        raise CmsError("Article not found.", 404)
    sb.table("cms_articles").delete().eq("id", article_id).execute()


def set_cover_image(article_id: str, file_storage) -> dict:
    from app.services.storage_service import upload_file
    sb = get_supabase()
    article = sb.table("cms_articles").select("id").eq("id", article_id).execute()
    if not article.data:
        raise CmsError("Article not found.", 404)
    urls = upload_file(file_storage, folder=f"cms/articles/{article_id}")
    sb.table("cms_articles").update({
        "cover_image_url": urls["optimized_url"],
        "updated_at": _now(),
    }).eq("id", article_id).execute()
    return _article_to_dict(_fetch_article(article_id), include_content=False)


# ── Banners ────────────────────────────────────────────────────────────────────

def create_banner(data: dict, file_storage) -> dict:
    from app.services.storage_service import upload_file
    sb = get_supabase()
    urls = upload_file(file_storage, folder="cms/banners")
    res = sb.table("cms_banners").insert({
        "title": data["title"],
        "image_url": urls["optimized_url"],
        "link_url": data.get("link_url"),
        "placement": data.get("placement", "app_home"),
        "display_order": data.get("display_order", 0),
        "is_active": True,
        "created_at": _now(),
    }).execute()
    return _banner_to_dict(res.data[0])


def update_banner(banner_id: int, data: dict) -> dict:
    sb = get_supabase()
    banner = sb.table("cms_banners").select("id").eq("id", banner_id).execute()
    if not banner.data:
        raise CmsError("Banner not found.", 404)
    fields = {f: data[f] for f in ("title", "link_url", "placement", "display_order", "is_active") if f in data}
    if fields:
        sb.table("cms_banners").update(fields).eq("id", banner_id).execute()
    res = sb.table("cms_banners").select("*").eq("id", banner_id).execute()
    return _banner_to_dict(res.data[0])


def delete_banner(banner_id: int) -> None:
    sb = get_supabase()
    banner = sb.table("cms_banners").select("id").eq("id", banner_id).execute()
    if not banner.data:
        raise CmsError("Banner not found.", 404)
    sb.table("cms_banners").delete().eq("id", banner_id).execute()
