"""
Feature engineering v2 для инференса.
"""

from __future__ import annotations

import warnings
from datetime import timedelta
from typing import Dict, List

import numpy as np
import pandas as pd

from wr_curve import project_via_wr, wr_ratio

warnings.filterwarnings("ignore", message=r"Mean of empty slice", category=RuntimeWarning)
warnings.filterwarnings("ignore", message=r"All-NaN slice encountered", category=RuntimeWarning)


def _row_level_intervals(intervals_df: pd.DataFrame, user_gender: pd.Series) -> pd.DataFrame:
    if intervals_df.empty:
        return intervals_df.assign(int_wr_ratio=np.nan, int_riegel_2k=np.nan)
    df = intervals_df.copy()
    df["distance"] = pd.to_numeric(df["distance"], errors="coerce")
    df["time"] = pd.to_numeric(df["time"], errors="coerce")
    df["split_500"] = pd.to_numeric(df["split_500"], errors="coerce")
    df["heart_rate"] = pd.to_numeric(df["heart_rate"], errors="coerce")
    df["stroke_rate"] = pd.to_numeric(df["stroke_rate"], errors="coerce")
    df["rest_before"] = pd.to_numeric(df["rest_before"], errors="coerce")

    gender = df["gender"].fillna("m").to_numpy()
    t = df["time"].to_numpy(dtype=float)
    d = df["distance"].to_numpy(dtype=float)
    with np.errstate(invalid="ignore", divide="ignore"):
        df["int_wr_ratio"] = wr_ratio(t, d, gender)
        df["int_riegel_2k"] = project_via_wr(t, d, gender)
    bad = df["distance"] < 200.0
    df.loc[bad, "int_riegel_2k"] = np.nan

    df = df.sort_values(["workout_id", "interval_id"]).reset_index(drop=True)
    df["split_diff_prev"] = df.groupby("workout_id")["split_500"].diff().abs()
    df["regime_change"] = (df["split_diff_prev"] >= 2.0).astype("Int64")
    return df


def _block_projections(
    ri: pd.DataFrame,
    pace_threshold: float = 2.5,
    rest_break: float = 600.0,
    min_single_d: float = 500.0,
    eff_d_cap: float | None = None,
    rest_tau_sec: float = 180.0,
) -> pd.DataFrame:
    cols = [
        "workout_id",
        "block_id",
        "n_intervals",
        "single_d",
        "sum_d",
        "avg_rest",
        "eff_d",
        "eff_t",
        "riegel_2k_block",
        "block_split_500",
    ]
    if ri.empty:
        return pd.DataFrame(columns=cols)

    df = ri.sort_values(["workout_id", "interval_id"]).copy()
    df["distance"] = pd.to_numeric(df["distance"], errors="coerce")
    df["time"] = pd.to_numeric(df["time"], errors="coerce")
    df["split_500"] = pd.to_numeric(df["split_500"], errors="coerce")
    df["rest_before"] = pd.to_numeric(df["rest_before"], errors="coerce").fillna(0.0)

    rows: List[Dict] = []
    for wid, grp in df.groupby("workout_id"):
        grp = grp.sort_values("interval_id").reset_index(drop=True)
        if len(grp) < 2:
            continue
        pace_jump = grp["split_500"].diff().abs() > pace_threshold
        big_rest = grp["rest_before"] > rest_break
        new_block = (pace_jump | big_rest).fillna(False)
        new_block.iloc[0] = True
        block_id = new_block.cumsum()

        for bid, bg in grp.groupby(block_id):
            if len(bg) < 2:
                continue
            sum_d = float(bg["distance"].sum())
            sum_t = float(bg["time"].sum())
            single_d = float(bg["distance"].mean())
            if single_d < min_single_d:
                continue
            rest_breaks_n = max(len(bg) - 1, 1)
            rest_within = float(bg["rest_before"].iloc[1:].sum())
            avg_rest = rest_within / rest_breaks_n
            if not (sum_d > 0 and sum_t > 0 and single_d > 0):
                continue

            weight = float(np.exp(-avg_rest / max(rest_tau_sec, 1e-6)))
            eff_d_raw = single_d + (sum_d - single_d) * weight
            eff_d = eff_d_raw if eff_d_cap is None else min(eff_d_raw, eff_d_cap)
            eff_t = sum_t * (eff_d / sum_d)
            if eff_d < 200.0:
                continue
            gender = bg["gender"].iloc[0] if "gender" in bg.columns else "m"
            try:
                proj = float(project_via_wr(eff_t, eff_d, gender))
            except Exception:
                proj = np.nan
            rows.append(
                {
                    "workout_id": int(wid),
                    "block_id": int(bid),
                    "n_intervals": int(len(bg)),
                    "single_d": single_d,
                    "sum_d": sum_d,
                    "avg_rest": avg_rest,
                    "eff_d": eff_d,
                    "eff_t": eff_t,
                    "riegel_2k_block": proj,
                    "block_split_500": (eff_t / eff_d) * 500.0,
                },
            )
    return pd.DataFrame(rows, columns=cols)


