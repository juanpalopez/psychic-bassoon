## Which touch is the emulated mouse and which are extra fingers, whatever indexes
## the browser hands out (Safari's do not start at 0).
extends GutTest


func test_the_first_finger_is_the_mouse_whatever_its_index() -> void:
	for index in [0, 1, 7, 4242]:
		var fingers := TouchFingers.new()
		assert_eq(fingers.press(index), TouchFingers.MOUSE, "index %d" % index)
		assert_eq(fingers.pointer_of(index), TouchFingers.MOUSE)


func test_a_second_finger_gets_its_own_pointer_even_with_the_lower_index() -> void:
	var fingers := TouchFingers.new()
	fingers.press(9)
	var second := fingers.press(0)
	assert_gte(second, 1, "the second finger is not the mouse")
	assert_eq(fingers.pointer_of(0), second)
	assert_eq(fingers.pointer_of(9), TouchFingers.MOUSE)


func test_a_third_finger_gets_another_pointer() -> void:
	var fingers := TouchFingers.new()
	fingers.press(3)
	var second := fingers.press(5)
	var third := fingers.press(6)
	assert_ne(second, third)
	assert_gte(third, 1)


func test_pressing_a_known_finger_again_changes_nothing() -> void:
	var fingers := TouchFingers.new()
	fingers.press(7)
	var second := fingers.press(8)
	assert_eq(fingers.press(7), TouchFingers.MOUSE)
	assert_eq(fingers.press(8), second)


func test_the_mouse_finger_lifting_hands_the_mouse_to_the_next_new_finger() -> void:
	# like the engine: the next finger to go down while no finger is the mouse is it
	var fingers := TouchFingers.new()
	fingers.press(1)
	var second := fingers.press(2)
	assert_eq(fingers.release(1), TouchFingers.MOUSE)
	assert_eq(fingers.pointer_of(2), second, "the second finger keeps its pointer")
	assert_eq(fingers.press(3), TouchFingers.MOUSE)


func test_releasing_a_finger_frees_its_pointer_and_an_unknown_one_is_ignored() -> void:
	var fingers := TouchFingers.new()
	fingers.press(1)
	var second := fingers.press(2)
	assert_eq(fingers.release(2), second)
	assert_eq(fingers.press(5), second, "the freed pointer is used again")
	assert_eq(fingers.release(99), TouchFingers.MOUSE, "a finger it never saw is not an extra one")


func test_reset_forgets_every_finger() -> void:
	var fingers := TouchFingers.new()
	fingers.press(4)
	fingers.press(5)
	fingers.reset()
	assert_eq(fingers.press(8), TouchFingers.MOUSE)
