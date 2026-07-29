"""Admin — user management."""
from flask import Blueprint, request
from flask_jwt_extended import get_jwt_identity

from app.schemas.admin import SuspendUserSchema, ChangeRoleSchema
from app.services import user_service
from app.services.user_service import UserError
from app.utils.decorators import admin_required, moderator_required
from app.utils.pagination import get_pagination_params
from app.utils.responses import success_response, error_response, paginated_response

admin_users_bp = Blueprint("admin_users", __name__)

_suspend_schema = SuspendUserSchema()
_role_schema = ChangeRoleSchema()


@admin_users_bp.get("/")
@admin_required
def list_users():
    page, per_page = get_pagination_params()
    filters = {
        "search": request.args.get("search"),
        "role": request.args.get("role"),
        "is_suspended": (
            request.args.get("is_suspended", "").lower() == "true"
            if request.args.get("is_suspended") is not None
            else None
        ),
    }
    filters = {k: v for k, v in filters.items() if v is not None}
    items, total = user_service.list_users_admin(page, per_page, filters)
    return paginated_response(items, total, page, per_page)


@admin_users_bp.get("/<user_id>")
@admin_required
def get_user(user_id):
    try:
        data = user_service.get_user_by_id(user_id, include_private=True)
    except UserError as e:
        return error_response(e.message, e.status_code)
    return success_response(data=data)


@admin_users_bp.patch("/<user_id>/suspend")
@admin_required
def suspend_user(user_id):
    body = request.get_json(silent=True) or {}
    errors = _suspend_schema.validate(body)
    if errors:
        return error_response("Validation failed.", 422, errors=errors)
    data = _suspend_schema.load(body)
    admin_id = get_jwt_identity()
    try:
        updated = user_service.suspend_user(
            admin_id, user_id, data["suspend"], data.get("reason")
        )
    except UserError as e:
        return error_response(e.message, e.status_code)
    action = "suspended" if data["suspend"] else "unsuspended"
    return success_response(data=updated, message=f"User {action}.")


@admin_users_bp.patch("/<user_id>/role")
@admin_required
def change_role(user_id):
    body = request.get_json(silent=True) or {}
    errors = _role_schema.validate(body)
    if errors:
        return error_response("Validation failed.", 422, errors=errors)
    data = _role_schema.load(body)
    admin_id = get_jwt_identity()
    try:
        updated = user_service.change_user_role(admin_id, user_id, data["role"])
    except UserError as e:
        return error_response(e.message, e.status_code)
    return success_response(data=updated, message="Role updated.")


@admin_users_bp.patch("/<user_id>/verify")
@admin_required
def verify_user(user_id):
    try:
        updated = user_service.verify_user(user_id)
    except UserError as e:
        return error_response(e.message, e.status_code)
    return success_response(data=updated, message="User verified.")
