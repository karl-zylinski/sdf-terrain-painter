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

GridSize :: 256

GameMemory :: struct {	
	camera_pos: Vec2,
	grid: [GridSize][GridSize]f32,
	radius: f32,
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
}

draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground({176, 184, 223, 255})
	
	rl.BeginMode2D(game_camera())

	for x in 0..<GridSize {
		for y in 0..<GridSize {
			rl.DrawPixelV({f32(x), f32(y)}, {0, 255, 0, u8(g_mem.grid[x][y]*255)})
		}
	}

	bp := vec2_floor(brush_pos())

	r := g_mem.radius

	g_mem.radius += rl.GetMouseWheelMove()

	draw := rl.IsMouseButtonDown(.LEFT)
	erase := rl.IsMouseButtonDown(.RIGHT)

	for i := bp.y-r; i <= bp.y+r; i+=1 {
		for j := bp.x; (j-bp.x)*(j-bp.x) + (i-bp.y)*(i-bp.y) < r*r; j-=1 {
			p := Vec2{j, i}
			if r-linalg.length(p-bp) < 2 {
				rl.DrawPixelV({j, i}, rl.GREEN)
			}

			if (draw || erase) && j >= 0 && j < GridSize && i >= 0 && i < GridSize {
				g_mem.grid[int(j)][int(i)] = draw ? 1 : 0
			}
		}
		for j := bp.x+1; (j-bp.x)*(j-bp.x) + (i-bp.y)*(i-bp.y) < r*r; j+=1 {
			p := Vec2{j, i}
			if r-linalg.length(p-bp) < 2 {
				rl.DrawPixelV({j, i}, rl.GREEN)
			}

			if (draw || erase) && j >= 0 && j < GridSize && i >= 0 && i < GridSize {
				g_mem.grid[int(j)][int(i)] = draw ? 1 : 0
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