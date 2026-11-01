import argparse
import json
import re
import urllib.request

from azure.identity import ManagedIdentityCredential
from sqlalchemy import select

from app.auth.security import hash_password, verify_password
from app.db.session import SessionLocal
from app.models import Cart, User, UserRole
from app.observability.logging import anonymize_email, configure_logging, logger
from app.schemas.api import UserCreate


def provision(email: str, password: str, role: str) -> dict:
    if not re.fullmatch(r"soc-[a-z0-9-]+@platf0rm\.site", email) or role not in ("customer", "admin"):
        raise ValueError("Only dedicated synthetic lab identities may be provisioned")
    UserCreate(email=email, password=password, first_name="SOC", last_name="Synthetic")
    with SessionLocal() as db:
        existing = db.scalar(select(User).where(User.email == email))
        if existing:
            if existing.role.value != role or not verify_password(password, existing.password_hash):
                raise ValueError("Existing identity does not match; no account was changed")
            return {"user_id": existing.id, "email_hash": anonymize_email(email), "role": role, "created": False}
        user = User(email=email, password_hash=hash_password(password), first_name="SOC", last_name="Synthetic", role=UserRole(role))
        db.add(user)
        db.flush()
        db.add(Cart(user_id=user.id))
        db.commit()
        result = {"user_id": user.id, "email_hash": anonymize_email(email), "role": role, "created": True}
        logger.info("Synthetic lab identity provisioned by maintenance command", extra={"event_type": "LAB_ACCOUNT_PROVISIONED", "user_id": user.id, "user_role": role, "email_hash": result["email_hash"]})
        return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--email", required=True)
    parser.add_argument("--role", choices=("customer", "admin"), required=True)
    parser.add_argument("--secret-name", required=True)
    parser.add_argument("--client-id", required=True)
    args = parser.parse_args()
    if not re.fullmatch(r"soc-lab-[a-z0-9-]+", args.secret_name):
        parser.error("Use a dedicated soc-lab secret")
    configure_logging()
    credential = ManagedIdentityCredential(client_id=args.client_id)
    token = credential.get_token("https://vault.azure.net/.default").token
    request = urllib.request.Request(
        f"https://secure-commerce-dev-43ad.vault.azure.net/secrets/{args.secret_name}?api-version=7.4",
        headers={"Authorization": f"Bearer {token}"},
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        password = json.load(response)["value"]
    print(json.dumps(provision(args.email, password, args.role)))


if __name__ == "__main__":
    main()
