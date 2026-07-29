"""Identification trigger and result retrieval."""
from flask import Blueprint, request
from flask_jwt_extended import jwt_required, get_jwt_identity

from app.extensions import limiter
from app.services import identification_service
from app.services.identification_service import IdentificationError
from app.utils.decorators import moderator_required
from app.utils.responses import success_response, error_response

identifications_bp = Blueprint("identifications", __name__)


@identifications_bp.post("/observations/<obs_id>/identify")
@jwt_required()
@limiter.limit("30 per hour")
def trigger(obs_id):
    """
    Trigger synchronous Gemini identification for an observation.
    Runs the AI call inline — response may take 5-15 seconds.
    Returns 200 with the completed (or failed) result.
    """
    user_id = get_jwt_identity()
    try:
        result = identification_service.trigger_identification(obs_id, user_id)
    except IdentificationError as e:
        return error_response(e.message, e.status_code)
    return success_response(data=result)


@identifications_bp.get("/observations/<obs_id>/result")
@jwt_required()
def get_result(obs_id):
    """Get the stored identification result for an observation."""
    user_id = get_jwt_identity()
    try:
        result = identification_service.get_identification_result(obs_id, user_id)
    except IdentificationError as e:
        return error_response(e.message, e.status_code)
    return success_response(data=result)


@identifications_bp.post("/results/<result_id>/matches/<int:match_id>/accept")
@moderator_required
def accept_match(result_id, match_id):
    """
    Admin / moderator: override the AI result by accepting a specific match.
    Sets is_accepted=True, updates the observation's species and verification status.
    """
    body = request.get_json(silent=True) or {}
    admin_notes = body.get("admin_notes")
    try:
        result = identification_service.admin_accept_match(result_id, match_id, admin_notes)
    except IdentificationError as e:
        return error_response(e.message, e.status_code)
    return success_response(data=result, message="Match accepted.")
