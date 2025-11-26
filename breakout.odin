package breakout

import "core:fmt"
import m "core:math"
import la "core:math/linalg"
import rl "vendor:raylib"

WW :: 1280
WH :: 1280
SS :: 320
FPS :: 500

BGC :: rl.Color{150, 190, 220, 255}
PPY :: SS - 10
PW :: 50
PH :: 6
PCOLOR :: rl.Color{50, 150, 90, 255}
PSPEED :: 200
BSPEED :: 260
BRAD :: 4
BCOLOR :: rl.Color{200, 90, 20, 255}
BINIT_Y :: 160
N_BLOCKS_X :: 10
N_BLOCKS_Y :: 8
BKW :: 28
BKH :: 10
BKPX :: 20
BKPY :: 40
SFS :: 25
GOFS :: 15

game_has_started: bool
game_over: bool
game_score: int

Paddle :: struct {
	position: rl.Vector2,
}

Ball :: struct {
	position:  rl.Vector2,
	direction: rl.Vector2,
}

Block :: struct {
	color:  rl.Color,
	exists: bool,
	rect:   rl.Rectangle,
}


Block_Color :: enum {
	Yellow,
	Green,
	Orange,
	Red,
}


block_row_colors := [N_BLOCKS_Y]Block_Color {
	.Red,
	.Red,
	.Orange,
	.Orange,
	.Green,
	.Green,
	.Yellow,
	.Yellow,
}
block_color_scores := [Block_Color]int {
	.Yellow = 2,
	.Green  = 4,
	.Orange = 6,
	.Red    = 6,
}

block_color_map := [Block_Color]rl.Color {
	.Yellow = rl.Color{253, 249, 150, 255},
	.Green  = rl.Color{180, 245, 190, 255},
	.Orange = rl.Color{170, 120, 250, 255},
	.Red    = rl.Color{250, 90, 85, 255},
}

BlockGrid :: [N_BLOCKS_X][N_BLOCKS_Y]Block


draw_block :: proc(b: ^Block) {
	tl := rl.Vector2{b.rect.x, b.rect.y}
	tr := rl.Vector2{b.rect.x + b.rect.width, b.rect.y}
	bl := rl.Vector2{b.rect.x, b.rect.y + b.rect.height}
	br := rl.Vector2{b.rect.x + b.rect.width, b.rect.y + b.rect.height}
	rl.DrawRectangleRec(b.rect, b.color)
	rl.DrawLineEx(tl, tr, 1, {255, 255, 150, 100})
	rl.DrawLineEx(tl, bl, 1, {255, 255, 150, 100})
	rl.DrawLineEx(tr, br, 1, {0, 0, 50, 100})
	rl.DrawLineEx(bl, br, 1, {0, 0, 50, 100})
}

init_blocks :: proc(bks: ^[N_BLOCKS_X][N_BLOCKS_Y]Block) {
	for x in 0 ..< N_BLOCKS_X {
		for y in 0 ..< N_BLOCKS_Y {
			bks[x][y] = Block {
				color  = block_color_map[block_row_colors[y]],
				exists = true,
				rect   = rl.Rectangle{f32(BKPX + x * BKW), f32(BKPY + y * BKH), BKW, BKH},
			}

		}
	}
}

draw_blocks :: proc(bks: BlockGrid) {
	for x in 0 ..< N_BLOCKS_X {
		for y in 0 ..< N_BLOCKS_Y {
			bk := bks[x][y]
			if bk.exists == false {
				continue
			}
			draw_block(&bk)
		}
	}
}

blocks: BlockGrid

restart :: proc(p: ^Paddle, b: ^Ball) {
	p.position.x = SS / 2 - (PW / 2)
	b.position = {SS / 2 - BRAD, BINIT_Y}
	game_score = 0
	game_over = false
	game_has_started = false
	init_blocks(&blocks)
}

