"""Admin — CMS article and banner management."""
from flask import Blueprint, request
from flask_jwt_extended import get_jwt_identity

from app.schemas.cms import ArticleCreateSchema, ArticleUpdateSchema, BannerCreateSchema, BannerUpdateSchema
from app.services import cms_service
from app.services.cms_service import CmsError
from app.utils.decorators import admin_required, moderator_required
from app.utils.pagination import get_pagination_params
from app.utils.responses import success_response, error_response, paginated_response
from app.utils.validators import validate_image_file

admin_cms_bp = Blueprint("admin_cms", __name__)

_article_create_schema = ArticleCreateSchema()
_article_update_schema = ArticleUpdateSchema()
_banner_create_schema = BannerCreateSchema()
_banner_update_schema = BannerUpdateSchema()


# ── Articles ───────────────────────────────────────────────────────────────────

@admin_cms_bp.get("/articles")
@moderator_required
def list_articles():
    page, per_page = get_pagination_params()
    status = request.args.get("status")
    article_type = request.args.get("type")
    items, total = cms_service.admin_list_articles(page, per_page, status, article_type)
    return paginated_response(items, total, page, per_page)


@admin_cms_bp.get("/articles/<article_id>")
@moderator_required
def get_article(article_id):
    from app.services.cms_service import _fetch_article, _article_to_dict
    article = _fetch_article(article_id)
    if not article:
        return error_response("Article not found.", 404)
    return success_response(data=_article_to_dict(article, include_content=True))


@admin_cms_bp.post("/articles")
@moderator_required
def create_article():
    body = request.get_json(silent=True) or {}
    errors = _article_create_schema.validate(body)
    if errors:
        return error_response("Validation failed.", 422, errors=errors)
    data = _article_create_schema.load(body)
    author_id = get_jwt_identity()
    try:
        article = cms_service.create_article(data, author_id)
    except CmsError as e:
        return error_response(e.message, e.status_code)
    return success_response(data=article, status_code=201)


@admin_cms_bp.put("/articles/<article_id>")
@moderator_required
def update_article(article_id):
    body = request.get_json(silent=True) or {}
    errors = _article_update_schema.validate(body)
    if errors:
        return error_response("Validation failed.", 422, errors=errors)
    data = _article_update_schema.load(body)
    try:
        article = cms_service.update_article(article_id, data)
    except CmsError as e:
        return error_response(e.message, e.status_code)
    return success_response(data=article)


@admin_cms_bp.patch("/articles/<article_id>/publish")
@moderator_required
def publish_article(article_id):
    try:
        article = cms_service.update_article(article_id, {"status": "published"})
    except CmsError as e:
        return error_response(e.message, e.status_code)
    return success_response(data=article, message="Article published.")


@admin_cms_bp.patch("/articles/<article_id>/archive")
@moderator_required
def archive_article(article_id):
    try:
        article = cms_service.update_article(article_id, {"status": "archived"})
    except CmsError as e:
        return error_response(e.message, e.status_code)
    return success_response(data=article, message="Article archived.")


@admin_cms_bp.post("/articles/<article_id>/cover")
@moderator_required
def upload_cover(article_id):
    file = request.files.get("image")
    ok, err = validate_image_file(file)
    if not ok:
        return error_response(err, 400)
    try:
        article = cms_service.set_cover_image(article_id, file)
    except CmsError as e:
        return error_response(e.message, e.status_code)
    return success_response(data=article)


@admin_cms_bp.delete("/articles/<article_id>")
@admin_required
def delete_article(article_id):
    try:
        cms_service.delete_article(article_id)
    except CmsError as e:
        return error_response(e.message, e.status_code)
    return success_response(message="Article deleted.")


# ── Banners ────────────────────────────────────────────────────────────────────

@admin_cms_bp.get("/banners")
@moderator_required
def list_banners():
    banners = cms_service.list_banners()
    return success_response(data=banners)


@admin_cms_bp.post("/banners")
@admin_required
def create_banner():
    file = request.files.get("image")
    ok, err = validate_image_file(file)
    if not ok:
        return error_response(err, 400)
    body = request.form.to_dict()
    errors = _banner_create_schema.validate(body)
    if errors:
        return error_response("Validation failed.", 422, errors=errors)
    data = _banner_create_schema.load(body)
    try:
        banner = cms_service.create_banner(data, file)
    except CmsError as e:
        return error_response(e.message, e.status_code)
    return success_response(data=banner, status_code=201)


@admin_cms_bp.put("/banners/<int:banner_id>")
@admin_required
def update_banner(banner_id):
    body = request.get_json(silent=True) or {}
    errors = _banner_update_schema.validate(body)
    if errors:
        return error_response("Validation failed.", 422, errors=errors)
    data = _banner_update_schema.load(body)
    try:
        banner = cms_service.update_banner(banner_id, data)
    except CmsError as e:
        return error_response(e.message, e.status_code)
    return success_response(data=banner)


@admin_cms_bp.delete("/banners/<int:banner_id>")
@admin_required
def delete_banner(banner_id):
    try:
        cms_service.delete_banner(banner_id)
    except CmsError as e:
        return error_response(e.message, e.status_code)
    return success_response(message="Banner deleted.")
