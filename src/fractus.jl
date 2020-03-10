
#------------------------------#
# Complex Math + Escape Timing #
#------------------------------#

# Creates a 2d grid of complex numbers from the given
# origin, width, and height. The resw and resh parameters
# determine the density of the mesh.
imRange(bl, w, h, resw, resh) = (x + y*1im for
	x in range(bl.re, bl.re + w, length = resw),
	y in range(bl.im, bl.im + h, length = resh))

# Basic point smoothing. Uses the absolute value of the point
# to help give it a less integer-y escape time. Also points
# far enough apart get different colors even if they escape
# at the same time.
#
# This creates beautiful images, but obfuscates the pattern
# of escape iterations somewhat.
smoothEscape(iters, z) = iters + log(abs(z))

# Creates an escape time function when given the right
# configuration. Then just map your numbers through it.
escapeTimeWith(func, iters, smooth = (e, c) -> e) = c -> begin
	z = 0
	for i in 1:iters
		z = func(z, c)
		if abs2(z) >= 4 return smooth(i, c) end
	end
	return iters
end

# See above. This is the easy part...
calculateEscapeTime(points, func, iters, smooth = (e, c) -> e) = begin
   	points .|> escapeTimeWith(func, iters, smooth)
end

#----------#
# Coloring #
#----------#

import Images

# The most basic of coloring functions...
monocolor(iters) = n -> (n == iters
	? Images.RGBA(0, 0, 0, 1)  # It's captured. Black it is.
	: Images.RGBA(1, 1, 1, 1)) # It escaped! Color it white.

# A version which accepts a function to color
# escaped points only. Captured points are black.
capturedToBlack(escapeColorFunc) = iters -> n -> (n == iters
	? Images.RGBA(0, 0, 0, 1)
	: Images.RGBA((escapeColorFunc(n) .|> Images.clamp01nan)...))

# Setup for a phased color loop, a not very descriptive name
# for a color scheme that uses various sin functions to map
# into the unit range.

# For each RGB channel, we need a frequency, phase, and minimum
# (in the unit range).
# We need one such set for channel, so we require a dict, with
# keys R, G, and B, which map to a 3 tuple.
phasedColorLoop(config) = begin
    snr = (f, p, m) -> n -> sin(f*n + p)*0.5*(1 - m) + 1 + m
    f = n -> [snr(config["R"]...)(n) snr(config["B"]...)(n) snr(config["G"]...)(n) 1]
    capturedToBlack(f)
end

BASIC_PCL = Dict(
	"R" => (0.016, 4, 0.1),
	"G" => (0.13, 2, 0.1),
	"B" => (0.01, 1, 0.1)
)

#-------------------------------#
# Main Function + Configuration #
#-------------------------------#

BASIC_FCONFIG = Dict(
	"bl" => -3 -1im,
	"w" => 4,
	"h" => 2,

	"resw" => 1400,
	"resh" => 700,

	"iters" => 1000,
	"func" => (z, c) -> z^2 + c,

	"color" => phasedColorLoop(BASIC_PCL),
	"path" => "fractal.png",
)

TEST_FCONFIG = Dict(
	"bl" => -0.49054109031733145 + 0.5296658986175117im,
	"w" => 0.25,
	"h" => 0.125,

	"resw" => 800,
	"resh" => 400,

	"iters" => 1000,
	"func" => (z, c) -> z^2 + c,

	"color" => phasedColorLoop(BASIC_PCL),
	"path" => "test.png",
)

# Creates and saves an image representing the fractal constructed
# using the supplied configuraton.
fractus(config) = (imRange(config["bl"], config["w"], config["h"], config["resw"], config["resh"])
	|> grid -> calculateEscapeTime(grid, config["func"], config["iters"])
	.|> config["color"](config["iters"])
	|> transpose
	|> frac -> reverse(frac, dims=1)
	|> frac -> Images.save(config["path"], frac))

# For testing, if you like:
# fractus(TEST_FCONFIG)

#---------------------#
# Web Server (Woah!!) #
#---------------------#

import Genie

# This endpoint should generate a new fractal
# image based on the given JSON. It should look like:
#   "bl": [number, number]
#   "dim" [number, number]
#	"res": [number, number]
#   "iters": number
# all optional, using values from the base config when ommited.
#
# Ideally support more in the future so we can change
# the color and iteration functions as well.
# And for gods sake at least make this part of the code
# somewhat error resistant.
Genie.Router.route("/generate", method = "POST") do
	json = Genie.Requests.jsonpayload()
	config = BASIC_FCONFIG

	if haskey(json, "bl")
		config["bl"] = json["bl"][1] + json["bl"][2]*1im
	end
	if haskey(json, "dim")
		config["w"] = json["dim"][1]
		config["h"] = json["dim"][2]
	end
	if haskey(json, "res")
		config["resw"] = json["res"][1]
		config["resh"] = json["res"][2]
	end
	if haskey(json, "iters")
		config["iters"] = json["iters"]
	end

	fractus(config)
	Genie.Renderer.Json.json(Dict(
		"success" => true,
	))
end

Genie.up()