main :: proc() {
	rl.InitWindow(WW, WH, "breakout")
	rl.SetTargetFPS(FPS)

	paddle := Paddle {
		position = {0, PPY},
	}

	ball := Ball{}

	cam := rl.Camera2D {
		zoom = f32(rl.GetScreenHeight()) / SS,
	}

	ball_to_paddle_direction :: proc(b: ^Ball, p: ^Paddle) -> rl.Vector2 {
		paddle_center := rl.Vector2{p.position.x + PW / 2, PPY}
		return la.normalize(paddle_center - b.position)
	}

	ball_idle :: proc(b: ^Ball) {
		b.position = {SS / 2 + f32(m.cos(rl.GetTime()) * SS / 2.5), BINIT_Y}
	}

	normal_reflect :: proc(direction, normal: rl.Vector2) -> rl.Vector2 {
		reflected_direction := la.reflect(direction, la.normalize(normal))
		return la.normalize(reflected_direction)
	}

	paddle_rebound :: proc(b: ^Ball, p: ^Paddle, dt: ^f32) {
		p_rect := rl.Rectangle{p.position.x, PPY, PW, PH}
		previous_ball_position := b.position
		if rl.CheckCollisionCircleRec(b.position, BRAD, p_rect) {
			collision_surf_normal: rl.Vector2

			if previous_ball_position.y < p_rect.y + p_rect.height {
				collision_surf_normal += {0, -1} // Pointing upwards
				b.position.y = p_rect.y - BRAD
			}

			if (previous_ball_position.y > p_rect.y + p_rect.height) {
				collision_surf_normal += {0, 1} // Pointing Downwards
				b.position.y = p_rect.y + p_rect.height + BRAD
			}

			if (previous_ball_position.x < p_rect.x) {
				collision_surf_normal += {-1, 0} // pointing left
			}

			if (previous_ball_position.x > p_rect.x + p_rect.width) {
				collision_surf_normal += {1, 0} // pointing right
			}

			if collision_surf_normal != 0 {
				b.direction = normal_reflect(b.direction, collision_surf_normal)
			}
		}
	}

	ball_rebound :: proc(b: ^Ball, p: ^Paddle) {

		// Right Wall
		if b.position.x + BRAD > SS {
			b.position.x = SS - BRAD
			b.direction = normal_reflect(b.direction, {-1, 0})
		}

		// Left Wall
		if b.position.x - BRAD < 0 {
			b.position.x = BRAD
			b.direction = normal_reflect(b.direction, {1, 0})
		}

		// Top Wall
		if b.position.y - BRAD < 0 {
			b.position.y = BRAD
			b.direction = normal_reflect(b.direction, {0, 1})
		}

		if (!game_over && b.position.y > SS + BRAD * 4) {
			game_over = true
		}
	}

	block_has_lateral_neighbours :: proc(x, y: int) -> bool {
		if x < 0 || y < 0 || x >= N_BLOCKS_X || y >= N_BLOCKS_Y {
			return false
		}
		return blocks[x][y].exists
	}

	block_rebound :: proc(ball: ^Ball) {
		pbp := ball.position
		outer: for x in 0 ..< N_BLOCKS_X {
			for y in 0 ..< N_BLOCKS_Y {
				bk := &blocks[x][y]
				if bk.exists == false {
					continue
				}
				if rl.CheckCollisionCircleRec(ball.position, BRAD, bk.rect) {
					collision_normal := rl.Vector2{}
					if pbp.y < bk.rect.y {
						collision_normal += {0, -1}
					}
					if pbp.y > bk.rect.y + bk.rect.height {
						collision_normal += {0, 1}
					}
					if pbp.x < bk.rect.x {
						collision_normal += {-1, 0}
					}
					if pbp.x > bk.rect.x + bk.rect.width {
						collision_normal += {1, 0}
					}

					if block_has_lateral_neighbours(x + int(collision_normal.x), y) {
						collision_normal.x = 0
					}

					if block_has_lateral_neighbours(x, y + int(collision_normal.y)) {
						collision_normal.y = 0
					}

					if collision_normal != 0 {
						ball.direction = normal_reflect(ball.direction, collision_normal)
					}
					bk.exists = false
					game_score += block_color_scores[block_row_colors[y]]
					break outer
				}
			}
		}
	}

	draw_game_over_text :: proc() {

		go_box := rl.Rectangle {
			x      = SS / 2 - 70,
			y      = SS / 2 - 35,
			width  = 140,
			height = 70,
		}

		gobox_color := rl.Color{140, 176, 204, 255}
		tl := rl.Vector2{go_box.x, go_box.y}
		tr := rl.Vector2{go_box.x + go_box.width, go_box.y}
		bl := rl.Vector2{go_box.x, go_box.y + go_box.height}
		br := rl.Vector2{go_box.x + go_box.width, go_box.y + go_box.height}


		rl.DrawRectangleRec(go_box, gobox_color)
		rl.DrawLineEx(tl, tr, 1, rl.WHITE)
		rl.DrawLineEx(tl, bl, 1, rl.WHITE)
		rl.DrawLineEx(tr, br, 1, {0, 0, 50, 100})
		rl.DrawLineEx(bl, br, 1, {0, 0, 50, 100})

		go_text_size: i32 = 4

		text_line_1 := fmt.ctprint("Game Over")
		text_line_2 := fmt.ctprintf("Your final score is: %d", game_score)
		text_line_3 := fmt.ctprint("Press space to play again")

		tw1 := rl.MeasureText(text_line_1, go_text_size)
		tw2 := rl.MeasureText(text_line_2, go_text_size)
		tw3 := rl.MeasureText(text_line_3, go_text_size)

		t1x := i32(go_box.x) + i32(go_box.width / 2) - tw1 / 2
		t2x := i32(go_box.x) + i32(go_box.width / 2) - tw2 / 2
		t3x := i32(go_box.x) + i32(go_box.width / 2) - tw3 / 2
		t1y := i32(go_box.y) + 18
		t2y := t1y + 10
		t3y := t2y + 10

		rl.DrawText(text_line_1, t1x, t1y, go_text_size, rl.BLACK)
		rl.DrawText(text_line_2, t2x, t2y, go_text_size, rl.BLACK)
		rl.DrawText(text_line_3, t3x, t3y, go_text_size, rl.BLACK)


	}

	move :: proc(p: ^Paddle, b: ^Ball, dt: ^f32) {
		pmv: f32

		if !game_has_started {
			ball_idle(b)
			if rl.IsKeyPressed(.SPACE) {
				towards_paddle := ball_to_paddle_direction(b, p)
				b.direction = towards_paddle
				game_has_started = true
			}
		} else if game_over {
			if rl.IsKeyPressed(.SPACE) {
				restart(p, b)
			}
		} else {
			dt^ = rl.GetFrameTime()
		}

		if rl.IsKeyDown(.LEFT) {
			pmv -= PSPEED
		} else if rl.IsKeyDown(.RIGHT) {
			pmv += PSPEED
		}

		b.position += b.direction * BSPEED * dt^
		p.position.x += pmv * dt^
		p.position.x = clamp(p.position.x, 0, SS - PW)

		ball_rebound(b, p)
		paddle_rebound(b, p, dt)
		block_rebound(b)
	}

	draw_score :: proc() {
		score_txt := fmt.ctprint(game_score)
		score_width := rl.MeasureText(score_txt, SFS)
		score_x_pos := SS / 2 - score_width
		rl.DrawText(score_txt, score_x_pos, 5, SFS, rl.WHITE)
	}

	draw_paddle :: proc(p: ^Paddle, dt: f32) {

		p_rect := rl.Rectangle{p.position.x, p.position.y, PW, PH}

		tl := rl.Vector2{p_rect.x, p_rect.y}
		bl := rl.Vector2{p_rect.x, p_rect.y + p_rect.height}
		tr := rl.Vector2{p_rect.x + p_rect.width, p_rect.y}
		br := rl.Vector2{p_rect.x + p_rect.width, p_rect.y + p_rect.height}
		rl.DrawRectangleV(p.position, {PW, PH}, PCOLOR)
		rl.DrawLineEx(tl, tr, 1, rl.WHITE)
		rl.DrawLineEx(tl, bl, 1, rl.WHITE)
		rl.DrawLineEx(tr, br, 1, rl.BLACK)
		rl.DrawLineEx(bl, br, 1, rl.BLACK)
	}

	draw_ball :: proc(b: ^Ball) {
		rl.DrawCircleGradient(
			i32(b.position.x),
			i32(b.position.y),
			BRAD,
			rl.Color{136, 5, 5, 255},
			rl.Color{41, 5, 5, 255},
		)
		rl.DrawCircle(
			i32(b.position.x - 1),
			i32(b.position.y - 1),
			BRAD * 0.25,
			rl.Color{255, 255, 255, 90},
		)
	}

	draw_bg_rect :: proc() {
		rl.DrawRectangleGradientV(
			0,
			0,
			SS,
			SS,
			rl.Color{0, 116, 152, 255},
			rl.Color{0, 163, 164, 255},
		)
	}

	draw :: proc(p: ^Paddle, b: ^Ball, blocks: BlockGrid, dt: f32) {
		draw_bg_rect()
		draw_paddle(p, dt)
		draw_ball(b)
		draw_blocks(blocks)
		draw_score()
		if len(blocks) == 0 || game_over {
			draw_game_over_text()
		}
	}

	restart(&paddle, &ball)


	for !rl.WindowShouldClose() {
		dt: f32
		rl.BeginDrawing()
		rl.ClearBackground(rl.WHITE)
		rl.BeginMode2D(cam)
		move(&paddle, &ball, &dt)
		draw(&paddle, &ball, blocks, dt)
		rl.EndMode2D()
		rl.EndDrawing()
		free_all(context.temp_allocator)
	}
	rl.CloseWindow()

}
