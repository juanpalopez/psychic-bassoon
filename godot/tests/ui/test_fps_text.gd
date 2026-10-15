## The line the fps overlay shows.
extends GutTest


func test_it_shows_fps_draw_calls_foes_and_thousands_of_triangles() -> void:
	assert_eq(FpsText.format(60, 87, 80, 123456), "60 fps  87 draws  80 foes  123k tris")


func test_small_numbers_and_zero_read_fine() -> void:
	assert_eq(FpsText.format(0, 0, 0, 0), "0 fps  0 draws  0 foes  0k tris")
	assert_eq(FpsText.format(30, 5, 1, 999), "30 fps  5 draws  1 foes  0k tris")
