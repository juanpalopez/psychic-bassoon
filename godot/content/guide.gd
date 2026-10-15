## The words of the first-time tour and of the tower guide. Strings only; the numbers shown
## beside them come from `towers.gd`.
extends RefCounted

## The words of the intro wave, one speech bubble per step. `target` is the name of a HUD
## control to outline ("" for none).
const INTRO := {
	"goal":
	{
		"text":
		(
			"Welcome! Paper raiders walk the road toward your Heartstone. "
			+ "Every one that gets there costs Heartstone health, so stop them "
			+ "for 20 waves. Let's build your first tower."
		),
		"target": "",
	},
	"pick_socket":
	{
		"text":
		(
			"Tap a glowing circle: a socket. Towers cost Buttons, which you earn "
			+ "from every foe you stop."
		),
		"target": "",
	},
	"pick_tower":
	{
		"text":
		(
			"Hover over a tower, or press and hold it, to see what it does. Tap "
			+ "it to build. A Spool Guard is a safe first choice."
		),
		"target": "",
	},
	"start_wave":
	{
		"text": "Your tower is ready. Press Start wave to send the first raiders.",
		"target": "LaunchWave",
	},
	"watch":
	{
		"text":
		(
			"Here they come! Your tower shoots what is in range. Tap it to "
			+ "upgrade or sell; higher paper reaches further."
		),
		"target": "",
	},
	"done":
	{
		"text":
		(
			"Well done, you held the road! More towers help: open Menu and "
			+ "Tower guide to see each one, or How to play to see this again. "
			+ "Good luck!"
		),
		"target": "",
	},
}

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
		"weak": "Costly, and its reach is modest, so it is best saved for armored foes.",
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
