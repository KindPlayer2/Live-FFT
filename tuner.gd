extends Node2D

# Standard guitar tuning frequencies for 6 strings (Low E to High E)
const STRING_FREQUENCIES = {
	"Low E": 82.41,
	"A": 110.00,
	"D": 159.83,
	"G": 185.00,
	"B": 279.94,
	"High E": 329.63
}

@onready var tune_label: Label = $Tune
@onready var Freq: Label = $Freq
@onready var audio_bus_index: int = AudioServer.get_bus_index("Record")

var current_selected_string: String = ""
var spectrum: AudioEffectSpectrumAnalyzerInstance

var isLE: bool = false
var isA: bool = false
var isD: bool = false
var isG: bool = false
var isB: bool = false
var isHE: bool = false

func _ready():
	# Connect buttons
	$Control/LowEButton.pressed.connect(func(): check_string_tuning("Low E"))
	$Control/AButton.pressed.connect(func(): check_string_tuning("A"))
	$Control/DButton.pressed.connect(func(): check_string_tuning("D"))
	$Control/GButton.pressed.connect(func(): check_string_tuning("G"))
	$Control/BButton.pressed.connect(func(): check_string_tuning("B"))
	$Control/HighEButton.pressed.connect(func(): check_string_tuning("High E"))
	
	# Initialize the spectrum analyzer.
	spectrum = AudioServer.get_bus_effect_instance(1, 1)
	
	# Resize and initialize arrays for frequency bands.
	min_values.resize(VU_COUNT)
	max_values.resize(VU_COUNT)
	min_values.fill(0.0)
	max_values.fill(0.0)

func _process(delta):
	# Array to store magnitudes for each frequency range.
	var spectrum_magnitudes: Array[float] = []
	var spectrum_freqs: Array[float] = []
	
	# Sample the entire spectrum using the audio effect spectrum analyzer
	var min_freq: float = 20.0  # Start from audible range
	var freq_range_max: float = FREQ_MAX
	var step: float = (freq_range_max - min_freq) / 100.0  # Sampling 100 points
	
	var max_raw_magnitude: float = 0.0
	var raw_max_freq: float = 0.0
	
	# Sample spectrum and find raw max frequency
	for i in range(100):
		var freq: float = min_freq + i * step
		var magnitude: float = spectrum.get_magnitude_for_frequency_range(freq, freq + step).length()
		
		spectrum_magnitudes.append(magnitude)
		spectrum_freqs.append(freq + step / 2.0)
		
		# Find raw max frequency
		if magnitude > max_raw_magnitude:
			max_raw_magnitude = magnitude
			raw_max_freq = freq + step / 2.0
	
	# Find max index for parabolic interpolation
	var max_index_para: int = 0
	for i in range(1, spectrum_magnitudes.size() - 1):
		if spectrum_magnitudes[i] > spectrum_magnitudes[max_index_para]:
			max_index_para = i
	
	# Parabolic interpolation
	var alpha: float = spectrum_magnitudes[max_index_para - 1]
	var beta: float = spectrum_magnitudes[max_index_para]
	var gamma: float = spectrum_magnitudes[max_index_para + 1]
	
	var peak_offset: float = 0.5 * (alpha - gamma) / (alpha - 2 * beta + gamma)
	var interpolated_freq: float = spectrum_freqs[max_index_para] + peak_offset * step
	
	# Ignore frequencies below the threshold
	if interpolated_freq < MIN_FREQ_THRESHOLD:
		interpolated_freq = MIN_FREQ_THRESHOLD
		raw_max_freq = MIN_FREQ_THRESHOLD
	
	# Array to store heights for each frequency band.
	var data: Array[float] = []
	var prev_hz: float = 0.0

	# Loop to calculate the magnitude for each frequency band.
	for i in range(1, VU_COUNT + 1):
		var hz: float = i * FREQ_MAX / VU_COUNT
		var magnitude: float = spectrum.get_magnitude_for_frequency_range(prev_hz, hz).length()
		var energy: float = clamp((MIN_DB + linear_to_db(magnitude)) / MIN_DB, 0, 1)
		var height: float = energy * HEIGHT * HEIGHT_SCALE
		data.append(height)
		prev_hz = hz

	# Update min and max values for each band.
	for i in range(VU_COUNT):
		if data[i] > max_values[i]:
			max_values[i] = data[i]
		else:
			max_values[i] = lerp(max_values[i], data[i], ANIMATION_SPEED)
		if data[i] <= 0.0:
			min_values[i] = lerp(min_values[i], 0.0, ANIMATION_SPEED)

	# Find the peak bar index for visualization
	max_index = 0
	for i in range(1, VU_COUNT - 1):
		if data[i] > data[max_index]:
			max_index = i

	# Detect the nearest guitar string
	var closest_string: String = ""
	var closest_diff: float = INF
	if interpolated_freq >= MIN_FREQ_THRESHOLD:
		for string_name in GUITAR_STRINGS.keys():
			var string_freq: float = GUITAR_STRINGS[string_name]
			var diff: float = abs(interpolated_freq - string_freq)
			if diff < closest_diff:
				closest_diff = diff
				closest_string = string_name
				
	Freq.text = "Frequency: " + str(interpolated_freq) + " Hz"
	if isLE:
		update_tuning_guidance(interpolated_freq)
	if isA:
		update_tuning_guidance(interpolated_freq)
	if isD:
		update_tuning_guidance(interpolated_freq)
	if isG:
		update_tuning_guidance(interpolated_freq)
	if isB:
		update_tuning_guidance(interpolated_freq)
	if isHE:
		update_tuning_guidance(interpolated_freq)
				
	# Redraw the visualization.
	queue_redraw()


