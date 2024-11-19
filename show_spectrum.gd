extends Node2D

# Constants
const VU_COUNT = 800               # Number of frequency bands (bars) to display.
const FREQ_MAX = 11050.0          # Maximum frequency range (in Hz), set to 11050 Hz, which is above the range of human hearing.

const WIDTH = 800                 # Width of the visualization (in pixels).
const HEIGHT = 250                # Height of the visualization (in pixels).
const HEIGHT_SCALE = 8.0          # Scale factor for the height of the bars (the magnitude).
const MIN_DB = 80                 # Minimum decibel threshold for measurement (to avoid negative values).
const ANIMATION_SPEED = 0.15       # Speed of the animation transition when bars change height.

# Variables
var spectrum: AudioEffectSpectrumAnalyzerInstance  # Instance of the spectrum analyzer to fetch audio frequency data.

var min_values: Array[float] = []                   # Array to store the minimum height of each frequency band.
var max_values: Array[float] = []                   # Array to store the maximum height of each frequency band.

# References to the labels in the scene
var DbLabel: Label  # Label to display the current highest Db value.
var FreqLabel: Label  # Label to display the current highest frequency.

# The _draw function is called every frame to draw the visualization.
func _draw() -> void:
	# Prevents a warning about integer division in this context.
	@warning_ignore("integer_division")
	
	# Calculate the width of each "bar" based on the total width and the number of bars.
	var w := WIDTH / VU_COUNT

	# Loop through all frequency bands (bars).
	for i in VU_COUNT:
		# Get the minimum and maximum height for the current frequency band.
		var min_height = min_values[i]
		var max_height = max_values[i]
		
		# Interpolate between min and max height for smooth animation of bars.
		var height = lerp(min_height, max_height, ANIMATION_SPEED)

		# Draw the main frequency bar.
		draw_rect(
				Rect2(w * i, HEIGHT - height, w - 2, height),  # Position and size of the bar.
				Color.RED  # Color for the bar (calculated per band).
		)

		# Draw the top border of the bar to enhance the visualization.
		draw_line(
				Vector2(w * i, HEIGHT - height),  # Start point (left side of the bar).
				Vector2(w * i + w - 2, HEIGHT - height),  # End point (right side of the bar).
				Color.RED,  # Color for the border (brighter).
				1.0,  # Line thickness.
				true   # Smooth line (antialiasing).
		)

# The _process function is called every frame and handles audio data processing.
func _process(_delta: float) -> void:
	# Create an empty array to store the calculated heights of each frequency band.
	var data: Array[float] = []
	print(AudioServer.get_bus_effect_instance(1, 1))
	# Previous frequency value used for frequency range calculation.
	var prev_hz := 0.0

	# Loop through each frequency band to calculate its magnitude.
	for i in range(1, VU_COUNT + 1):
		# Calculate the frequency range for the current band.
		var hz := i * FREQ_MAX / VU_COUNT

		# Get the magnitude (energy) for the current frequency range from the spectrum analyzer.
		var magnitude := spectrum.get_magnitude_for_frequency_range(prev_hz, hz).length()

		# Convert the magnitude to energy in decibels and normalize it.
		var energy := clampf((MIN_DB + linear_to_db(magnitude)) / MIN_DB, 0, 1)

		# Calculate the height of the frequency band based on the energy.
		var height := energy * HEIGHT * HEIGHT_SCALE
		data.append(height)  # Add the height to the data array.
		
		# Set the previous frequency for the next iteration.
		prev_hz = hz

	# After processing, update the max and min values for each frequency band.
	for i in VU_COUNT:
		if data[i] > max_values[i]:
			max_values[i] = data[i]
		else:
			max_values[i] = lerpf(max_values[i], data[i], ANIMATION_SPEED)

		if data[i] <= 0.0:
			min_values[i] = lerpf(min_values[i], 0.0, ANIMATION_SPEED)

	# Find the highest Db value and its corresponding frequency
	var max_db = -80
	var max_index = -1

	for i in range(VU_COUNT):
		if data[i] > max_db:
			max_db = data[i]
			max_index = i

	# Calculate the frequency corresponding to the highest Db value
	var max_freq = max_index * FREQ_MAX / VU_COUNT

	# Update the DbLabel and FreqLabel with the values
	DbLabel.text = "Db: " + str(linear_to_db(max_db))
	FreqLabel.text = "The current Maximum Frequency: " + str(max_freq) + " Hz"

	# Continuously redraw the graph, since sound plays back continuously.
	queue_redraw()

# The _ready function is called when the node is ready.
func _ready() -> void:
	# Initialize the spectrum analyzer to fetch audio data.
	spectrum = AudioServer.get_bus_effect_instance(1, 1)
	
	# Resize the min and max value arrays to match the number of frequency bands.
	min_values.resize(VU_COUNT)
	max_values.resize(VU_COUNT)

	# Fill the min and max arrays with initial values (0.0).
	min_values.fill(0.0)
	max_values.fill(0.0)

	# Get references to the labels in the scene
	DbLabel = $DbLabel  # Assuming your Db Label node is named "DbLabel".
	FreqLabel = $FreqLabel  # Assuming your Freq Label node is named "FreqLabel".
