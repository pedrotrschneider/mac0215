package main

import rl "vendor:raylib"
import  "core:math"
import c "core:c"
import  "core:strings"
import  "core:fmt"

sqrt :: proc(f: f64) -> f64 {
            return math.sqrt(f)
        }

println :: proc(s: string) {
            fmt.println(s)
        }

RlInitWindow :: proc(width, height: f64, windowName: string) {
            rl.InitWindow(c.int(width), c.int(height), strings.unsafe_string_to_cstring(windowName))
        }

RlCloseWindow :: proc() {
            rl.CloseWindow()
        }

RlWindowShouldClose :: proc() -> bool {
            return rl.WindowShouldClose()
        }

RlSetTargetFPS :: proc(target: f64) {
            rl.SetTargetFPS(c.int(target))
        }

RlPollInputEvents :: proc() {
            rl.PollInputEvents()
        }

RlIsKeyPressed :: proc(key: f64) -> bool {
            return rl.IsKeyPressed(rl.KeyboardKey(key))
        }

RlIsKeyDown :: proc(key: f64) -> bool {
            return rl.IsKeyDown(rl.KeyboardKey(key))
        }

RlBeginDrawing :: proc() {
            rl.BeginDrawing()
        }

RlEndDrawing :: proc() {
            rl.EndDrawing()
        }

RlClearBackground :: proc(r, g, b, a: f64) {
            rl.ClearBackground(rl.Color { u8(r), u8(g), u8(b), u8(a) })
        }

RlDrawRectangle :: proc(px, py, width, height, r, g, b, a: f64) {
            rl.DrawRectangle(c.int(px), c.int(py), c.int(width), c.int(height), rl.Color { u8(r), u8(g), u8(b), u8(a) })
        }

RlDrawCircle :: proc(px, py, radius, r, g, b, a: f64) {
            rl.DrawCircle(c.int(px), c.int(py), f32(radius), rl.Color { u8(r), u8(g), u8(b), u8(a) })
        }

RlDeltaTime :: proc() -> f64 {
            return f64(rl.GetFrameTime())
        }

RlKeyEscape :: proc() -> f64 {
            return f64(int(rl.KeyboardKey.ESCAPE))
        }

RlKeyUp :: proc() -> f64 {
            return f64(int(rl.KeyboardKey.UP))
        }

RlKeyDown :: proc() -> f64 {
            return f64(int(rl.KeyboardKey.DOWN))
        }

RlKeyW :: proc() -> f64 {
            return f64(int(rl.KeyboardKey.W))
        }

RlKeyS :: proc() -> f64 {
            return f64(int(rl.KeyboardKey.S))
        }


WINDOW_WIDTH:f64=2400
WINDOW_HEIGHT:f64=1600


PADDLE_WIDTH:f64=40
PADDLE_HEIGHT:f64=400
PADDLE_WALL_OFFSET:f64=40
PADDLE_SPEED:f64=300

paddle1PosX:f64=PADDLE_WALL_OFFSET
paddle1PosY:f64=WINDOW_HEIGHT*0.5

paddle2PosX:f64=WINDOW_WIDTH-PADDLE_WIDTH-PADDLE_WALL_OFFSET
paddle2PosY:f64=WINDOW_HEIGHT*0.5

DrawPaddle::proc(posX:f64, posY:f64){
RlDrawRectangle(posX, posY-PADDLE_HEIGHT*0.5, PADDLE_WIDTH, PADDLE_HEIGHT, 255, 255, 255, 255)
}

UpdatePaddles::proc(){
if RlIsKeyDown(RlKeyUp()){
paddle2PosY=paddle2PosY-PADDLE_SPEED*RlDeltaTime()
if paddle2PosY<PADDLE_HEIGHT*0.5{
paddle2PosY=PADDLE_HEIGHT*0.5
}
}
if RlIsKeyDown(RlKeyDown()){
paddle2PosY=paddle2PosY+PADDLE_SPEED*RlDeltaTime()
if paddle2PosY>WINDOW_HEIGHT-PADDLE_HEIGHT*0.5{
paddle2PosY=WINDOW_HEIGHT-PADDLE_HEIGHT*0.5
}
}

if RlIsKeyDown(RlKeyW()){
paddle1PosY=paddle1PosY-PADDLE_SPEED*RlDeltaTime()
if paddle1PosY<PADDLE_HEIGHT*0.5{
paddle1PosY=PADDLE_HEIGHT*0.5
}
}
if RlIsKeyDown(RlKeyS()){
paddle1PosY=paddle1PosY+PADDLE_SPEED*RlDeltaTime()
if paddle1PosY>WINDOW_HEIGHT-PADDLE_HEIGHT*0.5{
paddle1PosY=WINDOW_HEIGHT-PADDLE_HEIGHT*0.5
}
}
}

