#scope_file

Basic  :: #import "Basic";
Simp   :: #import "Simp";
Math   :: #import "Math";
Random :: #import "Random";

Dune_Simulator :: #import,file "dune_simulator.jai";

operator+ :: Math.operator+;
operator- :: Math.operator-;
operator* :: Math.operator*;
operator/ :: Math.operator/;

setPixel :: (bitmap: *Simp.Bitmap, x: int, y: int, value: Math.Vector3) {
	bpp := Simp.get_image_bytes_per_texel(bitmap.format);
	index := bpp * (x + y * bitmap.width);
	for i: 0 .. 2 {
		bitmap.data[index + i] = cast(u8) Math.floor(255 * value.component[i] + 0.5);
	}
	bitmap.data[index + 3] = 255;
}

randomNoise :: (bitmap: *Simp.Bitmap) {
	for y: 0 .. bitmap.height - 1 {
		for x: 0 .. bitmap.width - 1 {
			value := Math.Vector3.{
				Random.random_get_zero_to_one(),
				Random.random_get_zero_to_one(),
				Random.random_get_zero_to_one()
			};
			setPixel(bitmap, x, y, value);
		}
	}
}

gaussianNoise :: (bitmap: *Simp.Bitmap) {
	for y: 0 .. bitmap.height - 1 {
		for x: 0 .. bitmap.width - 1 {
			// Box–Muller transform
			u1     := Basic.max(Random.random_get_zero_to_one(), 0.01);
			u2     := Random.random_get_zero_to_one();
			radius := Basic.min(0.33 * Math.sqrt(-2 * Math.log(u1)), 1);
			theta  := Math.TAU * u2;

			// Generate the normal vector components
			vx := Basic.clamp(radius * Math.cos(theta), -0.99, 0.99);
			vz := Basic.clamp(radius * Math.sin(theta), -0.99, 0.99);
			d := 1.0 - vx * vx - vz * vz;
			vy := ifx d > 0 Math.sqrt(d);
			//Basic.print("r: %, vx: %, vz: %, vy: %, sqrt: %\n", radius, vx, vz, vy, 1.0 - vx * vx - vz * vz);

			value := 0.5 * Math.Vector3.{vx, vy, vz} + Math.Vector3.{0.5, 0.5, 0.5};
			setPixel(bitmap, x, y, value);
		}
	}
}

sand_ripples_state : struct {
	dune_field    : Dune_Simulator.DuneField;
	is_normal_map : bool;
}

sandRipples :: (bitmap: *Simp.Bitmap) {
	Dune_Simulator.setSize(*sand_ripples_state.dune_field, bitmap.width, bitmap.height);
	Dune_Simulator.randomize(*sand_ripples_state.dune_field, 0, 500);
	Dune_Simulator.toBitmap(*sand_ripples_state.dune_field, bitmap, sand_ripples_state.is_normal_map);
}

sandRipplesSimulateStep :: (bitmap: *Simp.Bitmap) {
	Dune_Simulator.step(*sand_ripples_state.dune_field);
	Dune_Simulator.toBitmap(*sand_ripples_state.dune_field, bitmap, sand_ripples_state.is_normal_map);
}

#scope_export

Generation_Type :: enum u32 {
	SAND_RIPPLES;
	RANDOM_NOISE;
	GAUSSIAN_NOISE;
}

init :: () {
	Random.random_seed(Basic.current_time_monotonic().low);
}

generate :: (generation_type: Generation_Type, bitmap: *Simp.Bitmap) {
	if generation_type == {
		case .RANDOM_NOISE;
			randomNoise(bitmap);
		case .GAUSSIAN_NOISE;
			gaussianNoise(bitmap);
		case .SAND_RIPPLES;
			sandRipples(bitmap);
	}
}

simulationStep :: (generation_type: Generation_Type, bitmap: *Simp.Bitmap) {
	if generation_type == {
		case .SAND_RIPPLES;
			sandRipplesSimulateStep(bitmap);
	}
}

setIsNormalMap :: (is_normal_map: bool) {
	sand_ripples_state.is_normal_map = is_normal_map;
}
