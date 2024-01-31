package main

import "core:fmt"
import "core:mem"
import "core:math/rand"
import "../../gui"
import "../widgets"

window: Window
grid: gui.Widget
buttons: [8]widgets.Button

main :: proc() {
    when ODIN_DEBUG {
        track: mem.Tracking_Allocator
        mem.tracking_allocator_init(&track, context.allocator)
        context.allocator = mem.tracking_allocator(&track)

        defer {
            if len(track.allocation_map) > 0 {
                fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
                for _, entry in track.allocation_map {
                    fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
                }
            }
            if len(track.bad_free_array) > 0 {
                fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
                for entry in track.bad_free_array {
                    fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
                }
            }
            mem.tracking_allocator_destroy(&track)
        }
    }

    init_window(&window,
        position = {50, 50},
        size = {400, 300},
        background_color = {0.2, 0.2, 0.2, 1},
    )
    defer destroy_window(&window)

    window.root.event_proc = proc(widget: ^gui.Widget, event: any) {
        switch e in event {
        case gui.Resize_Event:
            gui.set_size(&grid, e.size)
        }
        gui.root_event_proc(widget, event)
    }

    gui.init_widget(&grid,
        size = {400, 300},
        event_proc = proc(widget: ^gui.Widget, event: any) {
            switch e in event {
            case gui.Open_Event:
                gui.layout_grid(widget.children[:],
                    shape = {3, 3},
                    size = widget.size,
                    spacing = {5, 5},
                    padding = {10, 10},
                )
                gui.redraw()
            case gui.Resize_Event:
                gui.layout_grid(widget.children[:],
                    shape = {3, 3},
                    size = widget.size,
                    spacing = {5, 5},
                    padding = {10, 10},
                )
                gui.redraw()
            case gui.Draw_Event:
                gui.draw_rect({0, 0}, widget.size, {0.4, 0, 0, 1})
            }
        },
    )
    defer gui.destroy_widget(&grid)

    gui.add_children(&window.root, {&grid})

    for &button, i in buttons {
        widgets.init_button(&button,
            position = {f32(i * 20), f32(i * 20)},
            size = {32 + rand.float32() * 100, 32 + rand.float32() * 100},
            event_proc = proc(widget: ^gui.Widget, event: any) {
                button := cast(^widgets.Button)widget
                switch e in event {
                case gui.Mouse_Move_Event:
                    if button.is_down {
                        gui.set_position(button, button.position + e.delta)
                        gui.redraw()
                    }
                case widgets.Button_Click_Event:
                    fmt.println("Clicked")
                }
                widgets.button_event_proc(button, event)
            },
        )
        gui.add_children(&grid, {&button})
    }
    defer for &button, i in buttons {
        widgets.destroy_button(&button)
    }

    open_window(&window)
    for window_is_open(&window) {
        update()
    }
}