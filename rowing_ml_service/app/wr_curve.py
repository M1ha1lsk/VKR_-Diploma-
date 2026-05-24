"""
Кривая мирового рекорда (WR) для гребли на эргометре (C2).

Якорные точки взяты из официальной таблицы WR (мужчины/женщины):
    100м, 500м, 1000м, 2000м, 5000м, 6000м, 10 000м, 21 097м (HM), 42 195м (FM).

Интерполяция — кусочно-линейная в лог-лог-координатах log(T) vs log(D).
Это эквивалент формуле Риделя T = k·D^b, но с **переменной** экспонентой b
на каждом участке между якорями (для гребли b заметно меняется:
≈1.07 на коротких → ≈1.18 на 500–1000м → ≈1.04 на полумарафоне).

За пределами диапазона [100; 42195] используется экстраполяция по крайнему
участку (держим форму Риделя с локальной экспонентой).
"""

from __future__ import annotations

from typing import Union

import numpy as np
import pandas as pd


Num = Union[float, int, np.ndarray, pd.Series]

_WR_ANCHORS: dict[str, list[tuple[float, float]]] = {
    "m": [
        (100.0, 12.4),
        (500.0, 69.8),
        (1000.0, 158.0),
        (2000.0, 333.4),
        (5000.0, 893.8),
        (6000.0, 1084.7),
        (10000.0, 1865.2),
        (21097.0, 4042.7),
        (42195.0, 8406.9),
    ],
    "f": [
        (100.0, 14.6),
        (500.0, 84.5),
        (1000.0, 184.9),
        (2000.0, 381.1),
        (5000.0, 1009.4),
        (6000.0, 1217.7),
        (10000.0, 2133.0),
        (21097.0, 4662.2),
        (42195.0, 9738.3),
    ],
}


def _normalize_gender(g: str | None) -> str:
    if g is None:
        return "m"
    s = str(g).strip().lower()
    if s in ("m", "male", "man", "муж", "мужской", "м"):
        return "m"
    if s in ("f", "female", "woman", "жен", "женский", "ж"):
        return "f"
    return "m"


def _build_log_arrays(gender: str) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    pts = _WR_ANCHORS[_normalize_gender(gender)]
    d = np.array([p[0] for p in pts], dtype=float)
    t = np.array([p[1] for p in pts], dtype=float)
    log_d = np.log(d)
    log_t = np.log(t)
    exps = np.diff(log_t) / np.diff(log_d)
    return log_d, log_t, exps


_LOG_TABLES: dict[str, tuple[np.ndarray, np.ndarray, np.ndarray]] = {
    g: _build_log_arrays(g) for g in ("m", "f")
}


def _as_array(x: Num) -> tuple[np.ndarray, bool, object]:
    if isinstance(x, pd.Series):
        return x.to_numpy(dtype=float, copy=False), False, ("series", x.index)
    if np.isscalar(x):
        return np.array([float(x)], dtype=float), True, ("scalar", None)
    arr = np.asarray(x, dtype=float)
    return arr, False, ("array", None)


def _restore(arr: np.ndarray, is_scalar: bool, origin: tuple[str, object]):
    if is_scalar:
        return float(arr[0])
    kind, idx = origin
    if kind == "series":
        return pd.Series(arr, index=idx)  # type: ignore[arg-type]
    return arr


def _is_array_like(x) -> bool:
    return isinstance(x, (list, tuple, np.ndarray, pd.Series))


def _gender_array(gender, n: int) -> np.ndarray:
    if _is_array_like(gender):
        g = pd.Series(gender).map(_normalize_gender).to_numpy()
        if len(g) == 1 and n > 1:
            g = np.repeat(g, n)
        return g
    return np.repeat(_normalize_gender(gender), n)


def _wr_time_one(arr: np.ndarray, gender_str: str) -> np.ndarray:
    log_d_tab, log_t_tab, _ = _LOG_TABLES[gender_str]
    out = np.full_like(arr, fill_value=np.nan, dtype=float)
    valid = np.isfinite(arr) & (arr > 0)
    if not valid.any():
        return out
    ld = np.log(arr[valid])
    lt = np.interp(ld, log_d_tab, log_t_tab, left=np.nan, right=np.nan)
    below = ld < log_d_tab[0]
    above = ld > log_d_tab[-1]
    if below.any():
        b0 = (log_t_tab[1] - log_t_tab[0]) / (log_d_tab[1] - log_d_tab[0])
        lt = np.where(below, log_t_tab[0] + b0 * (ld - log_d_tab[0]), lt)
    if above.any():
        b_n = (log_t_tab[-1] - log_t_tab[-2]) / (log_d_tab[-1] - log_d_tab[-2])
        lt = np.where(above, log_t_tab[-1] + b_n * (ld - log_d_tab[-1]), lt)
    out[valid] = np.exp(lt)
    return out


def wr_time(distance_m: Num, gender: str | None = "m") -> Num:
    arr, is_scalar, origin = _as_array(distance_m)
    g_arr = _gender_array(gender, len(arr))
    out = np.full_like(arr, fill_value=np.nan, dtype=float)
    for g in ("m", "f"):
        mask = g_arr == g
        if mask.any():
            out[mask] = _wr_time_one(arr[mask], g)
    return _restore(out, is_scalar, origin)


def wr_ratio(time_sec: Num, distance_m: Num, gender: str | None = "m") -> Num:
    wr = wr_time(distance_m, gender)
    if isinstance(time_sec, pd.Series) or isinstance(wr, pd.Series):
        return pd.Series(time_sec) / pd.Series(wr)
    return np.asarray(time_sec, dtype=float) / np.asarray(wr, dtype=float)


def project_via_wr(time_sec: Num, distance_m: Num, gender: str | None = "m") -> Num:
    wr_d = wr_time(distance_m, gender)
    wr2k_m = _WR_ANCHORS["m"][3][1]
    wr2k_f = _WR_ANCHORS["f"][3][1]
    if isinstance(gender, (list, np.ndarray, pd.Series)):
        g = pd.Series(gender).map(_normalize_gender)
        wr2k = g.map({"m": wr2k_m, "f": wr2k_f}).to_numpy()
    else:
        wr2k = wr2k_m if _normalize_gender(gender) == "m" else wr2k_f
    if isinstance(time_sec, pd.Series) or isinstance(wr_d, pd.Series):
        return pd.Series(time_sec) * (
            pd.Series(wr2k) if not np.isscalar(wr2k) else wr2k
        ) / pd.Series(wr_d)
    return np.asarray(time_sec, dtype=float) * np.asarray(wr2k, dtype=float) / np.asarray(
        wr_d,
        dtype=float,
    )


__all__ = [
    "wr_time",
    "wr_ratio",
    "project_via_wr",
]
