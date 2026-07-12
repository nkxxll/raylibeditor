-- this needs some more work
local Presentation = require("presentation.lua")
local Slide = require("slide.lua")

local img = "someimage.png"
Slide.background(img)

local font_name = "jetbrains_mono"
local color = "black"
local color_rgb = 0xffffff

Slide.set_nuber(1)
Slide.set_heading("this is a heading", 20)
Slide.set_heading("this is a heading")
Slide.set_text("this is normal text", { font_size = 10, font_name = font_name, color , pos = { x = 500, y = 600} })
Slide.set_text("this is normal text", { font_size = 10, font_name = font_name, color = color_rgb })
Slide.set_text("this is normal text", { font_name = font_name })
Slide.set_text("this is normal text")

-- Presentation.set_slide(1)
-- develop on slide one

-- run the presentation space forward shift+space backward g opens textwindow
-- you can put in a number jump to that slide
Presentation.run()
