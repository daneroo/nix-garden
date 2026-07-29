# Markdown

Authoring conventions for repository documentation:

- Use lowercase kebab-case filenames. Reserve uppercase for recognized indexes
  or control files such as `README.md` and `BACKLOG.md`.
- Prefer headings and `-` lists. Use tables sparingly when alignment helps; move
  verbose detail into prose rather than widening the table.
- Use emphasis sparingly.
- Avoid emoji, including check/x status glyphs; use words or Markdown
  checkboxes. Other Unicode and literal output are fine.
- Use one `#` heading per file.
- Give fenced code blocks a language when one applies.
- End files with one newline.
- Keep prose brief and accurate; one durable fact should have one home.

The repository's formatting tool owns spacing and prose wrapping. Its Markdown
linter owns document structure and must use formatting-compatible rules. The
repository quality gate verifies both.

Exception: preserve installer-managed skills with a tracked upstream exactly as
pinned instead of reformatting them. This currently applies only to
`.agents/skills/grilling/`; repository-authored skills follow the normal rules.
