#!/usr/bin/env python3
"""Validate a campaign.yaml before any Meta write.

Usage: validate-campaign.py <campaign-dir>

Budget caps come from the environment (META_MAX_DAILY_BUDGET_CENTS and
META_MAX_LIFETIME_BUDGET_CENTS). The shell wrapper loads them from the
client .env. Image size is read from PNG, JPEG, and GIF bytes so macOS
sips is not required.
"""

from __future__ import annotations

import os
import shutil
import struct
import subprocess
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("error: PyYAML is required", file=sys.stderr)
    sys.exit(127)

OBJECTIVES = {
    "outcome_app_promotion",
    "outcome_awareness",
    "outcome_engagement",
    "outcome_leads",
    "outcome_sales",
    "outcome_traffic",
}

CTAS = {
    "apply_now",
    "book_travel",
    "buy_now",
    "contact_us",
    "download",
    "get_offer",
    "get_quote",
    "learn_more",
    "no_button",
    "open_link",
    "shop_now",
    "sign_up",
    "subscribe",
    "watch_more",
}

EVENTS = {
    "add_payment_info",
    "add_to_cart",
    "add_to_wishlist",
    "complete_registration",
    "contact",
    "content_view",
    "customize_product",
    "donate",
    "find_location",
    "initiated_checkout",
    "lead",
    "other",
    "purchase",
    "schedule",
    "search",
    "start_trial",
    "submit_application",
    "subscribe",
}

SPECIAL = {
    "NONE",
    "CREDIT",
    "EMPLOYMENT",
    "HOUSING",
    "ISSUES_ELECTIONS_POLITICS",
    "ONLINE_GAMBLING_AND_GAMING",
    "FINANCIAL_PRODUCTS_SERVICES",
}

MIN_PX = 1080


def fail(errors: list[str]) -> None:
    for item in errors:
        print(f"error: {item}", file=sys.stderr)
    sys.exit(1)


def as_str(value: object, label: str, errors: list[str]) -> str | None:
    if not isinstance(value, str) or not value.strip():
        errors.append(f"{label} is required")
        return None
    return value.strip()


def jpeg_size(data: bytes) -> tuple[int, int] | None:
    if data[:2] != b"\xff\xd8":
        return None
    i = 2
    sof = {
        0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7,
        0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF,
    }
    while i < len(data) - 8:
        if data[i] != 0xFF:
            i += 1
            continue
        while i < len(data) and data[i] == 0xFF:
            i += 1
        if i >= len(data):
            return None
        marker = data[i]
        i += 1
        if marker in (0xD8, 0xD9):
            continue
        if marker == 0x01 or 0xD0 <= marker <= 0xD7:
            continue
        if i + 2 > len(data):
            return None
        length = int.from_bytes(data[i : i + 2], "big")
        if length < 2:
            return None
        if marker in sof and i + 7 <= len(data):
            height = int.from_bytes(data[i + 3 : i + 5], "big")
            width = int.from_bytes(data[i + 5 : i + 7], "big")
            return width, height
        i += length
    return None


def image_size(path: Path) -> tuple[int, int] | None:
    data = path.read_bytes()
    if data.startswith(b"\x89PNG\r\n\x1a\n") and len(data) >= 24:
        width, height = struct.unpack(">II", data[16:24])
        return width, height
    if data.startswith((b"GIF87a", b"GIF89a")) and len(data) >= 10:
        width, height = struct.unpack("<HH", data[6:10])
        return width, height
    if data.startswith(b"\xff\xd8"):
        return jpeg_size(data)
    return None


