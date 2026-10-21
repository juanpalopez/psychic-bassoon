## The six section generators, in road order (`ValleyPlan.Id`). A real section replaces its
## stand-in by changing its own class; this list never changes.
class_name ValleySections
extends RefCounted


static func all() -> Array[ValleySection]:
	return [
		OuterMarch.new(),
		BrokenRidge.new(),
		BluewaterCrossing.new(),
		SunkenMeadow.new(),
		AncientFold.new(),
		HeartkeepApproach.new(),
	]
