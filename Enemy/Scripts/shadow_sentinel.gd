extends Enemy

# Override die method to ensure proper cleanup
func die():
	# Call parent die method to ensure proper cleanup
	super.die()
