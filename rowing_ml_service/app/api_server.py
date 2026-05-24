from __future__ import annotations

from pathlib import Path
import logging

import joblib
import pandas as pd
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from features_v2 import build_features_v2


class PredictRequest(BaseModel):
    user_id: int = -1
    race_date: str | None = None
    window_days: int = Field(default=60, ge=14, le=90)
    workouts: list[dict]
    intervals: list[dict] = Field(default_factory=list)
    users: list[dict]


app = FastAPI(title="Rowing ML API", version="1.0.0")
_bundle = None
logger = logging.getLogger("rowing_ml_api")


def _model_bundle():
    global _bundle
    if _bundle is None:
        model_path = Path("models/real_model_bundle.joblib")
        if not model_path.exists():
            raise FileNotFoundError(
                "Model file not found: models/real_model_bundle.joblib",
            )
        _bundle = joblib.load(model_path)
    return _bundle


@app.get("/health")
def health() -> dict:
    return {"ok": True}


@app.post("/predict")
def predict(payload: PredictRequest) -> dict:
    try:
        bundle = _model_bundle()
        workouts = pd.DataFrame(payload.workouts)
        intervals = pd.DataFrame(payload.intervals)
        users = pd.DataFrame(payload.users)
        if workouts.empty:
            raise HTTPException(status_code=400, detail="workouts is empty")
        if users.empty:
            raise HTTPException(status_code=400, detail="users is empty")

        if payload.race_date:
            race_date = pd.to_datetime(payload.race_date, errors="coerce")
        else:
            race_date = pd.to_datetime(workouts["date"], errors="coerce").max() + pd.Timedelta(days=1)
        if pd.isna(race_date):
            raise HTTPException(status_code=400, detail="Invalid race_date/date in workouts")

        races = pd.DataFrame(
            [{
                "race_id": 1,
                "user_id": payload.user_id,
                "date": race_date,
                "result_2k_sec": float("nan"),
            }],
        )

        feats = build_features_v2(
            workouts_df=workouts,
            intervals_df=intervals,
            races_df=races,
            users_df=users,
            window_days=payload.window_days,
        )
        if feats.empty:
            raise HTTPException(
                status_code=400,
                detail=(
                    f"No training data in {payload.window_days}-day window for "
                    f"user_id={payload.user_id}"
                ),
            )

        pipeline = bundle["pipeline"]
        feature_cols = bundle["feature_columns"]
        baseline_col = str(bundle.get("baseline_column", "w_riegel_2k_best_min"))
        target_mode = str(bundle.get("target_mode", "absolute"))

        for c in feature_cols:
            if c not in feats.columns:
                feats[c] = float("nan")
        x = feats[feature_cols]

        baseline_val = None
        if baseline_col in feats.columns and pd.notna(feats[baseline_col].iloc[0]):
            baseline_val = float(feats[baseline_col].iloc[0])

        if isinstance(pipeline, dict) and {"residual", "absolute"}.issubset(pipeline.keys()):
            weights = pipeline.get("weights") or {"baseline": 0.0, "residual": 0.5, "absolute": 0.5}
            wb = float(weights.get("baseline", 0.0))
            wr = float(weights.get("residual", 0.0))
            wa = float(weights.get("absolute", 0.0))
            pred_residual = float(pipeline["residual"].predict(x)[0])
            pred_absolute = float(pipeline["absolute"].predict(x)[0])
            if baseline_val is None:
                predicted = pred_absolute
            else:
                predicted = wb * baseline_val + wr * (baseline_val + pred_residual) + wa * pred_absolute
        else:
            predicted = float(pipeline.predict(x)[0])

        return {
            "predicted_2k_sec": round(predicted, 1),
            "target_mode": target_mode,
            "race_date": race_date.date().isoformat(),
            "window_days": int(payload.window_days),
            "n_workouts_in_window": int(feats["w_count"].iloc[0]) if "w_count" in feats.columns else None,
            "baseline_riegel_2k_sec": baseline_val,
        }
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("ML predict failed")
        raise HTTPException(status_code=500, detail=str(exc))
