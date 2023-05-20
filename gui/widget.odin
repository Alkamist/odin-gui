package gui

import "core:slice"
import "core:strings"
import vg "../vector_graphics"

Color :: [4]f32

Cursor_Style :: enum {
    Arrow,
    I_Beam,
    Crosshair,
    Pointing_Hand,
    Resize_Left_Right,
    Resize_Top_Bottom,
    Resize_Top_Left_Bottom_Right,
    Resize_Top_Right_Bottom_Left,
}

Widget :: struct {
    destroy: proc(widget: ^Widget),
    update: proc(widget: ^Widget),
    draw: proc(widget: ^Widget),
    shared_state: ^Shared_State,
    parent: ^Widget,
    children: [dynamic]^Widget,
    position: [2]f32,
    size: [2]f32,
    dont_draw: bool,
    clip_drawing: bool,
    clip_input: bool,
    consume_input: bool,
}

global_position :: proc(widget: ^Widget) -> [2]f32 {
    if is_root(widget) {
        return widget.position
    } else {
        return widget.position + global_position(widget.parent)
    }
}
global_mouse_position :: proc(widget: ^Widget) -> [2]f32 {
    return widget.shared_state.mouse_position
}
mouse_position :: proc(widget: ^Widget) -> [2]f32 {
    return global_position(widget) + widget.shared_state.mouse_position
}
delta_time :: proc(widget: ^Widget) -> f32 {
    state := widget.shared_state
    return state.time - state.previous_time
}
mouse_down :: proc(widget: ^Widget, button: Mouse_Button) -> bool {
    state := widget.shared_state
    return state.mouse_down_states[button]
}
key_down :: proc(widget: ^Widget, key: Keyboard_Key) -> bool {
    state := widget.shared_state
    return state.key_down_states[key]
}
mouse_moved :: proc(widget: ^Widget) -> bool {
    state := widget.shared_state
    return state.mouse_delta != {0, 0}
}
mouse_wheel_moved :: proc(widget: ^Widget) -> bool {
    state := widget.shared_state
    return state.mouse_wheel != {0, 0}
}
mouse_pressed :: proc(widget: ^Widget, button: Mouse_Button) -> bool {
    state := widget.shared_state
    return slice.contains(state.mouse_presses[:], button)
}
mouse_released :: proc(widget: ^Widget, button: Mouse_Button) -> bool {
    state := widget.shared_state
    return slice.contains(state.mouse_releases[:], button)
}
any_mouse_pressed :: proc(widget: ^Widget) -> bool {
    state := widget.shared_state
    return len(state.mouse_presses) > 0
}
any_mouse_released :: proc(widget: ^Widget) -> bool {
    state := widget.shared_state
    return len(state.mouse_releases) > 0
}
key_pressed :: proc(widget: ^Widget, key: Keyboard_Key) -> bool {
    state := widget.shared_state
    return slice.contains(state.key_presses[:], key)
}
key_released :: proc(widget: ^Widget, key: Keyboard_Key) -> bool {
    state := widget.shared_state
    return slice.contains(state.key_releases[:], key)
}
any_key_pressed :: proc(widget: ^Widget) -> bool {
    state := widget.shared_state
    return len(state.key_presses) > 0
}
any_key_released :: proc(widget: ^Widget) -> bool {
    state := widget.shared_state
    return len(state.key_releases) > 0
}
is_hovered :: proc(widget: ^Widget) -> bool {
    state := widget.shared_state
    return slice.contains(state.hovers[:], widget)
}
is_hovered_including_children :: proc(widget: ^Widget) -> bool {
    if is_hovered(widget) {
        return true
    }
    for child in widget.children {
        if is_hovered_including_children(child) {
            return true
        }
    }
    return false
}
capture_mouse :: proc(widget: ^Widget) {
    widget.shared_state.mouse_capture = widget
}
release_mouse_capture :: proc(widget: ^Widget) {
    widget.shared_state.mouse_capture = nil
}

is_root :: proc(widget: ^Widget) -> bool {
    return widget.parent == nil
}

get_vg_ctx :: proc(widget: ^Widget) -> ^vg.Context {
    return widget.shared_state.vg_ctx
}

