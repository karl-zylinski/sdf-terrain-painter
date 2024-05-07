package game

import "core:math"

Vec2i :: [2]int
Vec2 :: [2]f32

vec2_from_vec2i :: proc(p: Vec2i) -> Vec2 {
	return { f32(p.x), f32(p.y) }
}

vec2_floor :: proc(p: Vec2) -> Vec2 {
	return { math.floor(p.x), math.floor(p.y) }
}

vec2i_from_floored_vec2 :: proc(p: Vec2) -> Vec2i {
	return { int(math.floor(p.x)), int(math.floor(p.y)) }
}
