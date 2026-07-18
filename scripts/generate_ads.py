#!/usr/bin/env python3
"""Generate Integron Technologies FBR advertisement images."""

from __future__ import annotations

import math
import textwrap
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "app" / "assets" / "images"
OUT = ASSETS / "ads"
OUT.mkdir(parents=True, exist_ok=True)

LOGO = ASSETS / "logo.png"
BANNER = ASSETS / "banner.png"

# Integron theme
GREEN = "#157347"
GREEN_DARK = "#0f5132"
GREEN_LIGHT = "#d1e7dd"
GREEN_SOFT = "#ecfdf5"
TEXT = "#1e293b"
MUTED = "#64748b"
WHITE = "#ffffff"
NAVY = "#1e3a5f"
GOLD = "#c9a227"

W, H = 1200, 1200  # square social / WhatsApp friendly


def load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    paths = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/ubuntu/Ubuntu-Bold.ttf" if bold else "/usr/share/fonts/truetype/ubuntu/Ubuntu-Regular.ttf",
    ]
    for p in paths:
        if Path(p).exists():
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def hex_rgb(color: str) -> tuple[int, int, int]:
    c = color.lstrip("#")
    return tuple(int(c[i : i + 2], 16) for i in (0, 2, 4))


def gradient_bg(draw: ImageDraw.ImageDraw, top: str, bottom: str) -> None:
    t = hex_rgb(top)
    b = hex_rgb(bottom)
    for y in range(H):
        ratio = y / max(H - 1, 1)
        c = tuple(int(t[i] + (b[i] - t[i]) * ratio) for i in range(3))
        draw.line([(0, y), (W, y)], fill=c)


def paste_logo(img: Image.Image, box: tuple[int, int, int, int], alpha: bool = True) -> None:
    logo = Image.open(LOGO).convert("RGBA")
    lw, lh = box[2] - box[0], box[3] - box[1]
    logo.thumbnail((lw, lh), Image.Resampling.LANCZOS)
    x = box[0] + (lw - logo.width) // 2
    y = box[1] + (lh - logo.height) // 2
    if alpha:
        img.paste(logo, (x, y), logo)
    else:
        img.paste(logo, (x, y))


def paste_banner(img: Image.Image, box: tuple[int, int, int, int]) -> None:
    banner = Image.open(BANNER).convert("RGBA")
    bw, bh = box[2] - box[0], box[3] - box[1]
    banner = banner.resize((bw, bh), Image.Resampling.LANCZOS)
    img.paste(banner, (box[0], box[1]), banner)


def rounded_rect(draw: ImageDraw.ImageDraw, xy, radius: int, fill, outline=None, width: int = 1) -> None:
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)


def draw_footer(draw: ImageDraw.ImageDraw, y: int = None, dark: bool = True) -> None:
    y = y or H - 110
    bg = hex_rgb(GREEN_DARK if dark else GREEN_LIGHT)
    draw.rectangle([(0, y), (W, H)], fill=bg)
    f = load_font(26)
    fb = load_font(28, bold=True)
    fg = WHITE if dark else hex_rgb(GREEN_DARK)
    draw.text((40, y + 18), "Call:", font=fb, fill=fg)
    draw.text((120, y + 18), "03061111787  |  03334370073", font=f, fill=fg)
    draw.text((40, y + 58), "Web:", font=fb, fill=fg)
    draw.text((120, y + 58), "fbr-integration-cf69013f2b10.herokuapp.com", font=load_font(22), fill=fg)
    draw.text((40, y + 92), "Support:", font=fb, fill=fg)
    draw.text((160, y + 92), "subhani.lhr57@gmail.com", font=f, fill=fg)