new_root :: proc() -> ^Widget {
    widget := new(Widget)

    widget.dont_draw = false
    widget.consume_input = false
    widget.clip_input = false
    widget.clip_drawing = false

    widget.shared_state = shared_state_create()
    widget.update = proc(widget: ^Widget) { update_children(widget) }
    widget.draw = proc(widget: ^Widget) { draw_children(widget) }
    return widget
}

add_widget :: proc(parent: ^Widget, $T: typeid) -> ^T {
    widget := new(T)

    widget.dont_draw = false
    widget.consume_input = true
    widget.clip_input = true
    widget.clip_drawing = true

    widget.shared_state = parent.shared_state
    widget.parent = parent
    widget.update = proc(widget: ^Widget) { update_children(widget) }
    widget.draw = proc(widget: ^Widget) { draw_children(widget) }

    append(&parent.children, widget)
    return widget
}

destroy :: proc(widget: ^Widget) {
    if widget.destroy != nil {
        widget->destroy()
    }
    for child in widget.children {
        destroy(child)
    }
    delete(widget.children)
    if is_root(widget) {
        shared_state_destroy(widget.shared_state)
    }
    free(widget)
}

update :: proc(widget: ^Widget) {
    if widget.update != nil {
        widget->update()
    }
}

draw :: proc(widget: ^Widget) {
    if widget.dont_draw {
        return
    }
    if widget.draw != nil {
        widget->draw()
    }
}

update_children :: proc(widget: ^Widget) {
    ctx := get_vg_ctx(widget)
    for child in widget.children {
        vg.save(ctx)
        vg.translate(ctx, child.position)
        if widget.clip_drawing {
            vg.clip(ctx, {0, 0}, child.size)
        }
        update(child)
        vg.restore(ctx)
    }
}

draw_children :: proc(widget: ^Widget) {
    ctx := get_vg_ctx(widget)
    for child in widget.children {
        vg.save(ctx)
        vg.translate(ctx, child.position)
        if widget.clip_drawing {
            vg.clip(ctx, {0, 0}, child.size)
        }
        draw(child)
        vg.restore(ctx)
    }
}

bring_to_top :: proc(widget: ^Widget) {
    parent := widget.parent

    // Already on top.
    if parent.children[len(parent.children) - 1] == widget {
        return
    }

    found_child := false

    // Go through all the children to find the widget.
    for i in 0 ..< len(parent.children) - 1 {
        if !found_child && parent.children[i] == widget {
            found_child = true
        }
        // When found, shift all widgets afterward one index lower.
        if found_child {
            parent.children[i] = parent.children[i + 1]
        }
    }

    // Put the widget at the end.
    if found_child {
        parent.children[len(parent.children) - 1] = widget
    }
}

point_is_inside :: proc(widget: ^Widget, point: [2]f32) -> bool {
    w_pos := widget.position
    w_size := widget.size
    return point.x >= w_pos.x && point.x <= w_pos.x + w_size.x &&
           point.y >= w_pos.y && point.y <= w_pos.y + w_size.y
}

update_hovers :: proc(root: ^Widget) {
    if !is_root(root) {
        return
    }

    state := root.shared_state
    clear(&state.hovers)

    child_hit_test := _child_mouse_hit_test(root)
    for i := len(child_hit_test) - 1; i >= 0; i -= 1 {
        hit := child_hit_test[i]
        append(&state.hovers, hit)
        if hit.consume_input {
            return
        }
    }

    if point_is_inside(root, state.mouse_position) && state.mouse_capture == nil {
        append(&state.hovers, root)
    }

    if state.mouse_capture != nil {
        append(&state.hovers, state.mouse_capture)
    }
}

_child_mouse_hit_test :: proc(widget: ^Widget) -> (res: [dynamic]^Widget) {
    mouse_capture := widget.shared_state.mouse_capture
    for child in widget.children {
        mouse_inside := point_is_inside(child, mouse_position(widget)) || !child.clip_input
        no_capture := mouse_capture == nil
        capture_is_child := mouse_capture != nil && mouse_capture == child
        if (no_capture && mouse_inside) || (capture_is_child && mouse_inside) {
            append(&res, child)
            hit_test := _child_mouse_hit_test(child)
            for hit in hit_test {
                append(&res, hit)
            }
        }
    }
    return
}