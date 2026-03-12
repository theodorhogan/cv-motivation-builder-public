# Quarto CV and Motivation Letter Setup

This project renders two one-page PDF documents from markdown:

- `cv.md`
- `motivation.md`

Both documents use the same shared rendering pipeline:

- Quarto for compilation
- `filters/cv.lua` for markdown-to-layout conversion
- `tex/cv-setup.tex` for typography, spacing, alignment, and custom LaTeX macros

Rendered files are written to `output/`.

## Project structure

- `_quarto.yml`
  Project config. Defines the output directory and which files Quarto renders.
- `_metadata.yml`
  Shared PDF defaults such as paper size, base margins, and the shared TeX include.
- `cv.md`
  Source file for the CV.
- `motivation.md`
  Source file for the motivation letter.
- `filters/cv.lua`
  Shared Lua filter. Interprets the markdown structure and injects the correct LaTeX layout for each document type.
- `tex/cv-setup.tex`
  Shared LaTeX setup. Controls fonts, spacing, section rules, CV rows, bullet formatting, recipient block layout, and motivation body paragraph spacing.
- `output/`
  Generated PDFs and any temporary render output you explicitly create.

## Render commands

Render both documents:

```powershell
quarto render
```

Render only the CV:

```powershell
quarto render cv.md
```

Render only the motivation letter:

```powershell
quarto render motivation.md
```

## How the CV is authored

The CV is intentionally kept clean and close to normal markdown.

### Structure

Use:

- `#` for CV sections
- `##` for company or institution on the left and location on the right
- `###` for role or degree on the left and date on the right
- `-` for bullet points

### Row syntax

For rows with left and right aligned content, separate the two sides with `|`.

Example:

```md
# Experience

## Example Advisory GmbH | Munich, Germany

### Analyst Intern | Jan 2026 -- Jun 2026

- Built valuation models and prepared market update slides
- Supported live transaction workstreams and diligence tracking
```

### Important behavior

- The Lua filter splits `##` and `###` headings on the last `|`.
- This means `### Equity Research | Team Lead | Oct 2025 -- Jan 2026` is valid:
  - left side: `Equity Research | Team Lead`
  - right side: `Oct 2025 -- Jan 2026`
- Bullet lists immediately followed by another `###` use a compact spacing rule so there is no extra gap before the next role line.

## How the motivation letter is authored

The motivation letter uses normal markdown paragraphs plus YAML metadata for the letter-specific header content.

### Structure

- Keep `document.type: motivation` in the front matter.
- Keep `# Cover Letter` as the first heading in the body.
- Write the body as normal markdown paragraphs.
- Add a signature image with normal markdown image syntax if needed.

Example:

```md
# Cover Letter

Dear Ms. Example,

First paragraph.

Second paragraph.

Sincerely,

![](signatures/signature.png){ width=140px }

Max Mustermann
```

### Recipient block

The recipient block is not written in the body. It is generated from YAML metadata:

```yaml
letter:
  title: Cover Letter
  date: March 8, 2026
  recipient:
    - Clara Weiss
    - Vice President
    - Edelweiss Advisory AG
    - Bahnhofstrasse 42,
    - 8001 Zurich
```

Each entry in `letter.recipient` becomes one line in the rendered address block.

## Front matter fields

### Shared `cv` fields

Both `cv.md` and `motivation.md` use these fields:

- `cv.name`
- `cv.availability`
- `cv.phone`
- `cv.email`
- `cv.location`
- `cv.linkedin`

### Motivation-only `letter` fields

Only `motivation.md` uses:

- `letter.title`
- `letter.date`
- `letter.recipient`

### Per-file PDF settings

Each markdown file can override output details in its own front matter, for example:

- `format.pdf.output-file`
- `format.pdf.fontsize`
- `format.pdf.geometry`

Current usage:

- `cv.md` uses `10pt`
- `motivation.md` uses `11pt`

## Layout and spacing

### Where layout is controlled

- `tex/cv-setup.tex`
  Controls nearly all visible layout behavior.
- `filters/cv.lua`
  Decides which macros/environments are used for each markdown element.
- `_metadata.yml`
  Sets global PDF defaults.

### Current spacing model

- Global paragraph spacing is `0pt`.
- CV spacing is manually controlled by custom macros and environments.
- Motivation letter paragraph spacing is applied only inside the `motivationbody` environment, so the CV stays tight.

### Main TeX components

In `tex/cv-setup.tex`:

- `\cvheader`
  CV name and contact line.
- `\motivationheader`
  Motivation letter name and contact line.
- `\letterheading`
  Left-aligned title and right-aligned date row for the letter.
- `recipientblock`
  Vertical address block for the motivation letter.
- `\cvsection`
  Uppercase section heading plus rule.
- `\cvcompany`
  Bold left/right row.
- `\cvposition`
  Italic left/right row.
- `cvitems`
  Standard CV bullet list environment.
- `cvitemscompact`
  Bullet list environment with no trailing gap before the next `###` row.
- `motivationbody`
  Motivation-only paragraph spacing wrapper.

## How the filter works

`filters/cv.lua` checks `document.type`.

If `document.type: cv`:

- `#` becomes `\cvsection{...}`
- `## left | right` becomes `\cvcompany{left}{right}`
- `### left | right` becomes `\cvposition{left}{right}`
- markdown bullet lists become `cvitems` or `cvitemscompact`
- LinkedIn is appended at the bottom from `cv.linkedin`

If `document.type: motivation`:

- the shared motivation header is inserted
- the letter heading and date are built from `letter.title` and `letter.date`
- the recipient block is built from `letter.recipient`
- the first body heading is removed from the final output
- the body paragraphs are wrapped in `motivationbody`

## Common edits

### Change identity details

Edit the YAML front matter in both:

- `cv.md`
- `motivation.md`

### Add a new CV entry

Add a `##` row, then a `###` row, then bullet points.

Example:

```md
## Nordlicht Partners | Hamburg, Germany

### Off-Cycle Analyst | Jul 2026 -- Dec 2026

- Supported valuation work and client presentation drafting
- Coordinated diligence materials with internal and external stakeholders
```

### Add multiple positions at one company

Use one `##` company row and multiple `###` role rows:

```md
## Example Company | Berlin, Germany

### Senior Analyst | Jan 2026 -- Present

- Led valuation workstreams and review meetings

### Analyst | Jan 2025 -- Dec 2025

- Built operating models and market screens
```

### Add a signature to the motivation letter

Use a normal markdown image before the typed name:

```md
![](signatures/signature.png){ width=140px }
```

This is the simplest and most stable option.

## Notes

- `motivation-debug.tex` is not required for normal use. It was only useful for debugging the intermediate LaTeX.
- The sample content in `cv.md` and `motivation.md` is placeholder/demo content and can be replaced freely.
- If you want to change visual design, do that in `tex/cv-setup.tex` first. If you want to change how markdown is interpreted, do that in `filters/cv.lua`.