def _interval_aggregates(ri: pd.DataFrame, blocks: pd.DataFrame | None = None) -> pd.DataFrame:
    base_cols = [
        "workout_id",
        "iw_wr_ratio_min",
        "iw_wr_ratio_mean",
        "iw_wr_ratio_median",
        "iw_riegel_2k_min",
        "iw_riegel_2k_median",
        "iw_hr_at_min_split",
        "iw_hr_completeness",
        "iw_rest_sum",
        "iw_regime_changes",
        "iw_n_intervals",
        "iw_time_sum",
        "iw_distance_sum",
        "iw_stroke_rate_mean",
        "iw_block_riegel_2k_min",
        "iw_block_n_max",
    ]
    if ri.empty:
        return pd.DataFrame(columns=base_cols)

    def _agg(grp: pd.DataFrame) -> pd.Series:
        grp = grp.sort_values("interval_id")
        if grp["int_wr_ratio"].notna().any():
            i_min = grp["int_wr_ratio"].idxmin()
            hr_at_min = grp.loc[i_min, "heart_rate"]
        else:
            hr_at_min = np.nan
        return pd.Series(
            {
                "iw_wr_ratio_min": grp["int_wr_ratio"].min(),
                "iw_wr_ratio_mean": grp["int_wr_ratio"].mean(),
                "iw_wr_ratio_median": grp["int_wr_ratio"].median(),
                "iw_riegel_2k_min": grp["int_riegel_2k"].min(),
                "iw_riegel_2k_median": grp["int_riegel_2k"].median(),
                "iw_hr_at_min_split": hr_at_min,
                "iw_hr_completeness": grp["heart_rate"].notna().mean(),
                "iw_rest_sum": grp["rest_before"].sum(),
                "iw_regime_changes": pd.to_numeric(
                    grp["regime_change"],
                    errors="coerce",
                ).sum(skipna=True),
                "iw_n_intervals": len(grp),
                "iw_time_sum": grp["time"].sum(),
                "iw_distance_sum": grp["distance"].sum(),
                "iw_stroke_rate_mean": grp["stroke_rate"].mean(),
            },
        )

    iwa = ri.groupby("workout_id").apply(_agg).reset_index()
    if blocks is not None and not blocks.empty:
        bagg = blocks.groupby("workout_id").agg(
            iw_block_riegel_2k_min=("riegel_2k_block", "min"),
            iw_block_n_max=("n_intervals", "max"),
        ).reset_index()
        iwa = iwa.merge(bagg, on="workout_id", how="left")
    else:
        iwa["iw_block_riegel_2k_min"] = np.nan
        iwa["iw_block_n_max"] = 0

    iwa["iw_riegel_2k_min"] = iwa[["iw_riegel_2k_min", "iw_block_riegel_2k_min"]].min(
        axis=1,
    )
    return iwa


