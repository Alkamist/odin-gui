package gui

import "core:math"
import nvg "vendor:nanovg"
import "color"

Color :: color.Color
Paint :: nvg.Paint

Path_Winding :: enum {
    Positive,
    Negative,
}

solid_paint :: proc(color: Color) -> Paint {
    paint: Paint
    nvg.TransformIdentity(&paint.xform)
    paint.radius = 0.0
    paint.feather = 1.0
    paint.innerColor = color
    paint.outerColor = color
    return paint
}

quantize :: proc{
    quantize_f32,
    quantize_vec2,
}

quantize_f32 :: proc(value, distance: f32) -> f32 {
    return math.round(value / distance) * distance
}

quantize_vec2 :: proc(vec: Vec2, distance: f32) -> Vec2 {
    return {
        math.round(vec.x / distance) * distance,
        math.round(vec.y / distance) * distance,
    }
}

pixel_distance :: proc(window := _current_window) -> f32 {
    return 1.0 / window.cached_content_scale
}

pixel_align :: proc{
    pixel_align_f32,
    pixel_align_vec2,
}

pixel_align_f32 :: proc(value: f32, window := _current_window) -> f32 {
    return quantize_f32(value, pixel_distance(window))
}

pixel_align_vec2 :: proc(vec: Vec2, window := _current_window) -> Vec2 {
    pixel_distance := pixel_distance(window)
    return {
        quantize_f32(vec.x, pixel_distance),
        quantize_f32(vec.y, pixel_distance),
    }
}

begin_path :: proc() {
    append(&get_layer().draw_commands, Begin_Path_Command{})
}

close_path :: proc() {
    append(&get_layer().draw_commands, Close_Path_Command{})
}

path_move_to :: proc(position: Vec2) {
    append(&get_layer().draw_commands, Move_To_Command{
        position + get_offset(),
    })
}

path_line_to :: proc(position: Vec2) {
    append(&get_layer().draw_commands, Line_To_Command{
        position + get_offset(),
    })
}

path_arc_to :: proc(p0, p1: Vec2, radius: f32) {
    offset := get_offset()
    append(&get_layer().draw_commands, Arc_To_Command{
        p0 + offset,
        p1 + offset,
        radius,
    })
}

path_rect :: proc(position, size: Vec2, winding: Path_Winding = .Positive) {
    layer := get_layer()
    append(&layer.draw_commands, Rect_Command{
        position + get_offset(),
        size,
    })
    append(&layer.draw_commands, Winding_Command{winding})
}

path_rounded_rect_varying :: proc(position, size: Vec2, top_left_radius, top_right_radius, bottom_right_radius, bottom_left_radius: f32, winding: Path_Winding = .Positive) {
    layer := get_layer()
    append(&layer.draw_commands, Rounded_Rect_Command{
        position + get_offset(),
        size,
        top_left_radius, top_right_radius,
        bottom_right_radius, bottom_left_radius,
    })
    append(&layer.draw_commands, Winding_Command{winding})
}

path_rounded_rect :: proc(position, size: Vec2, radius: f32, winding: Path_Winding = .Positive) {
    path_rounded_rect_varying(position, size, radius, radius, radius, radius, winding)
}

fill_path_paint :: proc(paint: Paint) {
    append(&get_layer().draw_commands, Fill_Path_Command{paint})
}

fill_path :: proc(color: Color) {
    fill_path_paint(solid_paint(color))
}

stroke_path_paint :: proc(paint: Paint, width := f32(1)) {
    append(&get_layer().draw_commands, Stroke_Path_Command{paint, width})
}

stroke_path :: proc(color: Color, width := f32(1)) {
    append(&get_layer().draw_commands, Stroke_Path_Command{solid_paint(color), width})
}

fill_text_line :: proc(
    text: string,
    position: Vec2,
    color := Color{1, 1, 1, 1},
    font := _current_window.default_font,
    font_size := _current_window.default_font_size,
) {
    metrics := text_metrics(font, font_size)
    center_offset := Vec2{0, metrics.ascender}
    append(&get_layer().draw_commands, Fill_Text_Command{
      font = font,
      font_size = font_size,
      position = pixel_align(position + get_offset() + center_offset),
      text = text,
      color = color,
    })
}



@(private)
_path_winding_to_nvg_winding :: proc(winding: Path_Winding) -> nvg.Winding {
    switch winding {
    case .Negative: return .CW
    case .Positive: return .CCW
    }
    return .CW
}