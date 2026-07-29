"""Standardized JSON response helpers for all API endpoints."""
from flask import jsonify


def success_response(data=None, message=None, status_code=200, meta=None):
    response = {"success": True}
    if message:
        response["message"] = message
    if data is not None:
        response["data"] = data
    if meta:
        response["meta"] = meta
    return jsonify(response), status_code


def error_response(message, status_code=400, errors=None):
    response = {"success": False, "message": message}
    if errors:
        response["errors"] = errors
    return jsonify(response), status_code


def paginated_response(items, total, page, per_page, status_code=200):
    total_pages = max(1, (total + per_page - 1) // per_page)
    meta = {
        "total": total,
        "page": page,
        "per_page": per_page,
        "total_pages": total_pages,
        "pages": total_pages,  # alias — admin frontend reads meta.pages
        "has_next": page * per_page < total,
        "has_prev": page > 1,
    }
    return success_response(data=items, meta=meta, status_code=status_code)
