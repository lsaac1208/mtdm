class_name LevelData
extends RefCounted
## Active-chapter facade. Route data lives in scripts/level/chapters/*.gd;
## every caller keeps reading LevelData.ZONES, LevelData.ENCOUNTERS, ... and
## gets the chapter selected with use_chapter(). Chapter 1 is the default.

const CHAPTERS := {
	"ch1": preload("res://scripts/level/chapters/chapter1.gd"),
}

static var CHAPTER := "ch1"
static var LENGTH: float
static var ZONES: Array
static var GROUND: Array
static var PLATFORMS: Array
static var POOLS: Array
static var CHECKPOINTS: Array
static var SIGNS: Array
static var LORE: Array
static var DESTRUCTIBLES: Array
static var ENCOUNTERS: Array
static var END_X: float
static var WHISPERS: Dictionary


static func _static_init() -> void:
	use_chapter("ch1")


## Switch the active route data. Returns false for an unknown chapter id.
static func use_chapter(id: String) -> bool:
	if not CHAPTERS.has(id):
		return false
	var c = CHAPTERS[id]
	CHAPTER = id
	LENGTH = c.LENGTH
	ZONES = c.ZONES
	GROUND = c.GROUND
	PLATFORMS = c.PLATFORMS
	POOLS = c.POOLS
	CHECKPOINTS = c.CHECKPOINTS
	SIGNS = c.SIGNS
	LORE = c.LORE
	DESTRUCTIBLES = c.DESTRUCTIBLES
	ENCOUNTERS = c.ENCOUNTERS
	END_X = c.END_X
	WHISPERS = c.WHISPERS
	return true
