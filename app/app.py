"""Hello World web app that counts visits.

Locally the counter lives in memory. On Azure it is stored in Table Storage,
accessed with the App Service managed identity (no secrets in app settings).
"""

import os

from flask import Flask, jsonify, render_template_string

from store import InMemoryVisitStore, create_store_from_env

PAGE = """<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Hello from {{ environment }}</title>
    <style>
      body { font-family: system-ui, sans-serif; display: grid; place-items: center;
             min-height: 100vh; margin: 0; background: #0f172a; color: #e2e8f0; }
      main { text-align: center; padding: 16px; }
      .count { font-size: 5rem; font-weight: 700; color: #38bdf8; }
      .env { text-transform: uppercase; letter-spacing: .15em; color: #94a3b8; }
    </style>
  </head>
  <body>
    <main>
      <p class="env">{{ environment }}{% if version %} &middot; {{ version }}{% endif %}</p>
      <h1>Hello World!</h1>
      <p>This page has been visited</p>
      <p class="count">{{ count }}</p>
      <p>times</p>
    </main>
  </body>
</html>
"""


def create_app(store=None):
    app = Flask(__name__)
    visits = store if store is not None else create_store_from_env()
    environment = os.environ.get("APP_ENVIRONMENT", "local")
    version = os.environ.get("APP_VERSION")

    @app.get("/")
    def index():
        return render_template_string(
            PAGE, count=visits.increment(), environment=environment, version=version
        )

    @app.get("/api/visits")
    def api_visits():
        return jsonify(visits=visits.get(), environment=environment, version=version)

    @app.get("/health")
    def health():
        return jsonify(status="ok")

    return app


# Entry point for gunicorn: `gunicorn app:app`
app = create_app()

if __name__ == "__main__":
    create_app(InMemoryVisitStore()).run(debug=True, port=8000)