def _row_level_workouts(workouts_df: pd.DataFrame) -> pd.DataFrame:
    df = workouts_df.copy()
    for c in ["distance", "time", "split_500", "heart_rate", "stroke_rate", "fatigue_score"]:
        df[c] = pd.to_numeric(df[c], errors="coerce")

    gender = df["gender"].fillna("m").to_numpy()
    t = df["time"].to_numpy(dtype=float)
    d = df["distance"].to_numpy(dtype=float)
    with np.errstate(invalid="ignore", divide="ignore"):
        nonint_wr_ratio = wr_ratio(t, d, gender)
        nonint_riegel_2k = project_via_wr(t, d, gender)
    mask_nonint = df["workout_type"] == 0
    df["wrk_wr_ratio_best_row"] = np.where(mask_nonint, nonint_wr_ratio, np.nan)
    df["wrk_wr_ratio_typical_row"] = df["wrk_wr_ratio_best_row"]
    df["wrk_riegel_2k_best_row"] = np.where(mask_nonint, nonint_riegel_2k, np.nan)
    df["wrk_riegel_2k_typical_row"] = df["wrk_riegel_2k_best_row"]
    df["date"] = pd.to_datetime(df["date"], errors="coerce")
    return df


def _merge_interval_aggregates(ww: pd.DataFrame, iwa: pd.DataFrame) -> pd.DataFrame:
    df = ww.merge(iwa, on="workout_id", how="left")
    is_interval = df["workout_type"] == 1
    df["wrk_wr_ratio_best"] = np.where(is_interval, df["iw_wr_ratio_min"], df["wrk_wr_ratio_best_row"])
    df["wrk_wr_ratio_typical"] = np.where(
        is_interval,
        df["iw_wr_ratio_median"],
        df["wrk_wr_ratio_typical_row"],
    )
    df["wrk_riegel_2k_best"] = np.where(is_interval, df["iw_riegel_2k_min"], df["wrk_riegel_2k_best_row"])
    df["wrk_riegel_2k_typical"] = np.where(
        is_interval,
        df["iw_riegel_2k_median"],
        df["wrk_riegel_2k_typical_row"],
    )
    df["wrk_work_time"] = np.where(is_interval, df["iw_time_sum"], df["time"])
    df["wrk_work_distance"] = np.where(is_interval, df["iw_distance_sum"], df["distance"])
    df["wrk_hr_unified"] = np.where(is_interval, df["iw_hr_at_min_split"], df["heart_rate"])
    df["wrk_hr_present"] = np.where(
        is_interval,
        pd.to_numeric(df["iw_hr_completeness"], errors="coerce").fillna(0.0),
        df["heart_rate"].notna().astype(float),
    )
    return df


