#scope_file

Math   :: #import "Math";
Basic  :: #import "Basic";
Random :: #import "Random";
Simp   :: #import "Simp";

Array2d :: #import,file "array2d.jai";

operator+ :: Math.operator+;
operator- :: Math.operator-;
operator* :: Math.operator*;
operator/ :: Math.operator/;

#scope_export

SHADOW_SLOPE :: 2.9; // 0.80384757; // == 3 * tan(15 / 180 * pi)

DI_MOORE_DOWN :: int.[1,  0,  0,  1,  1];
DJ_MOORE_DOWN :: int.[ 0,  1, -1, -1,  1];
DI_MOORE_UP   :: int.[-1,  0,  0, -1, -1];
DJ_MOORE_UP   :: int.[ 0,  1, -1, -1,  1];

DuneField :: struct {
	width         : int;
	height        : int;
	shadow_slope := SHADOW_SLOPE;

	// Hop length
	hop_length : int = 2;

	// Probability of sand slab deposit on bare ground
	prob_deposit_bare : float = 1;

	// Probability of sand slab deposit on sandy ground
	prob_deposit_sand : float = 0.3;

	// Number of sand slabs
	h : Array2d.Array2d;

	// Define wether a cell is in the shadow (1) or not (0) of other cells
	shadow : Array2d.Array2d;

	// Random seed number
	seed : u32 = 1;

	di_down := DI_MOORE_DOWN;
	dj_down := DJ_MOORE_DOWN;
	di_up   := DI_MOORE_UP;
	dj_up   := DJ_MOORE_UP;
}

// Set the dunefield shape.
setSize :: (this: *DuneField, width: int, height: int) {
	this.width  = width;
	this.height = height;
	Array2d.setSize(*this.h, width, height);
	Array2d.setSize(*this.shadow, width, height);
}

dis :: () -> float {
	return Random.random_get_zero_to_one();
}

disIJ :: () -> int {
	return cast(int) Random.random_get_within_range(0.0, 10.0); // this.width - 1; what is it?
}

// Perform one simulation step
step :: (this: *DuneField) {
	for i: 0 .. this.width - 1 for j: 0 .. this.height - 1 {
		// Shuffle cell indices to avoid artifacts
		i = (i + disIJ()) % this.width;
		j = (j + disIJ()) % this.height;

		if Array2d.get(this.h, i, j) > 0 && Array2d.get(this.shadow, i, j) == 0 {
			// Remove slab from initial cell
			deposeAt(this, i, j, -1, this.di_up, this.dj_up);

			// Keep moving the cell downwind by 'hop_length' jumps until it deposits
			keep_hopping := true;
			ic           := i;

			while keep_hopping {
				ic = (ic + this.hop_length) % this.width;

				if Array2d.get(this.shadow, ic, j) == 1 {
					deposeAt(this, ic, j, 1, this.di_down, this.dj_down);
					keep_hopping = false;
				} else {
					rd := dis();
					if (
						(Array2d.get(this.h, ic, j) == 0 && rd < this.prob_deposit_bare)
						|| rd < this.prob_deposit_sand
					) {
						deposeAt(this, ic, j, 1, this.di_down, this.dj_down);
						keep_hopping = false;
					}
				}
			}
		}
	}
}

/**
* Depose/erode one sand slab at location i, j
*
* @param i Index.
* @param j Index.
* @param amount +- 1
* @param di Avalanching coefficients for neighbor search.
* @param dj Avalanching coefficients for neighbor search.
*/
deposeAt :: (this: *DuneField, i: int, j: int, amount: int, di: [5]int, dj: [5]int) {
	p := i;
	q := j;

	for k: 0 .. di.count - 1 {
		in := (i + di[k] + this.width) % this.width;
		jn := (j + dj[k] + this.height) % this.height;

		if amount * (Array2d.get(this.h, i, j) - Array2d.get(this.h, in, jn)) > 2 {
			p = in;
			q = jn;
			break;
		}
	}
	Array2d.set(*this.h, p, q, Basic.max(0, Array2d.get(this.h, p, q) + amount));

	updateShadow(this, p, q);
}

// Update shadow field
updateShadow :: (this: *DuneField) {
	kmax := 2 + cast(int)(cast(float) Array2d.max(*this.h) / this.shadow_slope);
	for i: 0 .. this.width - 1 for j: 0 .. this.height - 1 {
		Array2d.set(*this.shadow, i, j, 0);
		slope := this.shadow_slope;
		k     := 1;
		dh    := -1.0;

		// Look for a cell upstream that would cast a shadow over the current cell
		while k < kmax && dh <= 0.0 {
			k_shifted := (i - k + this.width) % this.width;
			dh         = cast(float) (Array2d.get(this.h, k_shifted, j) - Array2d.get(this.h, i, j) - slope);
			slope     += this.shadow_slope;
			k         += 1;
		}

		if dh > 0.0 Array2d.set(*this.shadow, i, j, 1);
	}
}

