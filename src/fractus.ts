

const container = document.getElementById("easel") as HTMLDivElement;
const draw_area = document.getElementById("drawarea") as HTMLCanvasElement;
const ctx = draw_area.getContext("2d")!;

draw_area.width = container.offsetWidth;
draw_area.height = container.offsetHeight;

//-----------------\\
// Color Functions \\
//-----------------\\

// RGBA, n ∈ ℤ, in [0, 255].
type color = [number, number, number, number];
type ColorFunc = (iters: number, c: complex) => color;

function smoothIters(iters: number, z: complex): number {
	 return iters + 1 - Math.log(2)/cAbs(z) / Math.log(2);
}

// Frequency, phase, and a minimum value if applicable.
type PCLChannelParams = [number, number, number?];
type PCLParams = [PCLChannelParams, PCLChannelParams, PCLChannelParams];

function makePhasedColorLoop(params: PCLParams): ColorFunc {
	return (i, z) => {
		let si = smoothIters(i, z);
		let colors = Array(3)
			.fill(si)
			.map((si, chan) => {
				let [f, p, min = 0] = params[chan];
				return Math.sin(f*si + p)*(255 - min) + min;
			});

		return [...colors, 255] as color;
	}
}

//channel colour = sin(frequency * continuous_index + phase) * 127.5 + 127.5)

const color_funcs = {
	// All escape points are white.
	whiteEscape() {
		return [255, 255, 255, 255];
	},

	// A demo phased color loop:
	pcl: makePhasedColorLoop([
		[0.016, 4, 25],
		[0.13, 2, 25],
		[0.01, 1, 25],
	]),
}

//-------------------------------\\
// Canvas <-> Complex Conversion \\
//-------------------------------\\

// pixel coord uses a top-left origin
// complex tile uses a bottom left origin

function pxCoord2Index(coord: [number, number]): number {
	let [x, y] = coord;
	return 4*(y*draw_area.width + x);
}

function pxIndex2Coord(index: number): [number, number] {
	let n = index / 4;
	let x = n % draw_area.width;
	return [x, (n - x) / draw_area.width];
}

function pxCoord2CompTile(pxcoord: [number, number]): complex {
	let [px, py] = pxcoord;
	return [px , py + draw_area.height]
}

function compTile2PxCoord(tile: complex): [number, number] {
	let [tx, ty] = tile;
	return [tx, ty - draw_area.height];
}

// The inverse of this function will not be needed.
function tile2Comp(tile: complex): complex {
	let [tx, ty] = tile;
	return [
		frac_params.br[0] + (frac_params.vw/draw_area.width)*tx,
		frac_params.br[1] + (frac_params.vh/draw_area.height)*ty,
	];
}

function pixelIndexToComp(index: number): complex {
	return tile2Comp(pxCoord2CompTile(pxIndex2Coord(index)));
}

//---------------\\
// Main Function \\
//---------------\\

interface FracalParams {
	vw: number;
	vh: number;
	br: complex; // Bottom left of the view area.

	max_iters: number;
	iterFunc: (z: [number, number], c: [number, number]) => [number, number];

	colorFunc: (iters: number, c: complex) => color;
}

// This is expected to mutate.
const frac_params: FracalParams = {
	vw: 4,
	vh: 2,
	br: [-3, -3],

	max_iters: 1000,

	iterFunc: (z, c) => cAdd(cMult(z, z), c),
	colorFunc: color_funcs.pcl,
};

function genFractal(): void {
	const imgdata = ctx.getImageData(0, 0, draw_area.width, draw_area.height)!;
	const setPixelColor = (index: number, color: color) => {
		color.forEach(c => imgdata.data[index++] = c);
	}

	for (let pxi = 0; pxi < imgdata.data.length; pxi += 4) {
		const c = pixelIndexToComp(pxi);
		let z = [0, 0] as complex;

		let tally = 0;
		for (; tally < frac_params.max_iters; tally++) {
			if (cAbs2(z) > 4) break;
			z = frac_params.iterFunc(z, c);
		}

		if (tally === frac_params.max_iters) {
			setPixelColor(pxi, [0, 0, 0, 255]);
		} else {
			setPixelColor(pxi, frac_params.colorFunc(tally, c));
		}

	}

	ctx.putImageData(imgdata, 0, 0);
}

genFractal();

//-----------------\\
// Everything Else \\
//-----------------\\

/**
 * Complex number operators and other math.
 */

type complex = [number, number];

function cAdd(z1: complex, z2: complex): complex {
	return [
		z1[0] + z2[0],
		z1[1] + z2[1],
	];
}

function cMult(z1: complex, z2: complex): complex {
	return [
		z1[0]*z2[0] - z1[1]*z2[1],
		z1[0]*z2[1] + z1[1]*z2[0],
	];
}

function cAbs2(z: complex): number {
	return z[0]**2 + z[1]**2;
}

function cAbs(z: complex): number {
	return Math.sqrt(cAbs2(z));
}

// function cConj(z: complex): complex {
// 	return [z[0], -z[1]];
// }