func update_tuning_guidance(current_freq: float):
	var target_freq = STRING_FREQUENCIES[current_selected_string]
	var tolerance = 5.0  # Adjusted margin of error to 10 Hz
	
	if abs(current_freq - target_freq) <= tolerance:
		tune_label.text = "In Tune"
		tune_label.modulate = Color.GREEN
	elif current_freq < target_freq:
		tune_label.text = "Tune Up"
		tune_label.modulate = Color.YELLOW
	else:
		tune_label.text = "Tune Down"
		tune_label.modulate = Color.YELLOW

func check_string_tuning(string_name: String):
	current_selected_string = string_name
	tune_label.text = "Tuning " + string_name
	tune_label.modulate = Color.WHITE
	
	if string_name == "Low E":
		isLE = true
		isA = false
		isD = false
		isG = false
		isB = false
		isHE = false
	if string_name == "A":
		isLE = false
		isA = true
		isD = false
		isG = false
		isB = false
		isHE = false
	if string_name == "D":
		isLE = false
		isA = false
		isD = true
		isG = false
		isB = false
		isHE = false
	if string_name == "G":
		isLE = false
		isA = false
		isD = false
		isG = true
		isB = false
		isHE = false
	if string_name == "B":
		isLE = false
		isA = false
		isD = false
		isG = false
		isB = true
		isHE = false
	if string_name == "High E":
		isLE = false
		isA = false
		isD = false
		isG = false
		isB = false
		isHE = true

# Optional: Stop frequency analysis when no string is selected
func _on_no_string_selected():
	current_selected_string = ""
	tune_label.text = "Select a String"
	tune_label.modulate = Color.GRAY
	
# Constants
const VU_COUNT: int = 400               # Reduced the number of frequency bands to make the graph smaller.
const FREQ_MAX: float = 11050.0         # Maximum frequency range (in Hz).
const WIDTH: int = 400                  # Reduced width to make the graph smaller.
const HEIGHT: int = 150                 # Reduced height of the graph.
const HEIGHT_SCALE: float = 8.0         # Scale factor for the height of the bars (the magnitude).
const MIN_DB: float = 80.0              # Minimum decibel threshold for measurement.
const ANIMATION_SPEED: float = 0.15     # Speed of the animation transition for bars.
const MIN_FREQ_THRESHOLD: float = 80.0  # Minimum frequency to consider.

var min_values: Array[float] = []                  # Minimum values for each frequency band.
var max_values: Array[float] = []                  # Maximum values for each frequency band.
var max_index: int = 0                             # Index of the bar with the highest magnitude.

# Labels
var DbLabel: Label  # Display the highest Db value.
var FreqLabel: Label  # Display the frequency with the highest magnitude.
var StringLabel: Label  # Display the detected guitar string.
var RawFreqLabel: Label  # Display the raw (non-interpolated) frequency.
var ParabolicDiffLabel: Label  # Display the difference between parabolic and raw frequency.

# Guitar string frequencies (in Hz)
const GUITAR_STRINGS: Dictionary = {
	"low e": 82.41,
	"a": 110.00,
	"d": 156.83,
	"g": 186.00,
	"b": 280.94,
	"high e": 320.63
}

func _draw() -> void:
	# Calculate the width of each bar.
	var w: float = WIDTH / VU_COUNT
	
	# Loop through all frequency bands (bars).
	for i in range(VU_COUNT):
		# Interpolated height for animation.
		var height: float = lerp(min_values[i], max_values[i], ANIMATION_SPEED)
		
		# Determine the color of the bar.
		var color: Color = Color.BLUE if i == max_index else Color.RED
		
		# Draw the main frequency bar at bottom-left corner.
		draw_rect(
			Rect2(w * i, HEIGHT - height + 50, w - 2, height),  # Adjusted Y-position to appear at bottom-left.
			color  # Color of the bar.
		)

		# Draw the top border of the bar for visualization enhancement.
		draw_line(
			Vector2(w * i, HEIGHT - height + 50),
			Vector2(w * i + w - 2, HEIGHT - height + 50),
			color,  # Border color matches the bar.
			1.0,
			true
		)