DrawPaddles::proc(){
DrawPaddle(paddle1PosX, paddle1PosY)
DrawPaddle(paddle2PosX, paddle2PosY)
}


BALL_SIZE:f64=75

ballPosX:f64=WINDOW_WIDTH*0.5
ballPosY:f64=WINDOW_HEIGHT*0.5

ballDirX:f64=sqrt(2)*0.5
ballDirY:f64=-sqrt(2)*0.5
ballSpeed:f64=10

UpdateBall::proc(){
ballPosX=ballPosX+ballDirX*ballSpeed
ballPosY=ballPosY+ballDirY*ballSpeed

if ballPosX<BALL_SIZE*0.5{
println("Player 2 won the game")
ballSpeed=0
}
if ballPosX>WINDOW_WIDTH-BALL_SIZE*0.5{
println("Player 1 won the game")
ballSpeed=0
}

if ballDirY<0&&ballPosY<BALL_SIZE*0.5{
ballDirY=-ballDirY
}
if ballDirY>0&&ballPosY>WINDOW_HEIGHT-BALL_SIZE*0.5{
ballDirY=-ballDirY
}

if ballDirX<0{
if ballPosX<paddle1PosX+PADDLE_WIDTH+BALL_SIZE*0.5{
if ballPosY+BALL_SIZE*0.5>paddle1PosY-PADDLE_HEIGHT*0.5&&ballPosY-BALL_SIZE*0.5<paddle1PosY+PADDLE_HEIGHT*0.5{
ballDirX=-ballDirX
}
}
}

if ballDirX>0{
if ballPosX>paddle2PosX-BALL_SIZE*0.5{
if ballPosY+BALL_SIZE*0.5>paddle2PosY-PADDLE_HEIGHT*0.5&&ballPosY-BALL_SIZE*0.5<paddle2PosY+PADDLE_HEIGHT*0.5{
ballDirX=-ballDirX
}
}
}
}

DrawBall::proc(){
RlDrawRectangle(ballPosX-BALL_SIZE*0.5, ballPosY-BALL_SIZE*0.5, BALL_SIZE, BALL_SIZE, 255, 255, 255, 255)
}


DrawField::proc(){
RlDrawCircle(WINDOW_WIDTH*0.5, WINDOW_HEIGHT*0.5, WINDOW_HEIGHT*0.20, 100, 100, 100, 255)
RlDrawCircle(WINDOW_WIDTH*0.5, WINDOW_HEIGHT*0.5, WINDOW_HEIGHT*0.18, 0, 0, 0, 255)

RlDrawCircle(WINDOW_WIDTH*0.5, WINDOW_HEIGHT*0.5, WINDOW_HEIGHT*0.05, 100, 100, 100, 255)
RlDrawCircle(WINDOW_WIDTH*0.5, WINDOW_HEIGHT*0.5, WINDOW_HEIGHT*0.03, 0, 0, 0, 255)

RlDrawRectangle(WINDOW_WIDTH*0.5-WINDOW_HEIGHT*0.01, 0, WINDOW_HEIGHT*0.02, WINDOW_HEIGHT, 100, 100, 100, 255)

RlDrawCircle(0, WINDOW_HEIGHT*0.5, WINDOW_HEIGHT*0.25, 100, 100, 100, 255)
RlDrawCircle(0, WINDOW_HEIGHT*0.5, WINDOW_HEIGHT*0.23, 0, 0, 0, 255)

RlDrawCircle(WINDOW_WIDTH, WINDOW_HEIGHT*0.5, WINDOW_HEIGHT*0.25, 100, 100, 100, 255)
RlDrawCircle(WINDOW_WIDTH, WINDOW_HEIGHT*0.5, WINDOW_HEIGHT*0.23, 0, 0, 0, 255)
}


main::proc(){
RlInitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Hello from Yupii")
RlSetTargetFPS(60)

for ;!(RlWindowShouldClose()||RlIsKeyPressed(RlKeyEscape()));{
RlPollInputEvents()

RlClearBackground(0, 0, 0, 255)

UpdateBall()
UpdatePaddles()

RlBeginDrawing()
DrawField()
DrawBall()
DrawPaddles()
RlEndDrawing()
}

RlCloseWindow()
}