def _window_features(
    ww: pd.DataFrame,
    user_max_hr: pd.Series,
    gender_is_female: pd.Series,
    races: pd.DataFrame,
    window_days: int,
    hard_fatigue: int,
    easy_fatigue: int,
    easy_long_distance_m: float,
    recent_short_days: int,
    recent_mid_days: int,
) -> pd.DataFrame:
    rows: List[Dict] = []
    for r in races.itertuples(index=False):
        sub = ww[ww["user_id"] == r.user_id]
        win = sub[
            (sub["date"] < r.date) & (sub["date"] >= r.date - timedelta(days=window_days))
        ].copy()
        if win.empty:
            continue

        total_days = max((win["date"].max() - win["date"].min()).days + 1, 1)
        int_win = win[win["workout_type"] == 1]
        recent_s = win[win["date"] >= r.date - timedelta(days=recent_short_days)]
        recent_m = win[win["date"] >= r.date - timedelta(days=recent_mid_days)]
        last7 = win[win["date"] >= r.date - timedelta(days=7)]

        fat = pd.to_numeric(win["fatigue_score"], errors="coerce")
        wt_min = pd.to_numeric(win["wrk_work_time"], errors="coerce") / 60.0
        wr_best = pd.to_numeric(win["wrk_wr_ratio_best"], errors="coerce")
        riegel_best = pd.to_numeric(win["wrk_riegel_2k_best"], errors="coerce")

        easy_long = win[
            (fat <= easy_fatigue)
            & (pd.to_numeric(win["distance"], errors="coerce") >= easy_long_distance_m)
        ]
        easy_long_days_ratio = (
            easy_long["date"].dt.date.nunique() / total_days if not easy_long.empty else 0.0
        )

        wr_for_split = wr_best.dropna()
        if len(wr_for_split) >= 3:
            q33 = wr_for_split.quantile(0.33)
            q67 = wr_for_split.quantile(0.67)
            hard_mask = wr_best <= q33
            easy_mask = wr_best >= q67
        else:
            hard_mask = wr_best.notna()
            easy_mask = pd.Series(False, index=wr_best.index)
        hard = win[hard_mask.fillna(False)]
        easy = win[easy_mask.fillna(False)]

        max_hr_user = float(user_max_hr.get(r.user_id, np.nan))
        hr_present = pd.to_numeric(win["wrk_hr_present"], errors="coerce")

        def _hr_norm_median(sub_df: pd.DataFrame) -> float:
            if sub_df.empty or not np.isfinite(max_hr_user) or max_hr_user <= 0:
                return np.nan
            hr = pd.to_numeric(sub_df["wrk_hr_unified"], errors="coerce")
            return float((hr / max_hr_user).median())

        stress_load = (fat.fillna(0.0) * wt_min.fillna(0.0)).sum()
        pb_proxy = riegel_best.min()
        if np.isfinite(pb_proxy) and pb_proxy > 0:
            rel_intensity = (pb_proxy / riegel_best).clip(lower=0.4, upper=1.5)
        else:
            rel_intensity = pd.Series(np.nan, index=riegel_best.index)
        fpi = (fat / rel_intensity).replace([np.inf, -np.inf], np.nan)

        feats: Dict[str, float] = {
            "race_id": r.race_id,
            "user_id": int(r.user_id),
            "race_date": r.date,
            "target_2k_sec": float(r.result_2k_sec),
            "max_heart_rate": max_hr_user,
            "gender_is_female": int(gender_is_female.get(r.user_id, 0)),
            "w_count": int(len(win)),
            "w_interval_ratio": float((win["workout_type"] == 1).mean()),
            "w_days_since_last": int((r.date - win["date"].max()).days),
            "w_missing_ratio": float(
                win[["distance", "time", "split_500", "stroke_rate", "heart_rate", "fatigue_score"]]
                .isna()
                .mean()
                .mean()
            ),
            "w_work_time_sum": float(pd.to_numeric(win["wrk_work_time"], errors="coerce").sum()),
            "w_work_distance_sum_km": float(
                pd.to_numeric(win["wrk_work_distance"], errors="coerce").sum() / 1000.0
            ),
            "w_wr_ratio_best_min": float(wr_best.min()),
            "w_wr_ratio_best_median": float(wr_best.median()),
            "w_wr_ratio_typical_mean": float(
                pd.to_numeric(win["wrk_wr_ratio_typical"], errors="coerce").mean()
            ),
            "w_wr_ratio_typical_median": float(
                pd.to_numeric(win["wrk_wr_ratio_typical"], errors="coerce").median()
            ),
            "w_riegel_2k_best_min": float(riegel_best.min()),
            "w_riegel_2k_best_median": float(riegel_best.median()),
            "w_riegel_2k_typical_median": float(
                pd.to_numeric(win["wrk_riegel_2k_typical"], errors="coerce").median()
            ),
            "w_hr_completeness": float(hr_present.fillna(0.0).mean()),
            "w_hr_hard_norm_median": _hr_norm_median(hard),
            "w_hr_easy_norm_median": _hr_norm_median(easy),
            "w_stroke_rate_mean": float(pd.to_numeric(win["stroke_rate"], errors="coerce").mean()),
            "w_fatigue_hard_median": float(
                pd.to_numeric(hard["fatigue_score"], errors="coerce").median()
            )
            if not hard.empty
            else np.nan,
            "w_fatigue_per_intensity_median": float(fpi.median()),
            "w_stress_load_sum": float(stress_load),
            "w_fatigue_last7_mean": float(
                pd.to_numeric(last7["fatigue_score"], errors="coerce").mean()
            )
            if not last7.empty
            else np.nan,
            "w_hard_days_ratio": float((fat >= hard_fatigue).mean()),
            "w_easy_long_days_ratio": float(easy_long_days_ratio),
            "w_int_regime_changes_mean": float(
                pd.to_numeric(int_win["iw_regime_changes"], errors="coerce").mean()
            )
            if not int_win.empty
            else np.nan,
            "w_int_n_mean": float(pd.to_numeric(int_win["iw_n_intervals"], errors="coerce").mean())
            if not int_win.empty
            else np.nan,
            "w_recent_short_wr_ratio_mean": float(
                pd.to_numeric(recent_s["wrk_wr_ratio_typical"], errors="coerce").mean()
            )
            if not recent_s.empty
            else np.nan,
            "w_recent_short_riegel_2k_min": float(
                pd.to_numeric(recent_s["wrk_riegel_2k_best"], errors="coerce").min()
            )
            if not recent_s.empty
            else np.nan,
            "w_recent_mid_wr_ratio_mean": float(
                pd.to_numeric(recent_m["wrk_wr_ratio_typical"], errors="coerce").mean()
            )
            if not recent_m.empty
            else np.nan,
            "w_recent_mid_work_time_sum": float(
                pd.to_numeric(recent_m["wrk_work_time"], errors="coerce").sum()
            )
            if not recent_m.empty
            else np.nan,
        }
        rows.append(feats)

    return pd.DataFrame(rows)


