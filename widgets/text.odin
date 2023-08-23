package widgets

import "core:fmt"
import "core:mem"
import "core:strings"
import text_edit "core:text/edit"
import "../../gui"

Font :: gui.Font
Glyph :: gui.Glyph

Text :: struct {
    using button_state: Button,

    builder: strings.Builder,
    color: Color,
    selection_color: Color,
    font: ^Font,
    font_size: f32,

    glyphs: [dynamic]Glyph,
    ascender: f32,
    descender: f32,
    x_height: f32,

    _edit_state: text_edit.State,
    _is_dragging: bool,
    _drag_start: int,
    _drag_finish: int,
}

index_at_position :: proc(text: ^Text, position: Vec2) -> int {
    if position.x < text.position.x {
        return 0
    }

    for glyph, i in text.glyphs {
        left := text.position.x + glyph.left
        right := text.position.x + glyph.right

        if position.x >= left && position.x < right {
            return i
        }
    }

    return len(text.glyphs)
}

start_drag_selection :: proc(text: ^Text, index: int) {
    text._edit_state.selection = index
    text._drag_start = index
    text._is_dragging = true
}

process_drag_selection :: proc(text: ^Text, index: int) {
    text._drag_finish = index
    text._edit_state.selection[0] = min(text._drag_start, text._drag_finish)
    text._edit_state.selection[1] = max(text._drag_start, text._drag_finish)
}

finish_drag_selection :: proc(text: ^Text) {
    text._is_dragging = false
}

no_text_selected :: proc(text: ^Text) -> bool {
    return abs(text._edit_state.selection[0] - text._edit_state.selection[1]) == 0
}

backspace_text :: proc(text: ^Text) {
    if no_text_selected(text) {
        text_edit.delete_to(&text._edit_state, .Left)
    } else {
        text_edit.selection_delete(&text._edit_state)
    }
}

input_rune :: proc(text: ^Text, r: rune) {
    text_edit.input_runes(&text._edit_state, {r})
}

input_text :: proc(text: ^Text, data: string) {
    text_edit.input_text(&text._edit_state, data)
}

init_text :: proc(
    text: ^Text,
    data := "",
    position := Vec2{0, 0},
    color := Color{1, 1, 1, 1},
    selection_color := Color{0.36, 0.6, 0.98, 0.6},
    font := _default_font,
    font_size := f32(13),
    allocator := context.allocator,
) -> (res: ^Text, err: mem.Allocator_Error) #optional_allocator_error {
    text.font = font
    text.font_size = font_size
    text.position = position
    text.color = color
    text.selection_color = selection_color

    text.glyphs = make([dynamic]Glyph, allocator) or_return

    strings.builder_init(&text.builder, allocator) or_return
    strings.write_string(&text.builder, data)

    text_edit.init(&text._edit_state, allocator, allocator)

    return text, nil
}

destroy_text :: proc(text: ^Text) {
    strings.builder_destroy(&text.builder)
    text_edit.destroy(&text._edit_state)
    delete(text.glyphs)
}

update_text :: proc(text: ^Text) {
    if text.font == nil || text.font_size <= 0 {
        return
    }

    ascender, descender, line_height := gui.text_metrics(text.font, text.font_size)
    text.ascender = ascender
    text.descender = descender
    text.x_height = ascender + descender

    text.size.y = line_height

    if strings.builder_len(text.builder) == 0 {
        return
    }

    gui.measure_glyphs(&text.glyphs, strings.to_string(text.builder), text.font, text.font_size)

    if len(text.glyphs) > 0 {
        text.size.x = text.glyphs[len(text.glyphs) - 1].right - text.glyphs[0].left
    }

    update_button_ex(
        text,
        hover = gui.mouse_hit_test(text.position, text.size),
        press = gui.mouse_pressed(.Left),
        release = gui.mouse_released(.Left),
    )
}

edit_text :: proc(text: ^Text) {
    text_edit.end(&text._edit_state)

    last_selection := text._edit_state.selection
    text_edit.begin(&text._edit_state, 0, &text.builder)
    text._edit_state.selection = last_selection

    mouse_position := gui.mouse_position()
    hover_index := index_at_position(text, mouse_position)

    if gui.mouse_pressed(.Left) {
        start_drag_selection(text, hover_index)
    }
    if gui.mouse_down(.Left){
        process_drag_selection(text, hover_index)
    }
    if gui.mouse_released(.Left) {
        finish_drag_selection(text)
    }

    if data := gui.text_input(); data != "" {
        for r in data {
            switch r {
            case 8: backspace_text(text) // Backspace
            case 13: continue            // Enter
            case: input_rune(text, r)    // Anything else
            }
        }
    }

    // Drawing code.
    if strings.builder_len(text.builder) == 0 || len(text.glyphs) == 0 {
        return
    }

    low, high := text_edit.sorted_selection(&text._edit_state)

    // Draw selection.
    if high - low > 0 {
        low := clamp(low, 0, len(text.glyphs) - 1)

        selection_position := text.position + {text.glyphs[low].left, 0}

        selection_size := Vec2{0, text.size.y}
        if high < len(text.glyphs) {
            selection_size.x += text.glyphs[high - 1].right - text.glyphs[low].left
        } else {
            selection_size.x += text.glyphs[len(text.glyphs) - 1].right - text.glyphs[low].left
        }

        gui.begin_path()
        gui.path_rounded_rect(selection_position, selection_size, 3)
        gui.fill_path(text.selection_color)

    // Draw caret.
    } else {
        pixel := gui.pixel_distance()

        caret_position := text.position
        if low < len(text.glyphs) {
            low := max(low, 0)
            caret_position.x += text.glyphs[low].left
        } else {
            caret_position.x += text.glyphs[len(text.glyphs) - 1].right
        }

        gui.begin_path()
        gui.path_move_to(caret_position)
        gui.path_line_to(caret_position + {0, text.size.y})
        gui.stroke_path(text.selection_color, pixel)
    }
}

draw_text :: proc(text: ^Text) {
    if text.font == nil || text.font_size <= 0 || strings.builder_len(text.builder) == 0 || len(text.glyphs) == 0 {
        return
    }

    text_offset := Vec2{
        text.glyphs[0].draw_offset_x,
        text.size.y * 0.5 - text.x_height,
    }

    gui.fill_text_raw(
        strings.to_string(text.builder),
        text.position + text_offset,
        color = text.color,
        font = text.font,
        font_size = text.font_size,
    )
}