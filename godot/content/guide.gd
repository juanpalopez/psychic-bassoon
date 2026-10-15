## The words of the first-time tour and of the tower guide. Strings only; the numbers shown
## beside them come from `towers.gd`.
extends RefCounted

## One card per step. `target` is the name of a HUD control to outline ("" for none).
const TOUR_STEPS: Array[Dictionary] = [
	{
		"title": "Protect the Heartstone",
		"text":
		(
			"Paper raiders walk the road toward your Heartstone. Each one "
			+ "that gets there costs Heartstone health. Stop them for 20 "
			+ "waves to win."
		),
		"target": "",
	},
	{
		"title": "Build on sockets",
		"text":
		(
			"Tap a pale circle, a socket, to build a tower on it. Towers "
			+ "cost Buttons. You earn Buttons for every foe you stop and "
			+ "for every wave you clear."
		),
		"target": "",
	},
	{
		"title": "Pick the right tower",
		"text":
		(
			"Different foes need different towers. Open the Tower guide "
			+ "from the Menu at any time to see what each tower is good at."
		),
		"target": "MenuButton",
	},
	{
		"title": "Start a wave",
		"text":
		(
			"Press Start wave when you are ready. Calling the next wave "
			+ "early pays a bonus. Pause and the speed button slow the game "
			+ "down or speed it up."
		),
		"target": "LaunchWave",
	},
	{
		"title": "Upgrade and sell",
		"text":
		(
			"Tap a tower to see its range, then upgrade it to hit harder "
			+ "or sell it for some Buttons back. A socket on higher paper "
			+ "reaches further."
		),
		"target": "",
	},
	{
		"title": "Watch for the crow",
		"text":
		(
			"The Messenger Crow flies in with news of each wave. Good "
			+ "luck, and keep the Heartstone safe!"
		),
		"target": "",
	},
]

## One entry per tower id: what it is, what it is good against, what it is bad at, a tip.
const TOWERS := {
	"spoolGuard":
	{
		"role": "Fast single-target shooter.",
		"strong": "Cheap and quick. Good against Scrap Goblins and lone foes.",
		"weak": "Armor eats its small shots, so it struggles against Corrugated Orcs.",
		"tip": "Put a few near the first bends so every foe meets them early.",
	},
	"thimbleMortar":
	{
		"role": "Splash artillery.",
		"strong": "Hits a whole group at once. Best against crowds of Scrap Goblins.",
		"weak": "Slow shells are wasted on a single fast foe.",
		"tip": "Build it where the road bends, so groups bunch up inside its blast.",
	},
	"prismSpire":
	{
		"role": "Magic beam that ignores armor.",
		"strong": "The answer to Corrugated Orcs and the Cardboard Golem.",
		"weak": "Costly, with a short reach, and it does little against swarms.",
		"tip": "Keep one covering the long stretch before the Heartstone.",
	},
	"guardTent":
	{
		"role": "Blocks the road with two guards.",
		"strong":
		(
			"Each guard holds one foe so your towers get time to work. "
			+ "The Cardboard Golem cannot be blocked."
		),
		"weak": "Guards fall to heavy foes and wait a few seconds to be raised again.",
		"tip": "Place it so your shooters cover the spot where its guards stand.",
	},
	"messTent":
	{
		"role": "Support for the guards.",
		"strong": "Its aura makes nearby guards strike faster and heal.",
		"weak": "Does nothing without a Guard Tent whose guards are inside its aura.",
		"tip": "Build the Guard Tent first, then put this one beside its post.",
	},
}
