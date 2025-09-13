extends Node

# Test script to verify level unlocking functionality
# This script tests that completing a level properly unlocks the next level

var original_unlocked_levels: int
var level_completed_received: bool = false
var level_unlocked_received: bool = false
var unlocked_level_number: int = -1

func _ready():
	print("=== Level Unlock Test Started ===")
	
	# Save original state
	original_unlocked_levels = GameManager.level_manager.unlocked_levels
	print("Original unlocked levels: %d" % original_unlocked_levels)
	
	# Connect to signals
	GameManager.level_completed.connect(_on_level_completed)
	GameManager.level_unlocked.connect(_on_level_unlocked)
	
	# Test completing a level
	var test_level = 1
	print("Testing completion of level %d" % test_level)
	
	# Simulate level completion
	GameManager.level_manager.complete_level(test_level)
	
	# Wait a frame to allow signals to process
	await get_tree().process_frame
	
	# Check results
	if level_completed_received:
		print("✓ level_completed signal received")
	else:
		print("✗ level_completed signal NOT received")
		
	if level_unlocked_received:
		print("✓ level_unlocked signal received for level %d" % unlocked_level_number)
		if unlocked_level_number == test_level + 1:
			print("✓ Correct level unlocked (level %d)" % unlocked_level_number)
		else:
			print("✗ Incorrect level unlocked. Expected %d, got %d" % (test_level + 1, unlocked_level_number))
	else:
		print("✗ level_unlocked signal NOT received")
	
	# Check that unlocked_levels was updated
	var current_unlocked_levels = GameManager.level_manager.unlocked_levels
	if current_unlocked_levels > original_unlocked_levels:
		print("✓ unlocked_levels updated from %d to %d" % [original_unlocked_levels, current_unlocked_levels])
	else:
		print("✗ unlocked_levels NOT updated. Still at %d" % current_unlocked_levels)
	
	# Restore original state
	GameManager.level_manager.unlocked_levels = original_unlocked_levels
	print("Restored unlocked_levels to %d" % original_unlocked_levels)
	
	print("=== Level Unlock Test Completed ===")

func _on_level_completed(level_num: int):
	print("Received level_completed signal for level %d" % level_num)
	level_completed_received = true

func _on_level_unlocked(level_num: int):
	print("Received level_unlocked signal for level %d" % level_num)
	level_unlocked_received = true
	unlocked_level_number = level_num