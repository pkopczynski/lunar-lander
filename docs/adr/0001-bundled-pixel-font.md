# Bundle the Silkscreen font despite the no-external-assets rule

The office terminal needs a pixel font to look retro. Godot's default font doesn't look retro, and drawing glyphs from rectangles would be a lot of code for little gain. So we bundle `Silkscreen-Regular.ttf` (from Google Fonts) and its OFL licence. The only exception to "no external assets" is bundled OFL fonts. Everything else is still drawn with Godot nodes.