def build_features_v2(
    workouts_df: pd.DataFrame,
    intervals_df: pd.DataFrame,
    races_df: pd.DataFrame,
    users_df: pd.DataFrame,
    window_days: int = 60,
    hard_fatigue: int = 7,
    easy_fatigue: int = 3,
    easy_long_distance_m: float = 6000.0,
    recent_short_days: int = 21,
    recent_mid_days: int = 28,
) -> pd.DataFrame:
    w = workouts_df.copy()
    w["date"] = pd.to_datetime(w["date"], errors="coerce")
    u = users_df.copy()
    u["user_id"] = u["user_id"].astype(int)
    if "gender" not in u.columns:
        u["gender"] = "m"
    u["gender"] = u["gender"].fillna("m").astype(str).str.lower().str[0].replace({"ж": "f", "м": "m"})

    w = w.merge(u[["user_id", "gender"]], on="user_id", how="left")
    if not intervals_df.empty:
        w2u = w[["workout_id", "user_id", "gender"]].drop_duplicates("workout_id")
        ri = intervals_df.merge(w2u[["workout_id", "user_id", "gender"]], on="workout_id", how="left")
    else:
        ri = intervals_df.copy()
        ri["gender"] = "m"
        ri["user_id"] = pd.NA

    ri = _row_level_intervals(ri, u.set_index("user_id")["gender"])
    blocks = _block_projections(ri)
    iwa = _interval_aggregates(ri, blocks=blocks)
    ww = _row_level_workouts(w)
    ww = _merge_interval_aggregates(ww, iwa)

    races = races_df.copy()
    races["date"] = pd.to_datetime(races["date"], errors="coerce")
    user_max_hr = pd.to_numeric(u.set_index("user_id")["max_heart_rate"], errors="coerce")
    gender_is_female = (u.set_index("user_id")["gender"] == "f").astype(int)

    return _window_features(
        ww=ww,
        user_max_hr=user_max_hr,
        gender_is_female=gender_is_female,
        races=races,
        window_days=window_days,
        hard_fatigue=hard_fatigue,
        easy_fatigue=easy_fatigue,
        easy_long_distance_m=easy_long_distance_m,
        recent_short_days=recent_short_days,
        recent_mid_days=recent_mid_days,
    )


__all__ = ["build_features_v2"]
