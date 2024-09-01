// This is some signed distance field drawing experiments. You can draw hills
// It's not very performant, and runs on CPU. But the basic ideas are there.
// Most of the interesting things are in proc `update`

// Docs from template:
//
// This file is compiled as part of the `odin.dll` file. It contains the
// procs that `game.exe` will call, such as:
//
// game_init: Sets up the game state
// game_update: Run once per frame
// game_shutdown: Shuts down game and frees memory
// game_memory: Run just before a hot reload, so game.exe has a pointer to the
//		game's memory.
// game_hot_reloaded: Run after a hot reload so that the `g_mem` global variable
//		can be set to whatever pointer it was in the old DLL.

package game

import "core:fmt"
import "core:math/linalg"
import "core:math/noise"
import "base:intrinsics"
import "core:math"
import rl "vendor:raylib"

Vec2 :: rl.Vector2
_ :: fmt

PixelWindowHeight :: 180
GridWidth :: 320
GridHeight :: 180

GameMemory :: struct {	
	camera_pos: Vec2,

	// game_init sets all pixels in SDF to 32 by default
	sdf: [GridWidth][GridHeight]f32,

	// Change with mouse wheel
	radius: f32,
	brush: Brush,
}

Brush :: enum {
	Circle,
	Square,
}

g_mem: ^GameMemory

ColorGrass :: rl.Color { 100, 200, 100, 255 }
ColorDarkGrass :: rl.Color { 15, 116, 70, 255 }
ColorMud :: rl.Color { 156, 79, 79, 255 }
ColorDark :: rl.Color { 76, 53, 83, 255 }

remap :: proc "contextless" (old_value, old_min, old_max, new_min, new_max: $T) -> (x: T) where intrinsics.type_is_numeric(T), !intrinsics.type_is_array(T) {
	remapped := math.remap(old_value, old_min, old_max, new_min, new_max)
	return clamp(remapped, new_min, new_max)
}

brush_pos :: proc(c: rl.Camera2D) -> Vec2 {
	mp := rl.GetMousePosition()
	return rl.GetScreenToWorld2D(mp, c)
}

get_sdf_val :: proc(p: Vec2) -> f32 {
	return g_mem.sdf[int(clamp(p.x, 0, GridWidth-1))][int(clamp(p.y, 0, GridHeight-1))]
}

sdf_calculate_normal :: proc(p: Vec2) -> Vec2 {
	s1 := linalg.normalize0(Vec2{
		get_sdf_val(p + {2, 0}) - get_sdf_val(p - {2, 0}),
		get_sdf_val(p + {0, 2}) - get_sdf_val(p - {0, 4}),
	})

	s2 := linalg.normalize0(Vec2{
		get_sdf_val(p + {4, 0}) - get_sdf_val(p - {4, 0}),
		get_sdf_val(p + {0, 4}) - get_sdf_val(p - {0, 8}),
	})

	return (s1 + s2) /2
}

main :: proc() {
	game_init_window()
	game_init()

	for !rl.WindowShouldClose() {
		update()
	}

	game_shutdown()
	game_shutdown_window()
}

