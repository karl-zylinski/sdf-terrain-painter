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

import "core:math/linalg"
import "core:fmt"
import rl "vendor:raylib"

_ :: fmt

PixelWindowHeight :: 180

GridWidth :: 320
GridHeight :: 180

FillPoint :: struct {
	pos: Vec2i,
	stop_at: GroundType,
	consume: GroundType,
	filler: Color,
	dir: Vec2,
}

GameMemory :: struct {	
	camera_pos: Vec2,
	grid: [GridWidth][GridHeight]GroundType,
	mode: GroundType,
	radius: f32,

	show_result: bool,
	result: [GridWidth][GridHeight]rl.Color,

	visited: [GridWidth][GridHeight]bool,
}

GroundType :: enum {
	None,
	Ground0,
	Ground1,
}

mode_color := [GroundType]Color {
	.None = rl.BLACK,
	.Ground0 = rl.GREEN,
	.Ground1 = rl.DARKGREEN,
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

calculate :: proc() {
	for x in 0..<GridWidth {
		for y in 0..<GridHeight {
			g_mem.result[x][y] = rl.BLANK
		}
	}

	fill_points := make([dynamic]FillPoint, context.temp_allocator)

	for x in 0..<GridWidth {
		for y in 0..<GridHeight {
			g := &g_mem.grid
			c := g[x][y]

			r := rl.BLANK

			nearby: bit_set[GroundType]

			dir: Vec2

			for xx := x - 1; xx >= 0 && xx < x + 2 && xx < GridWidth; xx += 1 {
				for yy := y - 1; yy >= 0 && yy < y + 2 && yy < GridHeight; yy += 1 {
					if xx != x && yy != y {
						nearby += {g[xx][yy]}

						if g[x][y] == .Ground1 && g[xx][yy] == .Ground0 {
							v := Vec2{f32(xx - x), f32(yy - y)}
							dir += v
						}
					}
				}
			}

			dir = linalg.normalize0(dir)

			switch c {
				case .None:
					r = rl.BLANK

				case .Ground0:
					r = ColorGrass

				case .Ground1:
					r = ColorGrass

					if .Ground0 in nearby {
						append(&fill_points, FillPoint {
							pos = {x,y},
							consume = .Ground0,
							stop_at = .Ground1,
							filler = ColorMud,
							dir = dir,
						})
					}

					/*if w == .Ground0 {
						for xx := x; xx >= 0 && xx > x - 6; xx -= 1 {
							if g[xx][y] == .Ground0 {
								g_mem.result[xx][y] = ColorMud
							}
						}
						r = ColorMud
					}

					if e == .Ground0 {
						for xx := x; xx < GridWidth && xx < x + 6; xx += 1 {
							if g[xx][y] == .Ground0 {
								g_mem.result[xx][y] = ColorMud
							}
						}
						r = ColorMud
					} 

					if s == .Ground0 {
						for yy := y; yy < GridWidth && yy < y + 10; yy += 1 {
							if g[x][yy] == .Ground0 {
								g_mem.result[x][yy] = ColorMud
							}
						}
					}

					if n == .Ground0 {
						r = ColorMud
					}*/
			}

			g_mem.result[x][y] = r
		}
	}

	fill :: proc(src: [GridWidth][GridHeight]GroundType, dst: ^[GridWidth][GridHeight]Color, visited: ^[GridWidth][GridHeight]bool, fps: []FillPoint, cur: Vec2i) {


		if cur.x < 0 || cur.x >= GridWidth || cur.y < 0 || cur.y >= GridHeight {
			return
		}

		if visited[cur.x][cur.y] {
			return
		}

		visited[cur.x][cur.y] = true

		vcur := vec2_from_vec2i(cur)

		fp: ^FillPoint
		fp_dist := max(f32)

		for &f in fps {
			dist := linalg.length(vcur - vec2_from_vec2i(f.pos))
			if dist < fp_dist {
				fp = &f
				fp_dist = dist
			}
		}

		if fp == nil {
			return
		}

		if rl.IsKeyDown(.H) {
			rl.DrawCircleV(vec2_from_vec2i(fp.pos), 0.5, rl.YELLOW)
		}

		if src[cur.x][cur.y] == fp.stop_at { 
			return
		}

		fpos := vec2_from_vec2i(fp.pos)
		dir := linalg.normalize0(vcur - fpos)

		d := linalg.dot(dir, Vec2{0, 1})
		r := remap(d, -1, 1, 2, 14)

		if linalg.length(vcur - fpos) > r {
			return
		}

		//rl.DrawLineV(vec2_from_vec2i(fp.pos), vec2_from_vec2i(fp.pos) + fp.dir*5, rl.RED)

		/*perp := fpos + linalg.projection(vcur - fpos, Vec2{fp.dir.y, -fp.dir.x})

		//rl.DrawCircleV(on_dir, 0.5, rl.YELLOW)

		//fmt.printf("from: %v, to: %v, dir: %v\n", vcur, on_dir, fp.dir)

		/*dir := on_dir - vec2_from_vec2i(fp.pos)
		dist := linalg.length(dir)*/

		d := linalg.dot(fp.dir, Vec2{0, 1})
		r: f32 = 4

		if d < 0.4 {
			r = 4
		} else if d < 0.7 {
			r = 8
		} else {
			r = 14
		}


		/*if linalg.length(on_dir) > r || aa {
			return
		}*/

		if linalg.length(perp - vcur) > 5 {
			return
		}*/


		if src[cur.x][cur.y] == fp.consume {
			filler := ColorMud

			/*if dist < 3 {
				filler = ColorDarkGrass
			}*/

			dst[cur.x][cur.y] = filler
		}

		fill(src, dst, visited, fps, cur + {-1, 0})
		fill(src, dst, visited, fps, cur + {1, 0})
		fill(src, dst, visited, fps, cur + {0, -1})
		fill(src, dst, visited, fps, cur + {0, 1})
	} 

	g_mem.visited = {}
	/*for fp in fill_points {
		fill(g_mem.grid, &g_mem.result, &g_mem.visited, fill_points[:], fp.pos)
		fill(g_mem.grid, &g_mem.result, &g_mem.visited, fill_points[:], fp.pos + {-1, 0})
		fill(g_mem.grid, &g_mem.result, &g_mem.visited, fill_points[:], fp.pos + {1, 0})
		fill(g_mem.grid, &g_mem.result, &g_mem.visited, fill_points[:], fp.pos + {0, -1})
		fill(g_mem.grid, &g_mem.result, &g_mem.visited, fill_points[:], fp.pos + {0, 1})
	}*/

	for fp in fill_points {
		d := linalg.dot(fp.dir, Vec2{0, 1})
		r: f32 = 4

		if d < 0 {
			r = 4
		} else if d < 0.90 {
			r = 6
		} else {
			r = 14
		}

		bp := vec2_from_vec2i(fp.pos)

		for i := bp.y-r; i <= bp.y+r; i+=1 {
			for j := bp.x; (j-bp.x)*(j-bp.x) + (i-bp.y)*(i-bp.y) < r*r; j-=1 {
				p := Vec2 {j, i}

				c := ColorMud

				if r-linalg.length(p-bp) < 2 {
					//c = ColorDark
				}

				pi := vec2i_from_floored_vec2(p)

				if g_mem.grid[pi.x][pi.y] == fp.consume && g_mem.result[pi.x][pi.y] == ColorGrass {
					g_mem.result[pi.x][pi.y] = c
				}
			}
			for j := bp.x+1; (j-bp.x)*(j-bp.x) + (i-bp.y)*(i-bp.y) < r*r; j+=1 {
				p := Vec2 {j, i}

				c := ColorMud

				if r-linalg.length(p-bp) < 2 {
					//c = ColorDark
				}

				pi := vec2i_from_floored_vec2(p)

				if g_mem.grid[pi.x][pi.y] == fp.consume && g_mem.result[pi.x][pi.y] == ColorGrass {
					g_mem.result[pi.x][pi.y] = c
				}
			}
		}
	}
}
 
update :: proc() {
	g_mem.visited = {}
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

	if rl.IsKeyPressed(.SPACE) {
		if g_mem.show_result {
			g_mem.show_result = false
		} else {
			
			g_mem.show_result = true
		}
	}
}

draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground({74, 103, 181, 255})
	
	rl.BeginMode2D(game_camera())

	if rl.IsKeyDown(.SPACE) {
		for x in 0..<GridWidth {
			for y in 0..<GridHeight {
				g := g_mem.grid[x][y]
				rl.DrawPixelV({f32(x), f32(y)}, g == .None ? rl.BLANK : mode_color[g])
			}
		}
	} else {
		for x in 0..<GridWidth {
			for y in 0..<GridHeight {
				rl.DrawPixelV({f32(x), f32(y)}, g_mem.result[x][y])
			}
		}
	}
	
	bp := vec2_floor(brush_pos())

	r := g_mem.radius

	g_mem.radius += rl.GetMouseWheelMove()

	k := rl.GetKeyPressed()

	if k >= .ZERO && k <= .NINE {
		g_mem.mode = GroundType(k - .ZERO)
	}

	for i := bp.y-r; i <= bp.y+r; i+=1 {
		for j := bp.x; (j-bp.x)*(j-bp.x) + (i-bp.y)*(i-bp.y) < r*r; j-=1 {
			p := Vec2{j, i}
			if r-linalg.length(p-bp) < 2 {
				rl.DrawPixelV({j, i}, mode_color[g_mem.mode])
			}

			if rl.IsMouseButtonDown(.LEFT) && j >= 0 && j < GridWidth && i >= 0 && i < GridHeight {
				g_mem.grid[int(j)][int(i)] = g_mem.mode
			}
		}
		for j := bp.x+1; (j-bp.x)*(j-bp.x) + (i-bp.y)*(i-bp.y) < r*r; j+=1 {
			p := Vec2{j, i}
			if r-linalg.length(p-bp) < 2 {
				rl.DrawPixelV({j, i}, mode_color[g_mem.mode])
			}

			if rl.IsMouseButtonDown(.LEFT) && j >= 0 && j < GridWidth && i >= 0 && i < GridHeight {
				g_mem.grid[int(j)][int(i)] = g_mem.mode
			}
		}
	}

	calculate()
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