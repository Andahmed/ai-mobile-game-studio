current_planet):
		current_planet.occupied = false

	current_state = State.FLYING
	var tangent_angle: float = orbit_angle + (PI / 2.0) * orbit_direction
	velocity = Vector2(cos(tangent_angle), sin(tangent_angle)) * launch_speed
	rotation = tangent_angle + PI / 2.0
	current_planet = null
	launched.emit()
```
Wait! What happens when the player presses tap to launch from Planet 2?
Wait, if `area_entered` triggered when entering Planet 2:
Did `area_exited` happen? No, the player was orbiting inside Planet 2.
Wait,