update :: proc() {
	// Circle and square brush. Press 1 and 2 to change.
	if rl.IsKeyPressed(.ONE) {
		g_mem.brush = .Circle
	}

	if rl.IsKeyPressed(.TWO) {
		g_mem.brush = .Square
	}

	rl.BeginDrawing()
	
	camera := rl.Camera2D {
		zoom = f32(rl.GetScreenHeight())/PixelWindowHeight,
	}

	rl.BeginMode2D(camera)

	if rl.IsKeyDown(.SPACE) {
		// Hold space to see the actual SDF
		rl.ClearBackground(ColorGrass)
		for x in 0..<GridWidth {
			for y in 0..<GridHeight {
				s := g_mem.sdf[x][y]
				c: rl.Color

				if s > 0 {
					c = {0, u8(s*7.9), 0, 255}
				} else {
					c = {u8(s*7.9), 0, 0, 255}
				}

				rl.DrawPixelV({f32(x), f32(y)}, c)
			}
		}
	} else {
		// Draw pretty hills based on SDF

		rl.ClearBackground(ColorGrass)
		for x in 0..<GridWidth {
			for y in 0..<GridHeight {
				s := g_mem.sdf[x][y]

				p := vec2_from_int(x, y)
  				n := sdf_calculate_normal(p)
  				//rl.DrawLineV(p, p + n, rl.RED)

  				d := n.y

  				r1 := remap(d, -1, 1, 0, 1)

  				n2d := remap(noise.noise_2d(0, {f64(p.x), f64(p.y)}/6), -1, 1, 0, 1)
  				n22d := remap(noise.noise_2d(0, {f64(p.x), f64(p.y)}/10), -1, 1, 0, 1)

  				r := remap(r1, 0.2, 0.8, 2.5, 14)

				if s > 0 && s < r {
					c := ColorMud

					if s > r * 0.5 {
						if r > 5 && (s > r * 0.75 || n2d*(remap(14-s, 0, 10, 0, 1)) < 0.2){
							c = ColorDark
						}
					}

					rl.DrawPixelV(p, c)
				}

				if s > -2 && s < 5*remap(d, 0, 1, 0.2, 1) {
					if (s > -1 && s < 2) || n22d*(remap(14-s, 0, 10, 0, 1)) > 0.8 {
						rl.DrawPixelV(p, ColorDarkGrass)
					}
				}

				if s > r * 0.9 && s < r + 1 {
					if remap(d, 0, 1, 0, 0.5) > 0 && n22d*(remap(s, 0, 14, 0, 1)) < 0.5 {
						rl.DrawPixelV(p, ColorDarkGrass)
					}
				}
			}
		}
	}

	bp := vec2_floor(brush_pos(camera))
	r := g_mem.radius
	g_mem.radius += rl.GetMouseWheelMove()

	// These two procs are the ones that the brushes use to draw into the SDF
	sdf_circle :: proc(p: Vec2, r: f32) -> f32 {
		return linalg.length(p)-r
	}

	sdf_box :: proc(p: Vec2, b: Vec2) -> f32 {
    	d := linalg.abs(p) - b
    	return linalg.length(linalg.max(d, 0)) + min(max(d.x, d.y), 0)
	}

	smin :: proc(a, b, k: f32) -> f32 {
		h := max(k - abs(a - b), 0.0) / k
		return min(a, b) - h * h * h * k / 6.0
	}

	smax :: proc(a, b, k: f32) -> f32 {
		k := k * 1.4
		h := max(k - abs(a - b), 0.0)
		return max(a, b) + h * h * h / (6.0 * k * k)
	}

	switch g_mem.brush {
	case .Circle:
		for i := bp.y-r; i <= bp.y+r; i+=1 {
			for j := bp.x; (j-bp.x)*(j-bp.x) + (i-bp.y)*(i-bp.y) < r*r; j-=1 {
				p := Vec2{j, i}
				if r-linalg.length(p-bp) < 2 {
					rl.DrawPixelV({j, i}, rl.WHITE)
				}
			}
			for j := bp.x+1; (j-bp.x)*(j-bp.x) + (i-bp.y)*(i-bp.y) < r*r; j+=1 {
				p := Vec2{j, i}
				if r-linalg.length(p-bp) < 2 {
					rl.DrawPixelV({j, i}, rl.WHITE)
				}
			}
		}

		if rl.IsMouseButtonDown(.LEFT) {
			for x in 0..<GridWidth {
				for y in 0..<GridHeight {
					g_mem.sdf[x][y] = clamp(smin(g_mem.sdf[x][y], sdf_circle(vec2_from_int(x,y) - bp, r), 1), -32, 32)
				}
			}
		}

		if rl.IsMouseButtonDown(.RIGHT) {
			for x in 0..<GridWidth {
				for y in 0..<GridHeight {
					g_mem.sdf[x][y] = clamp(smax(g_mem.sdf[x][y], -sdf_circle(vec2_from_int(x,y) - bp, r),1), -32, 32)
				}
			}
		}
	case .Square:
		rect := rl.Rectangle {
			bp.x - r,
			bp.y - r,
			r*2,
			r*2,
		}
		rl.DrawRectangleLinesEx(rect, 1, rl.WHITE)
		
		if rl.IsMouseButtonDown(.LEFT) {
			for x in 0..<GridWidth {
				for y in 0..<GridHeight {
					g_mem.sdf[x][y] = clamp(smin(g_mem.sdf[x][y], sdf_box(vec2_from_int(x,y) - bp, {r, r}), 1), -32, 32)
				}
			}
		}

		if rl.IsMouseButtonDown(.RIGHT) {
			for x in 0..<GridWidth {
				for y in 0..<GridHeight {
					g_mem.sdf[x][y] = clamp(smax(g_mem.sdf[x][y], -sdf_box(vec2_from_int(x,y) - bp, {r, r}),1), -32, 32)
				}
			}
		}
	}

	rl.EndMode2D()

	rl.EndDrawing()
}

vec2_from_int :: proc(x: int, y: int) -> Vec2 {
	return { f32(x), f32(y) }
}

vec2_floor :: proc(p: Vec2) -> Vec2 {
	return { math.floor(p.x), math.floor(p.y) }
}

@(export)
game_init_window :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(1280, 720, "Pixel Painter!")
	rl.SetWindowPosition(200, 200)
	rl.SetTargetFPS(500)
}

@(export)
game_init :: proc() {
	g_mem = new(GameMemory)

	g_mem^ = GameMemory {
		radius = 10,
	}

	for x in 0..<GridWidth {
		for y in 0..<GridHeight {
			g_mem.sdf[x][y] = 32
		}
	}

	game_hot_reloaded(g_mem)
}

@(export)
game_shutdown :: proc() { 
	free(g_mem)
}

@(export)
game_shutdown_window :: proc() {
	rl.CloseWindow()
}

@(export)
game_memory :: proc() -> rawptr {
	return g_mem
}

@(export)
game_memory_size :: proc() -> int {
	return size_of(GameMemory)
}

@(export)
game_hot_reloaded :: proc(mem: rawptr) {
	g_mem = (^GameMemory)(mem)
}

@(export)
game_force_reload :: proc() -> bool {
	return rl.IsKeyPressed(.F5)
}

@(export)
game_force_restart :: proc() -> bool {
	return rl.IsKeyPressed(.F6)
}