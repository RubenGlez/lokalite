---
name: Lokalite
colors:
  primary: "#228B3C"
  primary-dark: "#59B85E"
  secondary: "#1168BE"
  secondary-dark: "#6DAFF1"
  accent: "#684FC9"
  accent-dark: "#9B87F1"
  neutral: "#5F6F7E"
  neutral-dark: "#909FAF"
  background: "#F8F9FA"
  background-dark: "#0A0E13"
  surface-sidebar: "#ECEEF1"
  surface-sidebar-dark: "#13181D"
  text: "#1C1F23"
  text-dark: "#F5F5F5"
  warning: "#BF6B1C"
  warning-dark: "#ECA25D"
  danger: "#C9352A"
  danger-dark: "#FF7B72"
  mint: "#108577"
  mint-dark: "#62D2C3"
  pink: "#C0396B"
  pink-dark: "#ED85B0"
  orange: "#B3850E"
  orange-dark: "#F2CC60"
typography:
  h1:
    fontFamily: "-apple-system, BlinkMacSystemFont, Segoe UI, sans-serif"
    fontSize: "24px"
    fontWeight: 700
    lineHeight: 1.2
  h2:
    fontFamily: "-apple-system, BlinkMacSystemFont, Segoe UI, sans-serif"
    fontSize: "18px"
    fontWeight: 650
    lineHeight: 1.3
  body-md:
    fontFamily: "-apple-system, BlinkMacSystemFont, Segoe UI, sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.45
  label:
    fontFamily: "-apple-system, BlinkMacSystemFont, Segoe UI, sans-serif"
    fontSize: "12px"
    fontWeight: 600
    lineHeight: 1.3
  secret-key:
    fontFamily: "SFMono-Regular, Cascadia Mono, ui-monospace, monospace"
    fontSize: "13px"
    fontWeight: 500
    lineHeight: 1.4
rounded:
  xs: "4px"
  sm: "6px"
  md: "8px"
  lg: "12px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "24px"
  2xl: "36px"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "#000000"
    rounded: "{rounded.sm}"
    height: "30px"
    padding: "{spacing.sm} {spacing.lg}"
  button-primary-dark:
    backgroundColor: "{colors.primary-dark}"
    textColor: "{colors.background-dark}"
    rounded: "{rounded.sm}"
    height: "30px"
    padding: "{spacing.sm} {spacing.lg}"
  input:
    backgroundColor: "{colors.background}"
    textColor: "{colors.text}"
    rounded: "{rounded.sm}"
    height: "30px"
    padding: "{spacing.sm} {spacing.md}"
  input-dark:
    backgroundColor: "{colors.background-dark}"
    textColor: "{colors.text-dark}"
    rounded: "{rounded.sm}"
    height: "30px"
    padding: "{spacing.sm} {spacing.md}"
  secret-row:
    backgroundColor: "{colors.background}"
    textColor: "{colors.text}"
    rounded: "{rounded.md}"
    height: "44px"
    padding: "{spacing.sm} {spacing.md}"
  secret-row-dark:
    backgroundColor: "{colors.background-dark}"
    textColor: "{colors.text-dark}"
    rounded: "{rounded.md}"
    height: "44px"
    padding: "{spacing.sm} {spacing.md}"
---

## Overview

Lokalite keeps its current armadillo and terminal-vault visual identity for the multiplatform release. The interface should feel compact, trustworthy, and developer-oriented rather than decorative: dense enough for quick secret lookup, calm enough for security prompts, and native enough to belong on both macOS and Windows. Platform conventions may change control shape, window behavior, and placement, but not the information hierarchy or semantic meaning of color.

## Colors

The green primary is the durable Lokalite brand and the default positive action color. Light mode uses `#228B3C`; dark mode uses the brighter `#59B85E` so the brand remains legible on the near-black `#0A0E13` background. The UI uses `#F8F9FA` / `#0A0E13` for the main canvas, `#ECEEF1` / `#13181D` for sidebars and grouped navigation, and `#1C1F23` / `#F5F5F5` for primary text.

The supporting palette is semantic and stable across platforms:

- Blue (`#1168BE` / `#6DAFF1`) marks links, selection, and informational state.
- Violet (`#684FC9` / `#9B87F1`) identifies one durable project or secret category.
- Amber (`#BF6B1C` / `#ECA25D`) communicates caution and approval-required state.
- Red (`#C9352A` / `#FF7B72`) is reserved for denial, destructive actions, and errors.
- Mint (`#108577` / `#62D2C3`), pink (`#C0396B` / `#ED85B0`), orange (`#B3850E` / `#F2CC60`), and slate (`#5F6F7E` / `#909FAF`) provide the remaining category accents.

Token names express semantic intent and map cleanly to CSS custom properties or W3C DTCG tokens. Every foreground/background pairing still requires an automated contrast check in both themes; category color alone must never carry status or policy meaning.

## Typography

Use the system UI stack, `-apple-system`, `BlinkMacSystemFont`, `Segoe UI`, `sans-serif`, so macOS and Windows retain native text metrics and rendering. Headings are restrained at 24 px and 18 px; body copy is 14 px; compact labels are 12 px. Secret keys and other code-like identifiers use `SFMono-Regular`, `Cascadia Mono`, `ui-monospace`, `monospace` at 13 px. Secret values may use monospace while revealed, but supporting descriptions and security explanations remain in the system UI face for readability.

## Components

Controls use the existing compact 30 px height. Secret and activity rows use 44 px to keep scanning rhythm and pointer targets consistent. The spacing scale is 4, 8, 12, 16, 24, and 36 px; radii are 4, 6, 8, and 12 px. These values are shared across platforms, while native menus, title bars, tray affordances, focus rings, and Windows Hello or LocalAuthentication prompts remain platform-owned.

Primary buttons use brand green and are limited to the clearest action in a view. Inputs and secret rows use neutral surfaces, an 8 px or smaller radius, and visible native focus treatment. Secret names are monospaced; descriptions and metadata remain proportional. Destructive controls use the danger token and require text or icon labeling in addition to color.

The desktop UI exposes secret values only after an explicit reveal action. Masked fields preserve their size when toggled, copy actions give a short non-secret confirmation, and policy badges combine a label with the semantic color. The tray popover and full manager window share these tokens and hierarchy, but their layout follows each operating system rather than forcing pixel-identical chrome.
