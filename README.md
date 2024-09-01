By Karl Zylinski, http://zylinski.se

Support me at https://www.patreon.com/karl_zylinski

This is a prototype of painting terrain using Signed Distance Fields for 2D top down games.

It looks like this:
https://github.com/karl-zylinski-subscribers/sdf-terrain-painter/assets/6352002/ff3079e0-e081-4567-80a7-7f9c91f88a59

This is just implemented on the CPU and is not very performant. Moving the rendering to the GPU should make things snappy. I will probably move this code into some other prototype and make it more fancy there. Almost everything of interest happens in game.odin:update()

