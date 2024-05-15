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
import rl "vendor:raylib"

_ :: fmt

PixelWindowHeight :: 180
GridWidth :: 320
GridHeight :: 180

GridProperty :: enum {
	None,
	Slope,
}

GameMemory :: struct {	
	camera_pos: Vec2,
	sdf: [GridWidth][GridHeight]f32,
	properties: [GridWidth][GridHeight]GridProperty,
	radius: f32,
	brush: Brush,
}

Brush :: enum {
	Circle,
	Square,
	Slope,
}

g_mem: ^GameMemory

game_camera :: proc() -> rl.Camera2D {
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())

	return {
		zoom = h/PixelWindowHeight,
		target = g_mem.camera_pos,
		offset = { w/2, h/2 },
	}
}

ui_camera :: proc() -> rl.Camera2D {
	return {
		zoom = f32(rl.GetScreenHeight())/PixelWindowHeight,
	}
}

ColorGrass :: Color { 100, 200, 100, 255 }
ColorDarkGrass :: Color { 15, 116, 70, 255 }
ColorMud :: Color { 156, 79, 79, 255 }
ColorDark :: Color { 76, 53, 83, 255 }

brush_pos :: proc() -> Vec2 {
	c := game_camera()
	mp := rl.GetMousePosition()
	return rl.GetScreenToWorld2D(mp, c)
}

update :: proc() {
	input: Vec2

	if rl.IsKeyDown(.W) {
		input.y -= 1
	}
	if rl.IsKeyDown(.S) {
		input.y += 1
	}
	if rl.IsKeyDown(.A) {
		input.x -= 1
	}
	if rl.IsKeyDown(.D) {
		input.x += 1
	}

	input = linalg.normalize0(input)
	g_mem.camera_pos += input * rl.GetFrameTime() * 100

	if rl.IsKeyPressed(.ONE) {
		g_mem.brush = .Circle
	}

	if rl.IsKeyPressed(.TWO) {
		g_mem.brush = .Square
	}

	if rl.IsKeyPressed(.THREE) {
		g_mem.brush = .Slope
	}
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

draw :: proc() {
	rl.BeginDrawing()
	
	rl.BeginMode2D(game_camera())

	if rl.IsKeyDown(.SPACE) {
		rl.ClearBackground(ColorGrass)
		for x in 0..<GridWidth {
			for y in 0..<GridHeight {
				s := g_mem.sdf[x][y]
				c: Color

				if s > 0 {
					c = {0, u8(s*7.9), 0, 255}
				} else {
					c = {u8(s*7.9), 0, 0, 255}
				}

				rl.DrawPixelV({f32(x), f32(y)}, c)

				switch g_mem.properties[x][y] {
					case .None:

					case .Slope:
						rl.DrawPixelV({f32(x), f32(y)}, {255, 0, 0, 100})
				}
			}
		}
	} else {
		rl.ClearBackground(ColorGrass)
		for x in 0..<GridWidth {
			for y in 0..<GridHeight {
				s := g_mem.sdf[x][y]
				prop := g_mem.properties[x][y]

				p := vec2_from_int(x, y)
  				n := sdf_calculate_normal(p)
  				//rl.DrawLineV(p, p + n, rl.RED)

  				d := linalg.dot(n, Vec2{0, 1})

  				r1 := remap(d, -1, 1, 0, 1)

  				n2d := remap(noise.noise_2d(0, {f64(p.x), f64(p.y)}/6), -1, 1, 0, 1)
  				n22d := remap(noise.noise_2d(0, {f64(p.x), f64(p.y)}/10), -1, 1, 0, 1)

  				r := remap(r1, 0.2, 0.8, 2.5, 14)


  				has_nearby_property :: proc(x, y: int, p: GridProperty) -> bool {
  					t := g_mem.properties[x][max(y-2, 0)] == .Slope
  					b := g_mem.properties[x][min(y+2, GridHeight - 1)] == .Slope
  					l := g_mem.properties[max(x-2, 0)][y] == .Slope
  					r := g_mem.properties[min(x+2, GridWidth-1)][y] == .Slope

  					return t || b || l || r
  				}

  				is_slope := prop == .Slope
  				is_slope_edge := !is_slope && has_nearby_property(x, y, .Slope)

  				if is_slope {
  					/*if s > -5 && s < r + 4 {
  					 	sr := remap(s, -5, 0, 0, 1)
  						rl.DrawPixelV(p, { 80, 180, 100, u8(f32(255) * sr) })
  					}*/
  				} else {
					if s > 0 && s < r {
						c := ColorMud

						if is_slope_edge {
							c = ColorDark

							if n2d*(remap(s, 0, 14, 0, 1)) > 0.3 {
								c = ColorDarkGrass
							}
						} else {
							if s > r * 0.5 {
								if r > 5 && (s > r * 0.75 || n2d*(remap(14-s, 0, 10, 0, 1)) < 0.2){
									c = ColorDark
								}
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
	}

	bp := vec2_floor(brush_pos())
	r := g_mem.radius
	g_mem.radius += rl.GetMouseWheelMove()

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
			rect := Rect{
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
		case .Slope:
			for i := bp.y-r; i <= bp.y+r; i+=1 {
				for j := bp.x; (j-bp.x)*(j-bp.x) + (i-bp.y)*(i-bp.y) < r*r; j-=1 {
					p := Vec2{j, i}
					if r-linalg.length(p-bp) < 2 {
						rl.DrawPixelV({j, i}, rl.WHITE)
					}
					if rl.IsMouseButtonDown(.LEFT) {
						g_mem.properties[int(j)][int(i)] = .Slope
					}
				}
				for j := bp.x+1; (j-bp.x)*(j-bp.x) + (i-bp.y)*(i-bp.y) < r*r; j+=1 {
					p := Vec2{j, i}
					if r-linalg.length(p-bp) < 2 {
						rl.DrawPixelV({j, i}, rl.WHITE)
					}
					if rl.IsMouseButtonDown(.LEFT) {
						g_mem.properties[int(j)][int(i)] = .Slope
					}
				}
			}
	}

	rl.EndMode2D()

	rl.BeginMode2D(ui_camera())
	rl.EndMode2D()

	rl.EndDrawing()
}

@(export)
game_update :: proc() -> bool {
	update()
	draw()

	return !rl.WindowShouldClose()
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
		camera_pos = {320/2, 180/2},
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