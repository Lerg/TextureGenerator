#scope_file

Basic  :: #import "Basic";
Random :: #import "Random";

#scope_export

Array2d :: struct {
	width  : int = 0;
	height : int = 0;
	array  : [..]int;
}

setSize :: (array: *Array2d, width: int, height: int) {
	array.width  = width;
	array.height = height;
	Basic.array_resize(*array.array, width * height);
}

set :: (array: *Array2d, x: int, y: int, value: int) {
	array.array[x + y * array.width] = value;
}

get :: (array: Array2d, x: int, y: int) -> int {
	return array.array[x + y * array.width];
}

getWrap :: (array: Array2d, x: int, y: int) -> int {
	xw := ifx x < 0 then (array.width + x) else (x % array.width);
	yw := ifx y < 0 then (array.height + y) else (y % array.height);
	return array.array[xw + yw * array.width];
}

max :: (array: Array2d) -> int {
	m : int = 0;
	for v: array.array {
		if v > m m = v;
	}
	return m;
}

randomize :: (array: *Array2d, v_min: int, v_max: int) {
	v_minf := cast(float) v_min;
	v_maxf := cast(float) v_max;
	for i: 0 .. array.array.count - 1 {
		array.array[i] = cast(int) (Random.random_get_within_range(v_minf, v_maxf) + 0.5);
	}
}
