# This class contains the methods needed to manipulate counters in a game
#
# It is meant to be extended and attached to a customized scene.
#
# In the extended script, the various values should be filled during
# the _ready() method
class_name Counters
extends Control

# Hold the actual values of the various counters requested
var counters := {}
# Holds the label nodes which display the counter values to the user
var _labels := {}
# Each entry in this dictionary will specify one counter to be added
# The key will be the name of the node holding the counter
# The value is a dictionary where each key is a label node path relative
# to the counter_scene
# and each value, is the text value for the label
var needed_counters: Dictionary
# This hold modifiers to counters that will be only active temporarily.
#
# Typically only used during
# an [execute_scripts()](ScriptingEngine#execute_scripts] task.
#
# Each key is a ScriptingEngine reference, and each value is a dictionary
# with a counter and its modifiers.
# This means multiple modifiers may be active at the same time.
var temp_count_modifiers := {}

# Holds the counter scene which has been created by the developer
export(PackedScene) var counter_scene

# This variable should hold the path to the Control container
# Which will hold the counter objects.
#
# It should be set in the _ready() function of the script which extends this class
var counters_container : Container
# This variable should hold which needed_counters dictionary key is the path
# to the label which holds the values for the counter
#
# It should be set in the _ready() function of the script which extends this class
var value_node: String


func _ready() -> void:
	pass


# This function should be called by the _ready() function of the script which
# extends thic class, after it has set all the necessary variables.
#
# It creates and initiates all the necessary counters required by this game.
func spawn_needed_counters() -> void:
	for counter_name in needed_counters:
		var counter = counter_scene.instance()
		counter.name = counter_name
		var counter_labels = needed_counters[counter_name]
		for label in counter_labels:
			counter.get_node(label).text = str(counter_labels[label])
			# The value_node is also used determine the initial values
			# of the counters dictionary
			if label == value_node:
				counters[counter_name] = counter_labels[label]
				# _labels stores the label node which displays the value
				# of the counter
				_labels[counter_name] = counter.get_node(label)
		counters_container.add_child(counter)


# Modifies the value of a counter. The counter has to have been specified
# in the `needed_counters`
#
# * Returns CFConst.ReturnCode.CHANGED if a modification happened
# * Returns CFConst.ReturnCode.OK if the modification requested is already the case
# * Returns CFConst.ReturnCode.FAILED if for any reason the modification cannot happen
#
# If check is true, no changes will be made, but will return
# the appropriate return code, according to what would have happened
#
# If set_to_mod is true, then the counter will be set to exactly the value
# requested. otherwise the value will be modified from the current value
func mod_counter(counter_name: String,
		value: int,
		set_to_mod := false,
		check := false) -> int:
	var retcode = CFConst.ReturnCode.CHANGED
	if counters.get(counter_name, null) == null:
		retcode = CFConst.ReturnCode.FAILED
	else:
		if set_to_mod and counters[counter_name] == value:
			retcode = CFConst.ReturnCode.OK
		elif set_to_mod and counters[counter_name] < 0:
			retcode = CFConst.ReturnCode.FAILED
		else:
			if counters[counter_name] + value < 0:
				retcode = CFConst.ReturnCode.FAILED
				value = -counters[counter_name]
			if not check:
				if set_to_mod:
					counters[counter_name] = value
				else:
					counters[counter_name] += value
				_labels[counter_name].text = str(counters[counter_name])
	return(retcode)


# Returns the value of the specified counter.
# Takes into account temp_count_modifiers and alterants
func get_counter(counter_name: String, requesting_card: Card = null) -> int:
	var count = get_counter_and_alterants(counter_name, requesting_card).count
	return(count)


# Discovers the modified value of the specified counter based
# on temp_count_modifiers and alterants.
#
# Returns a dictionary with the following keys:
# * count: The final value of this counter after all modifications
# * alteration: The full dictionary returned by
#	CFScriptUtils.get_altered_value() but including details about
#	temp_count_modifiers
func get_counter_and_alterants(
		counter_name: String,
		requesting_card: Card = null) -> Dictionary:
	var count = counters[counter_name]
	# We iterate through the values, where each value is a dictionary
	# with key being the counter name, and value being the temp modifier
	for modifier in temp_count_modifiers.values():
		count += modifier.get(counter_name,0)
	var alteration = {
		"value_alteration": 0,
		"alterants_details": {"counter_name": counter_name}
	}
	if requesting_card:
		alteration = CFScriptUtils.get_altered_value(
			requesting_card,
			"get_counter",
			{SP.KEY_COUNTER_NAME: counter_name,},
			counters[counter_name])
		if alteration is GDScriptFunctionState:
			alteration = yield(alteration, "completed")
	# The first element is always the total modifier from all alterants
	count += alteration.value_alteration
	if count < 0:
		count = 0
	var return_dict = {
		"count": count,
		"alteration": alteration
	}
	return(return_dict)

