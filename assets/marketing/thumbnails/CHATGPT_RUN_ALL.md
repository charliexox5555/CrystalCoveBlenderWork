# One prompt to make every image (paste after the style bible)

```
Make all 17 Glass Clash marketing images now, working through the repo folder on your own.

1. Read assets/marketing/thumbnails/CHATGPT_PROMPTS.md. The style bible (already given), the "Reject if" list and every section T1a, T1b, T1c, T1d, T1h, T2a, T2b, T2c, T3a, T3b, T4a, T4b, T5a, T5b, I1, I2, I3 apply. Each section is one image.
2. For each section, in that order:
   - Open every file it lists under "Attach" (paths are relative to assets/marketing/thumbnails/). Use <id>_beauty.png as the base, <id>_subject.png for the exact glassy shapes and colours, the studio_*.jpg files for the true in-game look.
   - Look at the Ball VS Ball images in references/ (if they are there) for energy and composition only. Read references/README.md. Never copy their content.
   - Generate 2 options at the section's size (1920x1080 for T*, 1024x1024 for I*), following its Keep / Enhance / Camera / Clear zone notes.
   - Check both against the "Reject if" list: same glassy shapes, colours and faces as the renders; no invented glassies, characters, UI, coins, text, letters, numbers or logo; the clear zone calm; nothing important in the bottom 15% (thumbnails) or the corners (icons). Regenerate any option that fails, up to 3 tries.
   - Save the better option as assets/marketing/thumbnails/from_chatgpt/<id>.png and the other as from_chatgpt/alt/<id>_b.png.
3. Don't stop to ask me between images. Don't edit or delete anything outside from_chatgpt/.
4. When all 17 are done, write assets/marketing/thumbnails/from_chatgpt/REPORT.md: one line per id with the file names, what you changed from the render, any rule you couldn't fully meet, and which ids you'd rank as the top 10 thumbnails and the best icon (with one line of reasoning each).
```
