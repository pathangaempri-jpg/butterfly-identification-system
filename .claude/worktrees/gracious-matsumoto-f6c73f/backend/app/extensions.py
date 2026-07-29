"""
Flask extensions — initialized here, bound to the app in create_app().
Import from here anywhere in the project to avoid circular imports.
"""
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from flask_jwt_extended import JWTManager
from flask_bcrypt import Bcrypt
from flask_cors import CORS
from flask_marshmallow import Marshmallow
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

db = SQLAlchemy()
migrate = Migrate()
jwt = JWTManager()
bcrypt = Bcrypt()
cors = CORS()
ma = Marshmallow()
limiter = Limiter(key_func=get_remote_address, default_limits=["1000 per day", "200 per hour"])
