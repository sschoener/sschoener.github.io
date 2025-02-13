---
layout: post
title: Note to myself - Image Magick commands that you will use
tags: [note to myself]
---
Dear future me, here are some ImageMagick commands that you will end up using over an over again and have to look up repeatedly (unless I write them down now, in which case you will surely remember all of them):

  * Convert from from one image format to another (PNG in this case): `mogrify -format png`
  * Resize pictures: `convert <input> -resize 25% <output>`
  * Add label to the bottom right: `composite label:<text> -gravity southeast <input> <output>`
  * Add a white border to the image: `convert -bordercolor White -border 10&#215;10 <input> <output>`
  * Arrange images horizontally such that the spacing between images is just as large as the frame of the whole batch (20px, in this case): `cmd /c "montage preview-1.png preview-2.png preview-3.png -geometry 500X500+10+0 -tile x1 - | convert -  -bordercolor White -border 10x20 preview.png` -- note the use of CMD here, since Windows PowerShell screws up piping of binary data ("Hey, it's a string, let's make it Unicode!")
  * Cut out the center in a square format: `convert <input> -set option:distort:viewport "%[fx: w>h ? h : w]x%[fx: w>h ? h : w]+%[fx: w>h ? (w - h)/2 : 0]+%[fx: w>h ? 0 : (h - w)/2]" -filter point -distort SRT 0 +repage <output>`
  * Cut out the center in a 2/3 format: `convert <input> -set option:distort:viewport "%[fx: w>(3/2*h) ? 3/2*h : w]x%[fx: w>(3/2*h) ? h : 2/3*w]+%[fx: w>(3/2*h) ? (w - 3/2*h)/2 : 0]+%[fx: w>(3/2*h) ? 0 : (h - 2/3*w)/2]" -filter point -distort SRT 0 +repage <output>`