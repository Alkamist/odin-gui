package widgets

import "core:fmt"
import "core:time"
import "../gui"

Performance :: struct {
    frame_time: f32,
    average_window: int,
    index: int,
    delta_times: [dynamic]time.Duration,
    previous_average_window: int,
}

init_performance :: proc(ctx: ^Context, perf: ^Performance, average_window := 100) {
    perf.average_window = average_window
    perf.delta_times = make([dynamic]time.Duration, average_window, average_window)
}

destroy_performance :: proc(ctx: ^Context, perf: ^Performance) {
    delete(perf.delta_times)
}

frame_time :: proc(ctx: ^Context, perf: ^Performance) -> f32 {
    return perf.frame_time
}

fps :: proc(ctx: ^Context, perf: ^Performance) -> f32 {
    return 1.0 / perf.frame_time
}

update_performance :: proc(ctx: ^Context, perf: ^Performance) {
    average_window := perf.average_window

    if average_window != perf.previous_average_window {
        perf.index = 0
        resize(&perf.delta_times, average_window)
    }

    if perf.index < len(perf.delta_times) {
        perf.delta_times[perf.index] = gui.delta_time(ctx)
    }

    perf.index += 1
    if perf.index >= len(perf.delta_times) {
        perf.index = 0
    }

    perf.frame_time = 0

    for dt in perf.delta_times {
        perf.frame_time += f32(time.duration_seconds(dt))
    }

    perf.frame_time /= f32(average_window)
    perf.previous_average_window = average_window
}

draw_performance :: proc(ctx: ^Context, perf: ^Performance) {
    fps_str := fmt.aprintf("Fps: %v", fps(ctx, perf))
    defer delete(fps_str)
    gui.fill_text_line(ctx, fps_str, {0, 0})
}