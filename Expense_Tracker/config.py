import os
import json
import urllib.request


def get_vault_secrets():
    vault_addr = os.environ["VAULT_ADDR"]
    role_id = os.environ["VAULT_ROLE_ID"]
    secret_id = os.environ["VAULT_SECRET_ID"]

    login_data = json.dumps({
        "role_id": role_id,
        "secret_id": secret_id
    }).encode()

    login_request = urllib.request.Request(
        f"{vault_addr}/v1/auth/approle/login",
        data=login_data,
        headers={"Content-Type": "application/json"},
        method="POST"
    )

    with urllib.request.urlopen(login_request) as response:
        login_response = json.loads(response.read().decode())

    vault_token = login_response["auth"]["client_token"]

    secret_request = urllib.request.Request(
        f"{vault_addr}/v1/secret/data/project3",
        headers={"X-Vault-Token": vault_token}
    )

    with urllib.request.urlopen(secret_request) as response:
        secret_response = json.loads(response.read().decode())

    return secret_response["data"]["data"]


vault_secrets = get_vault_secrets()


class Config:
    DB_HOST = os.getenv("DATABASE_HOST", "db")
    DB_NAME = os.getenv("DATABASE_NAME", "course_recommendation_db")
    DB_USER = os.getenv("DATABASE_USER", "postgres")

    DB_PASSWORD = vault_secrets["postgres_password"]

    SQLALCHEMY_DATABASE_URI = (
        f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:5432/{DB_NAME}"
    )

    SECRET_KEY = vault_secrets["secret_key"]
    JWT_SECRET_KEY = vault_secrets["jwt_secret_key"]