updateShadow :: (this: *DuneField, i: int, j: int) {
	kmax := 2;
	imax := 2 + Array2d.get(this.h, i, j);

	for p: -imax .. imax - 1 {
		ir    := (i + p + this.width) % this.width;
		slope := this.shadow_slope;
		k     := 1;
		dh    := -1.0;

		while k < kmax && dh <= 0.0 {
			k_shifted := (ir - k + this.width) % this.width;
			dh         = cast(float) (Array2d.get(this.h, k_shifted, j) - Array2d.get(this.h, ir, j) - slope);
			slope     += this.shadow_slope;
			k         += 1;
		}

		if dh > 0.0 {
			Array2d.set(*this.shadow, ir, j, 1);
		} else {
			Array2d.set(*this.shadow, ir, j, 0);
		}
	}
}

randomize :: (this: *DuneField, h_min: int, h_max: int) {
	Array2d.randomize(*this.h, h_min, h_max);
	updateShadow(this);
}

cross :: (a: Math.Vector3, b: Math.Vector3, c: Math.Vector3) -> Math.Vector3 {
	return Math.cross(b - a, c - a);
}

toBitmap :: (this: *DuneField, bitmap: *Simp.Bitmap, is_normal_map: bool) {
	bpp := Simp.get_image_bytes_per_texel(bitmap.format);
	channels: int;
	if bitmap.format == {
		case .R8;    channels = 1;
		case .RG8;   channels = 2;
		case .RGB8;  channels = 3;
		case .RGBA8; channels = 4;
	}
	max := cast(float) Array2d.max(*this.h);
	if is_normal_map {
		/*
		11 21 31
		+--+--+
		|\ | /|
		| \|/ |
		+--+--+
		12 22 32
		| /|\ |
		|/ | \|
		+--+--+
		13 23 33
		*/
		for y: 0 .. bitmap.height - 1 {
			for x: 0 .. bitmap.width - 1 {
				j := 1;
				v11 := Math.Vector3.{xx -j, xx -j, xx Array2d.getWrap(this.h, x - j, y - j)};
				v21 := Math.Vector3.{    0, xx -j, xx Array2d.getWrap(this.h, x,     y - j)};
				v31 := Math.Vector3.{xx  j, xx -j, xx Array2d.getWrap(this.h, x + j, y - j)};

				v12 := Math.Vector3.{xx -j, 0, xx Array2d.getWrap(this.h, x - j, y)};
				v22 := Math.Vector3.{    0, 0, xx Array2d.getWrap(this.h, x,     y)};
				v32 := Math.Vector3.{xx  j, 0, xx Array2d.getWrap(this.h, x + j, y)};

				v13 := Math.Vector3.{xx -j, xx j, xx Array2d.getWrap(this.h, x - j, y + j)};
				v23 := Math.Vector3.{ 0,    xx j, xx Array2d.getWrap(this.h, x,     y + j)};
				v33 := Math.Vector3.{xx j,  xx j, xx Array2d.getWrap(this.h, x + j, y + j)};

				sum: Math.Vector3;

				sum += cross(v22, v12, v11);
				sum += cross(v22, v11, v21);
				sum += cross(v22, v21, v31);
				sum += cross(v22, v31, v32);

				sum += cross(v22, v13, v12);
				sum += cross(v22, v23, v13);
				sum += cross(v22, v33, v23);
				sum += cross(v22, v32, v33);

				normal := Math.normalize(sum);
				normal.y, normal.z = normal.z, normal.y; // Y is up.
				v := 0.5 * normal + Math.Vector3.{0.5, 0.5, 0.5};

				index := bpp * (x + y * bitmap.width);
				for i: 0 .. Basic.min(channels - 1, 2) {
					bitmap.data[index + i] = cast(u8) (255 * v.component[i]);
				}
				if channels == 4 {
					bitmap.data[index + 3] = 255;
				}
			}
		}
	} else {
		for y: 0 .. bitmap.height - 1 {
			for x: 0 .. bitmap.width - 1 {
				index := bpp * (x + y * bitmap.width);
				for i: 0 .. channels - 1 {
					bitmap.data[index + i] = cast(u8) (255 * Array2d.get(this.h, x, y) / max);
				}
				if channels == 4 {
					bitmap.data[index + 3] = 255;
				}
			}
		}
	}
}
