"""Admin — observation moderation."""
from flask import Blueprint, request
from flask_jwt_extended import get_jwt_identity

from app.schemas.admin import VerifyObservationSchema, RejectObservationSchema
from app.services import observation_service
from app.services.observation_service import ObservationError
from app.utils.decorators import moderator_required
from app.utils.pagination import get_pagination_params
from app.utils.responses import success_response, error_response, paginated_response

admin_obs_bp = Blueprint("admin_obs", __name__)

_verify_schema = VerifyObservationSchema()
_reject_schema = RejectObservationSchema()


@admin_obs_bp.get("/")
@moderator_required
def list_observations():
    page, per_page = get_pagination_params()
    filters = {
        "state_id": request.args.get("state_id", type=int),
        "species_id": request.args.get("species_id"),
        "verification_status": request.args.get("verification_status"),
        "user_id": request.args.get("user_id"),
    }
    filters = {k: v for k, v in filters.items() if v is not None}
    items, total = observation_service.admin_list_observations(page, per_page, filters)
    return paginated_response(items, total, page, per_page)


@admin_obs_bp.patch("/<obs_id>/verify")
@moderator_required
def verify_observation(obs_id):
    body = request.get_json(silent=True) or {}
    errors = _verify_schema.validate(body)
    if errors:
        return error_response("Validation failed.", 422, errors=errors)
    data = _verify_schema.load(body)
    admin_id = get_jwt_identity()
    try:
        obs = observation_service.admin_verify_observation(
            obs_id, admin_id,
            species_id=data.get("species_id"),
            notes=data.get("admin_notes"),
        )
    except ObservationError as e:
        return error_response(e.message, e.status_code)
    return success_response(data=obs, message="Observation verified.")


@admin_obs_bp.patch("/<obs_id>/reject")
@moderator_required
def reject_observation(obs_id):
    body = request.get_json(silent=True) or {}
    errors = _reject_schema.validate(body)
    if errors:
        return error_response("Validation failed.", 422, errors=errors)
    data = _reject_schema.load(body)
    admin_id = get_jwt_identity()
    try:
        obs = observation_service.admin_reject_observation(
            obs_id, admin_id, notes=data["admin_notes"]
        )
    except ObservationError as e:
        return error_response(e.message, e.status_code)
    return success_response(data=obs, message="Observation rejected.")
