# Django Backend (Flutter Gateway)

This backend exposes stable endpoints for Flutter and proxies ML inference to the FastAPI service.

## Run

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install django djangorestframework django-cors-headers requests
python manage.py migrate
python manage.py runserver 0.0.0.0:9000
```

## Endpoints

- GET /api/health/
- GET /api/info/
- POST /api/predict/
- POST /api/predict/batch/
- GET /api/dashboard/
- GET /api/predictions/history/

Set ML API URL with `ML_API_BASE_URL` (default `http://127.0.0.1:8000`).

## Authentication (Django REST + JWT)

- POST /api/auth/token/
- POST /api/auth/token/refresh/
- POST /api/auth/dev-quick-login/ (debug only)

`/api/health/` and `/api/info/` are public.

`/api/predict/`, `/api/predict/batch/`, `/api/dashboard/` and `/api/predictions/history/` require a JWT token.

Example:

```powershell
curl -X POST http://127.0.0.1:9000/api/auth/token/ -H "Content-Type: application/json" -d "{\"username\":\"admin\",\"password\":\"admin\"}"
```

Quick immediate login in development mode:

```powershell
curl -X POST http://127.0.0.1:9000/api/auth/dev-quick-login/ -H "Content-Type: application/json" -d "{\"username\":\"demo\",\"password\":\"Demo12345!\"}"
```