def draw_badge(draw, text, x, y, bg=GREEN, fg=WHITE, pad=16):
    f = load_font(22, bold=True)
    bbox = draw.textbbox((0, 0), text, font=f)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    rounded_rect(draw, (x, y, x + tw + pad * 2, y + th + pad), 20, fill=bg)
    draw.text((x + pad, y + pad // 2), text, font=f, fill=fg)


def draw_check_list(draw, items, x, y, size=30, color=GREEN):
    f = load_font(size)
    cy = y
    for item in items:
        draw.ellipse((x, cy + 4, x + 28, cy + 32), fill=color)
        draw.text((x + 9, cy + 2), "✓", font=load_font(22, bold=True), fill=WHITE)
        draw.text((x + 40, cy), item, font=f, fill=hex_rgb(TEXT))
        cy += size + 18


def draw_dashboard_mock(draw, x, y, w, h):
    rounded_rect(draw, (x, y, x + w, y + h), 18, fill=WHITE, outline=GREEN_LIGHT, width=3)
    rounded_rect(draw, (x, y, x + w, y + 52), 12, fill=GREEN)
    draw.text((x + 16, y + 12), "Integron Dashboard", font=load_font(22, bold=True), fill=WHITE)
    cards = [("Total Invoices", "248"), ("Success Rate", "100%"), ("FBR Posted", "248")]
    cw = (w - 48) // 3
    for i, (label, val) in enumerate(cards):
        cx = x + 16 + i * (cw + 8)
        cy = y + 68
        rounded_rect(draw, (cx, cy, cx + cw, cy + 90), 10, fill=GREEN_SOFT)
        draw.text((cx + 12, cy + 10), label, font=load_font(16), fill=hex_rgb(MUTED))
        draw.text((cx + 12, cy + 38), val, font=load_font(32, bold=True), fill=hex_rgb(GREEN))


def ad_01_corporate_integration() -> Image.Image:
    """Style inspired by Axiom Square — sky + corporate."""
    img = Image.new("RGB", (W, H), WHITE)
    draw = ImageDraw.Draw(img)
    gradient_bg(draw, "#87CEEB", "#e8f4fc")
    # building silhouette bottom
    for i in range(0, W, 80):
        bh = 120 + (i % 5) * 40
        draw.rectangle([(i, H - 280 - bh), (i + 60, H - 280)], fill=(30, 58, 95))
    draw.rectangle([(0, H - 280), (W, H - 110)], fill=(245, 248, 252))
    paste_logo(img, (40, 30, 200, 170))
    draw.text((220, 55), "Integron Technologies", font=load_font(38, bold=True), fill=hex_rgb(NAVY))
    draw.text((220, 105), "FBR Digital Invoicing", font=load_font(26), fill=hex_rgb(GREEN))
    draw_badge(draw, "FBR PAKISTAN COMPLIANT", W - 340, 40, bg=GREEN)
    title = "FBR Digital Invoicing"
    draw.text((W // 2 - 280, 220), title, font=load_font(52, bold=True), fill=hex_rgb(NAVY))
    rounded_rect(draw, (W // 2 - 200, 290, W // 2 + 200, 360), 12, fill=(255, 255, 255, 200))
    draw.text((W // 2 - 150, 300), "INTEGRATION", font=load_font(56, bold=True), fill=hex_rgb(GREEN))
    rounded_rect(draw, (80, 400, W - 80, 470), 8, fill=GOLD)
    for i, t in enumerate(["GLITCH-FREE", "100% FBR COMPLIANT", "EASY TO USE"]):
        draw.text((120 + i * 340, 420), f"✓  {t}", font=load_font(26, bold=True), fill=WHITE)
    services = ["Smart Invoice System", "Modern Bookkeeping", "Sales Tax Filing", "Bulk Upload"]
    draw.text((W // 2 - 220, 520), "[ " + "  ·  ".join(services) + " ]", font=load_font(28), fill=hex_rgb(NAVY))
    draw_footer(draw)
    return img


def ad_02_dashboard_automation() -> Image.Image:
    """Style inspired by FIB — dashboard + features."""
    img = Image.new("RGB", (W, H), hex_rgb(GREEN_SOFT))
    draw = ImageDraw.Draw(img)
    rounded_rect(draw, (0, 0, W, 140), 0, fill=GREEN)
    paste_logo(img, (30, 20, 120, 120))
    draw.text((130, 35), "Integron Technologies", font=load_font(34, bold=True), fill=WHITE)
    draw.text((130, 80), "SMART INVOICING · FBR COMPLIANT", font=load_font(20), fill=GREEN_LIGHT)
    draw_badge(draw, "FBR COMPLIANT", W - 260, 45, bg=WHITE, fg=GREEN)
    draw.text((40, 170), "Automate Your", font=load_font(40), fill=hex_rgb(TEXT))
    draw.text((40, 220), "FBR DIGITAL", font=load_font(44, bold=True), fill=hex_rgb(GREEN_DARK))
    draw.text((40, 275), "INVOICING", font=load_font(44, bold=True), fill=hex_rgb(GREEN_DARK))
    draw.text((40, 335), "Save Time. Stay Compliant.", font=load_font(26), fill=hex_rgb(MUTED))
    features = [
        "FBR Compliant — seamless integration",
        "Real-time Processing — instant validation",
        "ERP / System Integration",
        "Bulk Invoice Handling",
        "Smart Dashboard & Reports",
    ]
    draw_check_list(draw, features, 40, 390, size=26)
    draw_dashboard_mock(draw, 560, 150, 600, 400)
    rounded_rect(draw, (40, 620, W - 40, 720), 16, fill=GREEN_DARK)
    draw.text((60, 645), "BOOK YOUR FREE DEMO TODAY!", font=load_font(36, bold=True), fill=WHITE)
    draw.text((60, 695), "Try: testaccount@gmail.com  |  Demo video available on request", font=load_font(22), fill=GREEN_LIGHT)
    draw_footer(draw, 760)
    return img


def ad_03_feature_showcase() -> Image.Image:
    """Style inspired by SMI Soft — feature list + devices."""
    img = Image.new("RGB", (W, H), WHITE)
    draw = ImageDraw.Draw(img)
    paste_logo(img, (40, 30, 160, 150))
    draw.text((180, 50), "Integron Technologies", font=load_font(36, bold=True), fill=hex_rgb(GREEN_DARK))
    draw.text((180, 95), "Quality FBR Integration Platform", font=load_font(22), fill=hex_rgb(MUTED))
    draw_badge(draw, "FBR COMPLIANT", W - 250, 50)
    draw.text((W // 2 - 280, 180), "FBR DIGITAL INVOICING", font=load_font(46, bold=True), fill=hex_rgb(GREEN_DARK))
    draw.text((W // 2 - 340, 245), "A Smart, Reliable & FBR Compliant Solution for Your Business", font=load_font(24), fill=hex_rgb(TEXT))
    draw_badge(draw, "S.R.O 350 COMPLIANCE", 80, 310, bg=GREEN_DARK)
    draw_badge(draw, "FBR INTEGRATED", 420, 310, bg=WHITE, fg=GREEN)
    rounded_rect(draw, (60, 380, 520, 430), 12, fill=GREEN_DARK)
    draw.text((90, 392), "CORE FEATURES", font=load_font(26, bold=True), fill=WHITE)
    features = [
        "Cloud-based System",
        "Backdate & Real-time Posting",
        "Bulk Invoice Uploading",
        "Auto Fetch Data",
        "Edit Invoice before Post",
        "Sales Summary Excel/PDF",
        "Auto Error Detection",
        "Branded PDF Downloads",
    ]
    draw_check_list(draw, features, 70, 450, size=26)
    # laptop mock
    rounded_rect(draw, (580, 360, 1120, 720), 20, fill="#e2e8f0")
    rounded_rect(draw, (610, 390, 1090, 690), 12, fill=WHITE)
    draw_dashboard_mock(draw, 630, 410, 430, 250)
    rounded_rect(draw, (40, 750, 560, 830), 14, fill=GREEN_SOFT, outline=GREEN, width=2)
    draw.text((70, 770), "FREE DEMO — Try Before You Commit!", font=load_font(28, bold=True), fill=hex_rgb(GREEN_DARK))
    rounded_rect(draw, (600, 750, 1120, 830), 14, fill=GREEN_SOFT, outline=GREEN, width=2)
    draw.text((630, 770), "FREE CUSTOMER SUPPORT — We Are Here to Help!", font=load_font(26, bold=True), fill=hex_rgb(GREEN_DARK))
    draw_footer(draw, 870)
    return img


def ad_04_auth_gradient() -> Image.Image:
    """Matches web auth page green gradient."""
    img = Image.new("RGB", (W, H), hex_rgb(GREEN))
    draw = ImageDraw.Draw(img)
    gradient_bg(draw, GREEN, GREEN_DARK)
    # orbs
    for cx, cy, r, alpha in [(900, 200, 180, 40), (200, 900, 220, 30)]:
        orb = Image.new("RGBA", (r * 2, r * 2), (0, 0, 0, 0))
        od = ImageDraw.Draw(orb)
        od.ellipse((0, 0, r * 2, r * 2), fill=(110, 231, 183, alpha))
        img.paste(orb, (cx - r, cy - r), orb)
    paste_logo(img, (W // 2 - 80, 80, W // 2 + 80, 220))
    draw.text((W // 2 - 280, 240), "Integron Technologies", font=load_font(42, bold=True), fill=WHITE, anchor="ma")
    draw.text((W // 2, 300), "FBR Digital Invoicing", font=load_font(30, bold=True), fill=GREEN_LIGHT, anchor="ma")
    tagline = "Create, validate, and submit sales tax invoices to FBR — all in one place."
    for i, line in enumerate(textwrap.wrap(tagline, 42)):
        draw.text((W // 2, 360 + i * 36), line, font=load_font(24), fill=WHITE, anchor="ma")
    features = [
        "FBR-compliant invoice submission",
        "Branded PDF downloads with your logo",
        "Secure taxpayer dashboard",
        "Bulk upload & real-time validation",
    ]
    for i, item in enumerate(features):
        y = 500 + i * 46
        draw.ellipse((120, y + 4, 148, y + 32), fill=WHITE)
        draw.text((129, y + 2), "✓", font=load_font(22, bold=True), fill=hex_rgb(GREEN_DARK))
        draw.text((160, y), item, font=load_font(26), fill=WHITE)
    draw.text((W // 2, 720), "Trusted FBR Integration Platform", font=load_font(28, bold=True), fill=GREEN_LIGHT, anchor="ma")
    rounded_rect(draw, (200, 780, W - 200, 860), 20, fill=WHITE)
    draw.text((W // 2, 810), "Start Free Demo Today", font=load_font(34, bold=True), fill=hex_rgb(GREEN_DARK), anchor="ma")
    draw_footer(draw, 900, dark=True)
    return img


def ad_05_banner_whatsapp() -> Image.Image:
    """Uses existing banner asset style."""
    img = Image.new("RGB", (W, H), WHITE)
    draw = ImageDraw.Draw(img)
    paste_banner(img, (0, 0, W, 400))
    draw.text((40, 440), "FBR Digital Invoicing Made Simple", font=load_font(44, bold=True), fill=hex_rgb(GREEN_DARK))
    draw.text((40, 510), "Innovate | Integrate | Elevate", font=load_font(30), fill=hex_rgb(MUTED))
    items = ["WhatsApp Support", "Free Demo Available", "FBR Compliant", "Cloud Based"]
    for i, t in enumerate(items):
        x = 40 + (i % 2) * 560
        y = 580 + (i // 2) * 80
        rounded_rect(draw, (x, y, x + 520, y + 60), 12, fill=GREEN_SOFT)
        draw.text((x + 20, y + 14), f"✓  {t}", font=load_font(26, bold=True), fill=hex_rgb(GREEN_DARK))
    rounded_rect(draw, (40, 760, W - 40, 860), 16, fill="#25D366")
    draw.text((W // 2, 800), "Chat on WhatsApp: 03061111787", font=load_font(32, bold=True), fill=WHITE, anchor="ma")
    draw_footer(draw, 900)
    return img


def ad_06_minimal_white() -> Image.Image:
    img = Image.new("RGB", (W, H), WHITE)
    draw = ImageDraw.Draw(img)
    draw.rectangle([(0, 0), (W, 8)], fill=GREEN)
    paste_logo(img, (W // 2 - 100, 60, W // 2 + 100, 200))
    draw.text((W // 2, 240), "Integron Technologies", font=load_font(40, bold=True), fill=hex_rgb(TEXT), anchor="ma")
    draw.text((W // 2, 300), "FBR DIGITAL INVOICING", font=load_font(36, bold=True), fill=hex_rgb(GREEN), anchor="ma")
    draw.line([(200, 360), (W - 200, 360)], fill=GREEN_LIGHT, width=3)
    bullets = [
        "Submit invoices directly to FBR",
        "Real-time validation & error detection",
        "Bulk import from Excel",
        "Professional branded PDFs",
        "Multi-user business accounts",
    ]
    y = 400
    for b in bullets:
        draw.ellipse((180, y + 6, 210, y + 36), fill=GREEN)
        draw.text((195, y + 4), "✓", font=load_font(20, bold=True), fill=WHITE, anchor="ma")
        draw.text((230, y), b, font=load_font(28), fill=hex_rgb(TEXT))
        y += 56
    rounded_rect(draw, (250, 720, W - 250, 800), 30, fill=GREEN)
    draw.text((W // 2, 750), "Request Your Free Demo", font=load_font(32, bold=True), fill=WHITE, anchor="ma")
    draw_footer(draw, 860)
    return img


def ad_07_dark_tech() -> Image.Image:
    img = Image.new("RGB", (W, H), "#0a1628")
    draw = ImageDraw.Draw(img)
    for i in range(20):
        x = (i * 137) % W
        y = (i * 89) % (H - 200)
        draw.ellipse((x, y, x + 4, y + 4), fill=(21, 115, 71, 80))
    paste_logo(img, (50, 40, 150, 140))
    draw.text((170, 55), "INTEGRON", font=load_font(40, bold=True), fill=GREEN_LIGHT)
    draw.text((170, 100), "TECHNOLOGIES", font=load_font(22), fill=MUTED)
    draw.text((50, 200), "NEXT-GEN", font=load_font(36), fill=WHITE)
    draw.text((50, 250), "FBR INTEGRATION", font=load_font(52, bold=True), fill=GREEN_LIGHT)
    draw.text((50, 330), "Secure · Automated · Compliant", font=load_font(28), fill=MUTED)
    draw_dashboard_mock(draw, 50, 400, 520, 320)
    tech = ["API Integration", "Webhook Support", "Audit Logs", "Multi-Company", "Role-Based Access"]
    draw_check_list(draw, tech, 620, 420, size=28, color=GREEN)
    for i, t in enumerate(tech):
        draw.text((660, 420 + i * 46), t, font=load_font(26), fill=WHITE)
    draw_footer(draw, 900)
    return img


def ad_08_landscape_cta() -> Image.Image:
    img = Image.new("RGB", (W, H), hex_rgb(GREEN_SOFT))
    draw = ImageDraw.Draw(img)
    rounded_rect(draw, (0, 0, W, 500), 0, fill=GREEN)
    paste_logo(img, (60, 60, 180, 180))
    draw.text((200, 80), "Integron Technologies", font=load_font(38, bold=True), fill=WHITE)
    draw.text((200, 130), "Pakistan's Trusted FBR Invoicing Platform", font=load_font(24), fill=GREEN_LIGHT)
    draw.text((60, 220), "SIMPLIFY INVOICING", font=load_font(56, bold=True), fill=WHITE)
    draw.text((60, 300), "ENSURE COMPLIANCE · GROW YOUR BUSINESS", font=load_font(28), fill=WHITE)
    sectors = ["Manufacturing", "Distribution", "Wholesale", "Retail", "Services"]
    draw.text((60, 540), "TRUSTED BY BUSINESSES ACROSS PAKISTAN", font=load_font(24, bold=True), fill=hex_rgb(GREEN_DARK))
    for i, s in enumerate(sectors):
        x = 60 + i * 220
        rounded_rect(draw, (x, 590, x + 200, 660), 12, fill=WHITE, outline=GREEN, width=2)
        draw.text((x + 100, 620), s, font=load_font(20, bold=True), fill=hex_rgb(GREEN_DARK), anchor="ma")
    rounded_rect(draw, (60, 700, W - 60, 780), 20, fill=GREEN_DARK)
    draw.text((W // 2, 730), "BOOK YOUR FREE DEMO TODAY →", font=load_font(34, bold=True), fill=WHITE, anchor="ma")
    draw.text((W // 2, 820), "fbr-integration-cf69013f2b10.herokuapp.com", font=load_font(26), fill=hex_rgb(GREEN_DARK), anchor="ma")
    draw.text((W // 2, 870), "03061111787  ·  03334370073  ·  subhani.lhr57@gmail.com", font=load_font(24), fill=hex_rgb(MUTED), anchor="ma")
    return img


def ad_09_pakistan_pro() -> Image.Image:
    img = Image.new("RGB", (W, H), WHITE)
    draw = ImageDraw.Draw(img)
    # pakistan colors accent
    draw.rectangle([(0, 0), (W, 12)], fill="#01411C")
    draw.rectangle([(0, 12), (W, 24)], fill=WHITE)
    gradient_bg(draw, "#f0fdf4", WHITE)
    paste_logo(img, (W // 2 - 90, 50, W // 2 + 90, 190))
    draw.text((W // 2, 220), "Integron Technologies", font=load_font(40, bold=True), fill=hex_rgb(GREEN_DARK), anchor="ma")
    draw.text((W // 2, 275), "FBR DIGITAL INVOICING FOR PAKISTAN", font=load_font(30, bold=True), fill=hex_rgb(GREEN), anchor="ma")
    draw_badge(draw, "FBR COMPLIANT SOLUTION", W // 2 - 160, 330)
    rounded_rect(draw, (80, 400, W - 80, 700), 20, fill=WHITE, outline=GREEN, width=3)
    pillars = [
        ("Compliance", "Full S.R.O 350 & FBR integration"),
        ("Efficiency", "Bulk upload, auto-validation, reports"),
        ("Support", "Dedicated help via email & phone"),
    ]
    for i, (title, desc) in enumerate(pillars):
        x = 120 + i * 340
        draw.text((x, 440), title, font=load_font(32, bold=True), fill=hex_rgb(GREEN_DARK))
        for j, line in enumerate(textwrap.wrap(desc, 22)):
            draw.text((x, 490 + j * 32), line, font=load_font(22), fill=hex_rgb(TEXT))
    draw.text((W // 2, 760), "Made in Pakistan · Built for Pakistani Businesses", font=load_font(26, bold=True), fill=hex_rgb(GREEN_DARK), anchor="ma")
    draw_footer(draw, 820)
    return img


def ad_10_demo_trial() -> Image.Image:
    img = Image.new("RGB", (W, H), WHITE)
    draw = ImageDraw.Draw(img)
    gradient_bg(draw, GREEN_SOFT, WHITE)
    paste_logo(img, (40, 40, 140, 140))
    draw.text((160, 60), "Integron Technologies", font=load_font(34, bold=True), fill=hex_rgb(GREEN_DARK))
    draw.text((W // 2, 200), "TRY IT FREE", font=load_font(64, bold=True), fill=hex_rgb(GREEN), anchor="ma")
    draw.text((W // 2, 290), "Live Demo Available", font=load_font(36), fill=hex_rgb(TEXT), anchor="ma")
    rounded_rect(draw, (150, 360, W - 150, 520), 20, fill=WHITE, outline=GREEN, width=3)
    draw.text((W // 2, 390), "Test Account Credentials", font=load_font(28, bold=True), fill=hex_rgb(GREEN_DARK), anchor="ma")
    draw.text((W // 2, 440), "Email: testaccount@gmail.com", font=load_font(30), fill=hex_rgb(TEXT), anchor="ma")
    draw.text((W // 2, 485), "Password: testing1234", font=load_font(30), fill=hex_rgb(TEXT), anchor="ma")
    rounded_rect(draw, (150, 560, W - 150, 640), 16, fill=GREEN)
    draw.text((W // 2, 590), "Watch Free Demo Video on Google Drive", font=load_font(28, bold=True), fill=WHITE, anchor="ma")
    draw.text((W // 2, 680), "Website: fbr-integration-cf69013f2b10.herokuapp.com", font=load_font(24), fill=hex_rgb(GREEN_DARK), anchor="ma")
    draw_footer(draw, 760)
    return img


def ad_11_services_brackets() -> Image.Image:
    img = Image.new("RGB", (W, H), "#e8f4fc")
    draw = ImageDraw.Draw(img)
    gradient_bg(draw, "#87CEEB", "#f8fafc")
    paste_logo(img, (40, 30, 170, 150))
    draw.text((190, 55), "Integron Technologies", font=load_font(34, bold=True), fill=hex_rgb(NAVY))
    draw_badge(draw, "FBR COMPLIANT", W - 240, 50)
    draw.text((W // 2, 200), "FBR Digital Invoicing", font=load_font(50, bold=True), fill=hex_rgb(NAVY), anchor="ma")
    draw.text((W // 2, 270), "INTEGRATION", font=load_font(58, bold=True), fill=hex_rgb(GREEN), anchor="ma")
    services = [
        "Invoice Creation & Validation",
        "FBR Submission & Tracking",
        "Bulk Excel Import",
        "Recurring Invoices",
        "Sales Reports & Analytics",
        "API & Webhook Integration",
    ]
    draw.text((W // 2, 360), "[", font=load_font(120, bold=True), fill=hex_rgb(NAVY), anchor="ma")
    y = 400
    for s in services:
        draw.text((W // 2, y), s, font=load_font(30), fill=hex_rgb(NAVY), anchor="ma")
        y += 48
    draw.text((W // 2, y + 20), "]", font=load_font(120, bold=True), fill=hex_rgb(NAVY), anchor="ma")
    for i, t in enumerate(["GLITCH-FREE", "100% COMPLIANT", "EASY TO USE"]):
        draw.text((120 + i * 340, 780), f"✓ {t}", font=load_font(26, bold=True), fill=hex_rgb(GREEN_DARK))
    draw_footer(draw, 850)
    return img


def ad_12_icon_grid() -> Image.Image:
    img = Image.new("RGB", (W, H), WHITE)
    draw = ImageDraw.Draw(img)
    rounded_rect(draw, (0, 0, W, 130), 0, fill=GREEN_DARK)
    paste_logo(img, (30, 15, 110, 115))
    draw.text((120, 40), "Integron Technologies", font=load_font(32, bold=True), fill=WHITE)
    draw.text((120, 80), "Complete FBR Digital Solution", font=load_font(22), fill=GREEN_LIGHT)
    icons = [
        ("FBR Integration", "Direct posting"),
        ("Real-time Validation", "Instant checks"),
        ("Secure Data", "Encrypted & safe"),
        ("Easy Setup", "Quick onboarding"),
        ("Dedicated Support", "Always available"),
        ("Multi-User", "Team access"),
    ]
    for i, (title, sub) in enumerate(icons):
        col, row = i % 3, i // 3
        x, y = 60 + col * 380, 180 + row * 280
        rounded_rect(draw, (x, y, x + 340, y + 240), 18, fill=GREEN_SOFT, outline=GREEN, width=2)
        draw.ellipse((x + 130, y + 30, x + 210, y + 110), fill=GREEN)
        draw.text((x + 170, y + 58), "✓", font=load_font(36, bold=True), fill=WHITE, anchor="ma")
        draw.text((x + 170, y + 130), title, font=load_font(24, bold=True), fill=hex_rgb(GREEN_DARK), anchor="ma")
        draw.text((x + 170, y + 175), sub, font=load_font(20), fill=hex_rgb(MUTED), anchor="ma")
    rounded_rect(draw, (200, 780, W - 200, 860), 24, fill=GREEN)
    draw.text((W // 2, 810), "Get Started — Free Demo Available", font=load_font(30, bold=True), fill=WHITE, anchor="ma")
    draw.text((W // 2, 900), "03061111787  |  03334370073  |  subhani.lhr57@gmail.com", font=load_font(22), fill=hex_rgb(GREEN_DARK), anchor="ma")
    draw.text((W // 2, 940), "fbr-integration-cf69013f2b10.herokuapp.com", font=load_font(22), fill=hex_rgb(MUTED), anchor="ma")
    return img


def ad_13_contact_card() -> Image.Image:
    img = Image.new("RGB", (W, H), hex_rgb(GREEN))
    draw = ImageDraw.Draw(img)
    gradient_bg(draw, GREEN, "#0a3d26")
    paste_logo(img, (W // 2 - 70, 80, W // 2 + 70, 210))
    draw.text((W // 2, 250), "Contact Integron Technologies", font=load_font(38, bold=True), fill=WHITE, anchor="ma")
    draw.text((W // 2, 310), "FBR Digital Invoicing Support", font=load_font(26), fill=GREEN_LIGHT, anchor="ma")
    contacts = [
        ("Phone", "03061111787"),
        ("Phone", "03334370073"),
        ("Website", "fbr-integration-cf69013f2b10.herokuapp.com"),
        ("Email", "subhani.lhr57@gmail.com"),
        ("Demo", "testaccount@gmail.com / testing1234"),
    ]
    y = 380
    for label, value in contacts:
        rounded_rect(draw, (120, y, W - 120, y + 80), 14, fill="#1a6b45")
        draw.rectangle((120, y, 280, y + 80), fill=hex_rgb(WHITE))
        draw.text((200, y + 22), label, font=load_font(24, bold=True), fill=hex_rgb(GREEN_DARK), anchor="ma")
        draw.text((310, y + 22), value, font=load_font(24), fill=WHITE)
        y += 100
    draw.text((W // 2, 980), "No hidden fees · Free demo · FBR Compliant", font=load_font(24, bold=True), fill=GREEN_LIGHT, anchor="ma")
    draw.text((W // 2, 1030), "Integron Technologies — Innovate | Integrate | Elevate", font=load_font(20), fill=WHITE, anchor="ma")
    return img


def ad_14_reports_analytics() -> Image.Image:
    img = Image.new("RGB", (W, H), hex_rgb(GREEN_SOFT))
    draw = ImageDraw.Draw(img)
    paste_logo(img, (40, 30, 130, 120))
    draw.text((150, 45), "Integron Technologies", font=load_font(32, bold=True), fill=hex_rgb(GREEN_DARK))
    draw.text((40, 150), "Track Every Invoice.", font=load_font(44), fill=hex_rgb(TEXT))
    draw.text((40, 210), "Stay FBR Compliant.", font=load_font(44, bold=True), fill=hex_rgb(GREEN))
    draw.text((40, 290), "Dashboard · Reports · Audit Logs · Excel Export", font=load_font(26), fill=hex_rgb(MUTED))
    # chart mock
    rounded_rect(draw, (40, 360, 700, 780), 16, fill=WHITE, outline=GREEN, width=2)
    draw.text((60, 380), "Sales Summary Report", font=load_font(26, bold=True), fill=hex_rgb(GREEN_DARK))
    for i, h in enumerate([120, 180, 90, 200, 150, 220, 170]):
        bx = 80 + i * 85
        draw.rectangle([(bx, 700 - h), (bx + 50, 700)], fill=GREEN if i % 2 == 0 else GREEN_DARK)
    stats = [
        ("Today's Invoices", "Live count"),
        ("Approved Amount", "Real-time"),
        ("Failed/Cancelled", "Tracked"),
        ("FBR Posted", "Verified"),
    ]
    for i, (t, s) in enumerate(stats):
        y = 360 + i * 110
        rounded_rect(draw, (740, y, 1140, y + 90), 12, fill=WHITE, outline=GREEN_LIGHT, width=2)
        draw.text((760, y + 15), t, font=load_font(22, bold=True), fill=hex_rgb(GREEN_DARK))
        draw.text((760, y + 50), s, font=load_font(20), fill=hex_rgb(MUTED))
    draw_footer(draw, 820)
    return img


def ad_15_social_square() -> Image.Image:
    """Compact social media post."""
    img = Image.new("RGB", (W, H), WHITE)
    draw = ImageDraw.Draw(img)
    rounded_rect(draw, (30, 30, W - 30, H - 30), 24, fill=GREEN_SOFT, outline=GREEN, width=4)
    paste_logo(img, (W // 2 - 80, 80, W // 2 + 80, 220))
    draw.text((W // 2, 260), "Integron", font=load_font(48, bold=True), fill=hex_rgb(GREEN_DARK), anchor="ma")
    draw.text((W // 2, 320), "TECHNOLOGIES", font=load_font(24), fill=hex_rgb(MUTED), anchor="ma")
    draw.text((W // 2, 400), "FBR", font=load_font(72, bold=True), fill=hex_rgb(GREEN), anchor="ma")
    draw.text((W // 2, 490), "DIGITAL INVOICING", font=load_font(36, bold=True), fill=hex_rgb(GREEN_DARK), anchor="ma")
    draw.text((W // 2, 560), "Create · Validate · Submit", font=load_font(28), fill=hex_rgb(TEXT), anchor="ma")
    rounded_rect(draw, (100, 620, W - 100, 700), 20, fill=GREEN)
    draw.text((W // 2, 650), "FREE DEMO AVAILABLE", font=load_font(30, bold=True), fill=WHITE, anchor="ma")
    draw.text((W // 2, 740), "03061111787  ·  03334370073", font=load_font(26, bold=True), fill=hex_rgb(GREEN_DARK), anchor="ma")
    draw.text((W // 2, 790), "fbr-integration-cf69013f2b10.herokuapp.com", font=load_font(20), fill=hex_rgb(MUTED), anchor="ma")
    draw.text((W // 2, 830), "subhani.lhr57@gmail.com", font=load_font(20), fill=hex_rgb(MUTED), anchor="ma")
    draw.text((W // 2, 900), "FBR Compliant · Cloud Based · Pakistani Businesses", font=load_font(22, bold=True), fill=hex_rgb(GREEN_DARK), anchor="ma")
    return img


def ad_master_combined() -> Image.Image:
    """Single premium ad blending all 3 reference advertisement styles."""
    w, h = 1200, 1600
    img = Image.new("RGB", (w, h), WHITE)
    draw = ImageDraw.Draw(img)

    # Sky gradient background (Axiom style)
    t, b = hex_rgb("#87CEEB"), hex_rgb("#f0f8ff")
    for y in range(680):
        ratio = y / 679
        c = tuple(int(t[i] + (b[i] - t[i]) * ratio) for i in range(3))
        draw.line([(0, y), (w, y)], fill=c)

    # Building silhouette right (Axiom)
    for i in range(8):
        bx = 700 + i * 70
        bh = 100 + (i % 4) * 50
        draw.rectangle((bx, 680 - bh, bx + 55, 680), fill=(200, 210, 225))
    draw.rectangle((0, 680, w, h), fill=hex_rgb(GREEN_SOFT))

    # Header
    paste_logo(img, (40, 28, 150, 138))
    draw.text((165, 42), "Integron Technologies", font=load_font(34, bold=True), fill=hex_rgb(NAVY))
    draw.text((165, 82), "SMART INVOICING · FBR COMPLIANT", font=load_font(18), fill=hex_rgb(GREEN))
    draw_badge(draw, "FBR COMPLIANT", w - 250, 40, bg=GREEN)
    draw_badge(draw, "S.R.O 350", w - 250, 95, bg=GREEN_DARK)

    # Main headline (Axiom + FIB)
    draw.text((w // 2, 175), "FBR Digital Invoicing", font=load_font(52, bold=True), fill=hex_rgb(NAVY), anchor="ma")
    rounded_rect(draw, (w // 2 - 175, 235, w // 2 + 175, 305), 10, fill=GREEN)
    draw.text((w // 2, 255), "INTEGRATION!", font=load_font(50, bold=True), fill=WHITE, anchor="ma")
    draw.text((w // 2, 330), "Automate Your Invoicing — Save Time. Stay Compliant.", font=load_font(26), fill=hex_rgb(TEXT), anchor="ma")

    # Gold feature bars (Axiom)
    bars = ["GLITCH-FREE", "100% FBR COMPLIANT", "EASY TO USE"]
    for i, label in enumerate(bars):
        y = 375 + i * 52
        for x in range(80, w - 80):
            ratio = (x - 80) / (w - 160)
            r = int(201 + (255 - 201) * ratio)
            g = int(162 + (255 - 162) * ratio)
            b = int(39 + (255 - 39) * ratio)
            draw.line([(x, y), (x, y + 42)], fill=(r, g, b))
        draw.ellipse((100, y + 8, 132, y + 36), fill=WHITE)
        draw.text((110, y + 6), "✓", font=load_font(20, bold=True), fill=hex_rgb(GREEN_DARK), anchor="ma")
        draw.text((150, y + 8), label, font=load_font(26, bold=True), fill=WHITE)

    # Left: Core features (SMI Soft)
    rounded_rect(draw, (50, 560, 420, 610), 12, fill=GREEN_DARK)
    draw.text((80, 572), "CORE FEATURES", font=load_font(24, bold=True), fill=WHITE)
    features = [
        "Cloud-based System",
        "Real-time FBR Posting",
        "Bulk Invoice Upload",
        "Auto Error Detection",
        "Sales Reports Excel/PDF",
        "Branded PDF Downloads",
    ]
    fy = 630
    for feat in features:
        draw.ellipse((60, fy + 2, 88, fy + 30), fill=GREEN)
        draw.text((69, fy), "✓", font=load_font(18, bold=True), fill=WHITE, anchor="ma")
        draw.text((100, fy), feat, font=load_font(22), fill=hex_rgb(TEXT))
        fy += 38

    # Right: Dashboard mock (FIB)
    draw_dashboard_mock(draw, 460, 540, 700, 360)
    draw.text((460, 920), "Good Morning! Here's your invoice overview", font=load_font(20, bold=True), fill=hex_rgb(GREEN_DARK))

    # Value icons row (FIB)
    values = [
        ("FBR Compliant", "Shield"),
        ("Save Time", "Clock"),
        ("Secure & Reliable", "Lock"),
        ("Boost Productivity", "Chart"),
    ]
    for i, (title, _) in enumerate(values):
        x = 50 + i * 280
        rounded_rect(draw, (x, 960, x + 260, 1050), 14, fill=WHITE, outline=GREEN, width=2)
        draw.ellipse((x + 15, 980, x + 55, 1020), fill=GREEN)
        draw.text((x + 35, 990), "✓", font=load_font(20, bold=True), fill=WHITE, anchor="ma")
        draw.text((x + 70, 988), title, font=load_font(20, bold=True), fill=hex_rgb(GREEN_DARK))

    # Services in brackets (Axiom)
    services = ["Smart Invoice System", "Modern Bookkeeping", "Sales Tax Filing"]
    draw.text((w // 2, 1090), "[", font=load_font(80, bold=True), fill=hex_rgb(NAVY), anchor="ma")
    sy = 1120
    for s in services:
        draw.text((w // 2, sy), s, font=load_font(28), fill=hex_rgb(NAVY), anchor="ma")
        sy += 42
    draw.text((w // 2, sy + 10), "]", font=load_font(80, bold=True), fill=hex_rgb(NAVY), anchor="ma")

    # CTA boxes (SMI + FIB)
    rounded_rect(draw, (50, 1280, 570, 1355), 14, fill=GREEN_SOFT, outline=GREEN, width=2)
    draw.text((80, 1305), "FREE DEMO — Try: testaccount@gmail.com", font=load_font(24, bold=True), fill=hex_rgb(GREEN_DARK))
    rounded_rect(draw, (600, 1280, 1150, 1355), 14, fill=GREEN)
    draw.text((875, 1305), "BOOK YOUR FREE DEMO TODAY!", font=load_font(26, bold=True), fill=WHITE, anchor="ma")

    # Footer
    draw.rectangle((0, h - 120, w, h), fill=hex_rgb(GREEN_DARK))
    fb, f = load_font(28, bold=True), load_font(24)
    fg = hex_rgb(WHITE)
    draw.text((40, h - 100), "Call:", font=fb, fill=fg)
    draw.text((115, h - 100), "03061111787  |  03334370073", font=f, fill=fg)
    draw.text((40, h - 68), "Web:", font=fb, fill=fg)
    draw.text((115, h - 68), "fbr-integration-cf69013f2b10.herokuapp.com", font=load_font(21), fill=fg)
    draw.text((40, h - 36), "Support:", font=fb, fill=fg)
    draw.text((155, h - 36), "subhani.lhr57@gmail.com", font=f, fill=fg)

    return img


ADS = [
    ("01_corporate_integration", ad_01_corporate_integration),
    ("02_dashboard_automation", ad_02_dashboard_automation),
    ("03_feature_showcase", ad_03_feature_showcase),
    ("04_auth_gradient", ad_04_auth_gradient),
    ("05_banner_whatsapp", ad_05_banner_whatsapp),
    ("06_minimal_white", ad_06_minimal_white),
    ("07_dark_tech", ad_07_dark_tech),
    ("08_landscape_cta", ad_08_landscape_cta),
    ("09_pakistan_pro", ad_09_pakistan_pro),
    ("10_demo_trial", ad_10_demo_trial),
    ("11_services_brackets", ad_11_services_brackets),
    ("12_icon_grid", ad_12_icon_grid),
    ("13_contact_card", ad_13_contact_card),
    ("14_reports_analytics", ad_14_reports_analytics),
    ("15_social_square", ad_15_social_square),
]


def main() -> None:
    print(f"Generating {len(ADS)} Integron Technologies advertisements...")
    for name, fn in ADS:
        path = OUT / f"integron_ad_{name}.png"
        img = fn()
        img.save(path, "PNG", optimize=True)
        print(f"  ✓ {path.name}")
    print(f"\nDone! Saved to {OUT}")


if __name__ == "__main__":
    main()
