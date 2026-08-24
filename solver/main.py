"""Vercel entrypoint (pyproject [tool.vercel] entrypoint = "main:app")."""
from paddltir_solver.app import app

__all__ = ["app"]