def video_size(path: Path) -> tuple[int, int] | None | str:
    ffprobe = shutil.which("ffprobe")
    if not ffprobe:
        return "skip"
    proc = subprocess.run(
        [
            ffprobe,
            "-v",
            "error",
            "-select_streams",
            "v:0",
            "-show_entries",
            "stream=width,height",
            "-of",
            "csv=p=0:s=x",
            str(path),
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        return "error"
    line = proc.stdout.strip().splitlines()[0] if proc.stdout.strip() else ""
    parts = line.split("x")
    if len(parts) != 2 or not parts[0].isdigit() or not parts[1].isdigit():
        return "error"
    return int(parts[0]), int(parts[1])


def resolve_asset(campaign: Path, rel: object, label: str, errors: list[str]) -> Path | None:
    if not isinstance(rel, str) or not rel.strip():
        errors.append(f"{label} path must be a string")
        return None
    rel_path = Path(rel)
    if rel_path.is_absolute() or ".." in rel_path.parts:
        errors.append(f"{label} must stay inside the campaign folder")
        return None
    path = (campaign / rel_path).resolve()
    try:
        path.relative_to(campaign)
    except ValueError:
        errors.append(f"{label} must stay inside the campaign folder")
        return None
    if not path.is_file():
        errors.append(f"{label} file not found: {rel}")
        return None
    return path


def cents(value: object, label: str, errors: list[str]) -> int | None:
    if isinstance(value, bool) or not isinstance(value, int):
        errors.append(f"{label} must be an integer number of cents")
        return None
    if value < 0:
        errors.append(f"{label} must be zero or more")
        return None
    return value


def check_cap(amount: int, env_name: str, errors: list[str]) -> None:
    raw = os.environ.get(env_name, "")
    if raw == "":
        errors.append(f"{env_name} is not set in the client .env")
        return
    if not raw.isdigit():
        errors.append(f"{env_name} must be an integer number of cents")
        return
    cap = int(raw)
    if amount > cap:
        errors.append(f"budget {amount} exceeds {env_name}={cap}")


def main() -> None:
    if len(sys.argv) != 2:
        print("usage: validate-campaign.py <campaign-dir>", file=sys.stderr)
        sys.exit(2)
    campaign = Path(sys.argv[1]).resolve()
    spec_path = campaign / "campaign.yaml"
    if not spec_path.is_file():
        fail([f"missing {spec_path}"])

    try:
        spec = yaml.safe_load(spec_path.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        fail([f"campaign.yaml is not valid YAML: {exc}"])
    if not isinstance(spec, dict):
        fail(["campaign.yaml must be a mapping"])

    errors: list[str] = []
    warnings: list[str] = []

    account = spec.get("ad_account_id")
    if not isinstance(account, str) or not account.startswith("act_") or not account[4:].isdigit():
        errors.append("ad_account_id must look like act_<digits>")

    camp = spec.get("campaign")
    if not isinstance(camp, dict):
        errors.append("campaign mapping is required")
        camp = {}
    as_str(camp.get("name"), "campaign.name", errors)
    objective = camp.get("objective")
    if objective not in OBJECTIVES:
        errors.append(
            "campaign.objective must be one of: " + ", ".join(sorted(OBJECTIVES))
        )
    daily = camp.get("daily_budget_cents", None)
    lifetime = camp.get("lifetime_budget_cents", None)
    daily_set = daily is not None
    life_set = lifetime is not None
    if daily_set == life_set:
        errors.append("set exactly one of campaign.daily_budget_cents or campaign.lifetime_budget_cents")
    if daily_set:
        amount = cents(daily, "campaign.daily_budget_cents", errors)
        if amount is not None:
            check_cap(amount, "META_MAX_DAILY_BUDGET_CENTS", errors)
    if life_set:
        amount = cents(lifetime, "campaign.lifetime_budget_cents", errors)
        if amount is not None:
            check_cap(amount, "META_MAX_LIFETIME_BUDGET_CENTS", errors)

    categories = camp.get("special_ad_categories", ["NONE"])
    if isinstance(categories, str):
        categories = [categories]
    if not isinstance(categories, list) or not categories:
        errors.append("campaign.special_ad_categories must be a non-empty list")
    else:
        unknown = [str(item) for item in categories if item not in SPECIAL]
        if unknown:
            errors.append("unknown special_ad_categories: " + ", ".join(unknown))
        elif categories != ["NONE"]:
            errors.append(
                "special_ad_categories other than NONE cannot be launched by this harness yet; "
                "the CLI chain does not send the field"
            )

    adset = spec.get("adset")
    if not isinstance(adset, dict):
        errors.append("adset mapping is required")
        adset = {}
    as_str(adset.get("name"), "adset.name", errors)
    goal = adset.get("optimization_goal")
    if not isinstance(goal, str) or not goal.isupper() or not goal.replace("_", "").isalnum():
        errors.append("adset.optimization_goal must be UPPERCASE")
        goal = ""
    billing = adset.get("billing_event")
    if not isinstance(billing, str) or not billing.isupper() or not billing.replace("_", "").isalnum():
        errors.append("adset.billing_event must be UPPERCASE")
    countries = adset.get("countries")
    if not isinstance(countries, list) or not countries:
        errors.append("adset.countries must be a non-empty list of ISO codes")
    else:
        for code in countries:
            if not isinstance(code, str) or len(code) != 2 or not code.isalpha() or not code.isupper():
                errors.append(f"country code must be two uppercase letters, got {code!r}")
    event = adset.get("custom_event_type")
    pixel = adset.get("pixel_id")
    if isinstance(pixel, int) and not isinstance(pixel, bool):
        pixel = str(pixel)
    if goal == "OFFSITE_CONVERSIONS":
        if not isinstance(pixel, str) or not pixel.isdigit():
            errors.append("adset.pixel_id is required for OFFSITE_CONVERSIONS and must be digits")
        if event not in EVENTS:
            errors.append("adset.custom_event_type is required for OFFSITE_CONVERSIONS")
    elif event is not None:
        errors.append(
            "adset.custom_event_type is only valid when optimization_goal is OFFSITE_CONVERSIONS"
        )

    creatives = spec.get("creatives")
    names: set[str] = set()
    if not isinstance(creatives, list) or not creatives:
        errors.append("creatives must be a non-empty list")
        creatives = []
    for index, creative in enumerate(creatives):
        label = f"creatives[{index}]"
        if not isinstance(creative, dict):
            errors.append(f"{label} must be a mapping")
            continue
        name = as_str(creative.get("name"), f"{label}.name", errors)
        if name is not None:
            if name in names:
                errors.append(f"duplicate creative name {name}")
            names.add(name)
        has_image = creative.get("image") not in (None, "")
        has_video = creative.get("video") not in (None, "")
        if has_image == has_video:
            errors.append(f"{label} needs exactly one of image or video")
        if has_image:
            path = resolve_asset(campaign, creative.get("image"), f"{label}.image", errors)
            if path is not None:
                size = image_size(path)
                if size is None:
                    errors.append(f"{label}.image must be PNG, JPEG, or GIF")
                elif size[0] < MIN_PX or size[1] < MIN_PX:
                    errors.append(
                        f"{label}.image is {size[0]}x{size[1]}; both sides must be >= {MIN_PX}"
                    )
        if has_video:
            path = resolve_asset(campaign, creative.get("video"), f"{label}.video", errors)
            if path is not None:
                size = video_size(path)
                if size == "skip":
                    warnings.append(f"{label}.video exists; ffprobe is not installed, so dimensions were not checked")
                elif size == "error" or size is None:
                    errors.append(f"{label}.video dimensions could not be read with ffprobe")
                elif size[0] < MIN_PX or size[1] < MIN_PX:
                    errors.append(
                        f"{label}.video is {size[0]}x{size[1]}; both sides must be >= {MIN_PX}"
                    )
        page = creative.get("page_id")
        if isinstance(page, int) and not isinstance(page, bool):
            page = str(page)
        if not isinstance(page, str) or not page.isdigit():
            errors.append(f"{label}.page_id must be digits")
        as_str(creative.get("body"), f"{label}.body", errors)
        as_str(creative.get("title"), f"{label}.title", errors)
        link = creative.get("link_url")
        if not isinstance(link, str) or not link.startswith("https://"):
            errors.append(f"{label}.link_url must start with https://")
        if creative.get("cta") not in CTAS:
            errors.append(f"{label}.cta must be a lowercase value from the schema")

    ads = spec.get("ads")
    if not isinstance(ads, list) or not ads:
        errors.append("ads must be a non-empty list")
        ads = []
    for index, ad in enumerate(ads):
        label = f"ads[{index}]"
        if not isinstance(ad, dict):
            errors.append(f"{label} must be a mapping")
            continue
        as_str(ad.get("name"), f"{label}.name", errors)
        ref = ad.get("creative_ref")
        if not isinstance(ref, str) or ref not in names:
            errors.append(f"{label}.creative_ref must match a creatives[].name")

    for item in warnings:
        print(f"warning: {item}", file=sys.stderr)
    if errors:
        fail(errors)
    print(f"ok {campaign}")


if __name__ == "__main__":
    main()
