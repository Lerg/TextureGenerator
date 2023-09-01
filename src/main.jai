Basic           :: #import "Basic";
Math            :: #import "Math";
Stb_Image       :: #import "stb_image";
Simp            :: #import "Simp";
Input           :: #import "Input";
Window_Creation :: #import "Window_Creation";
GetRect         :: #import "GetRect";

Generator :: #import,file "generator.jai";

KEYS :: struct {
	N     :: #char "N";
	S     :: #char "S";
	R     :: #char "R";
	SPACE :: #char " ";
}

state : struct {
	window_width          : s32 = 1920;
	window_height         : s32 = 1080;
	generation_type       :     = Generator.Generation_Type.SAND_RIPPLES;
	bitmap_width          : s32 = 512;
	bitmap_height         : s32 = 512;
	bitmap_texture_format :     = Simp.Texture_Format.RGBA8;
	bitmap                : Simp.Bitmap;
	texture               : Simp.Texture;
	font                  : *Simp.Dynamic_Font;
	is_simulation_running : bool;
	is_normal_map         : bool;
}

drawBackground :: () {
	background_color := Math.Vector4.{0.2, 0.2, 0.2, 1};
	Simp.set_shader_for_color();
	Simp.immediate_begin();
	Simp.immediate_quad(0, 0, xx state.window_width, xx state.window_height, background_color);
	Simp.immediate_flush();
}

drawTexture :: () {
	background_color := Math.Vector4.{1, 1, 1, 1};
	Simp.set_shader_for_images(*state.texture);
	Simp.immediate_begin();
	scale := 1;
	w, h  := scale * state.bitmap_width, scale * state.bitmap_height;
	Simp.immediate_quad(
		0.5 * (state.window_width - w),
		0.5 * (state.window_height - h),
		0.5 * (state.window_width + w),
		0.5 * (state.window_height + h),
		background_color
	);
	Simp.immediate_flush();
}

generateBitmap :: () {
	if (state.bitmap_width != state.bitmap.width || state.bitmap_height != state.bitmap.height) {
		Simp.deinit(*state.bitmap);
		Simp.bitmap_alloc(*state.bitmap, state.bitmap_width, state.bitmap_height, state.bitmap_texture_format);
	}

	Generator.generate(state.generation_type, *state.bitmap);
	result := Simp.texture_load_from_bitmap(*state.texture, *state.bitmap);
	Basic.print("Texture generated: %.\n", result);
}

generateSimulationStep :: () {
	if state.generation_type == .SAND_RIPPLES {
		Generator.simulationStep(state.generation_type, *state.bitmap);
		Simp.texture_load_from_bitmap(*state.texture, *state.bitmap);
	}
}

saveBitmap :: () {
	name   := ifx state.is_normal_map "texture_normal.png" else "texture.png";
	result := Simp.bitmap_save(*state.bitmap, name);
	Basic.print("Texture saved: %.\n", result);
}

initFonts :: () {
	pixel_height := state.window_height / 24;
	state.font    = Simp.get_font_at_size("data", "Roboto-Regular.ttf", pixel_height);
}

main :: () {
	window := Window_Creation.create_window(
		window_name = "Texture Generator",
		width       = state.window_width,
		height      = state.window_height
	);
	Simp.set_render_target(window);
	initFonts();
	GetRect.ui_init();
	Generator.init();

	generateBitmap();

	should_quit := false;
	while !should_quit {
		Basic.reset_temporary_storage();

		Input.update_window_events();

		for Input.get_window_resizes() {
			Simp.update_window(it.window);
			if it.window == window {
				should_reinit := (it.width != state.window_width) || (it.height != state.window_height);
				state.window_width  = it.width;
				state.window_height = it.height;
			}
		}

		for event: Input.events_this_frame {
			if event.type == .QUIT then should_quit = true;

			GetRect.getrect_handle_event(event);

			if event.type == {
				case .KEYBOARD;
					if event.key_pressed {
						if event.key_code        == .ESCAPE {
							should_quit = true;
						} else if event.key_code == KEYS.S {
							saveBitmap();
						} else if event.key_code == KEYS.R {
							generateBitmap();
						} else if event.key_code == KEYS.SPACE {
							state.is_simulation_running = !state.is_simulation_running;
							Basic.print("Simulation: %\n", state.is_simulation_running);
						} else if event.key_code == KEYS.N {
							state.is_normal_map = !state.is_normal_map;
							Generator.setIsNormalMap(state.is_normal_map);
							Basic.print("Normal map: %\n", state.is_normal_map);
						}
					}
			}
		}

		if state.is_simulation_running {
			generateSimulationStep();
		}

		drawBackground();
		drawTexture();

		Simp.swap_buffers(window);
	}
}
