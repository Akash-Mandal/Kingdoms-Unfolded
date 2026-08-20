extends RefCounted
class_name NPCNames

const POOLS := {
	"northern": {
		"male": ["Alaric", "Bjorn", "Edric", "Garret", "Harald", "Ivor", "Leif", "Osric", "Rowan", "Sigurd", "Torin", "Ulric", "Wulf", "Bran", "Caelum"],
		"female": ["Astrid", "Brenna", "Eira", "Freya", "Gudrun", "Hilda", "Ingrid", "Kara", "Linnea", "Ragna", "Sigrid", "Thyra", "Yara", "Elin", "Mira"],
		"surnames": ["Stonehand", "Frostmere", "Ironhall", "Snowborn", "Oakenshield", "Ravenscar", "Wolfsbane", "Greyward", "Stormholt", "Ashfield", "Brighthollow", "Coldwell"]
	},
	"southern": {
		"male": ["Aldo", "Basil", "Cael", "Darius", "Emmer", "Florian", "Gaius", "Horace", "Julian", "Lucan", "Marius", "Orin", "Silas", "Titus", "Varro"],
		"female": ["Aelia", "Cassia", "Diana", "Flavia", "Julia", "Livia", "Marcia", "Octavia", "Portia", "Sabina", "Tullia", "Valeria", "Aurelia", "Celia", "Lucia"],
		"surnames": ["Aureline", "Marivale", "Солнцев", "Goldmere", "Sunward", "Vinehall", "Rosethorn", "Brightwater", "Hightide", "Lowfield", "Amberford"]
	},
	"eastern": {
		"male": ["Boran", "Cheng", "Daisuke", "Emir", "Farid", "Hiro", "Jalen", "Kazuo", "Liang", "Minho", "Narek", "Osamu", "Raul", "Tariq", "Yusuf"],
		"female": ["Amira", "Chiyo", "Emi", "Hana", "Jamila", "Keiko", "Leila", "Mei", "Nadira", "Sakura", "Yuki", "Zahra", "Aiko", "Layla", "Soraya"],
		"surnames": ["Windmere", "Eastford", "Silkward", "Dawncrest", "Jadehill", "Sunplain", "Misthollow", "Riverbend", "Stonebridge", "Highsteppe"]
	},
	"desert": {
		"male": ["Azir", "Bashir", "Casim", "Dunad", "Ghalib", "Hakim", "Idris", "Jabir", "Khalid", "Malik", "Nasir", "Rashid", "Salim", "Tareq", "Zahir"],
		"female": ["Aisha", "Fatima", "Halima", "Jasmin", "Khadija", "Layla", "Nadira", "Rania", "Salma", "Thana", "Yasmin", "Zahra", "Amira", "Samira", "Noura"],
		"surnames": ["Sandstrider", "Duneward", "Sunscorch", "Oasisborn", "Sandveil", "Dusthollow", "Mirage", "Cinderward", "Emberwell"]
	},
	"island": {
		"male": ["Kael", "Mako", "Nalu", "Pono", "Tane", "Kai", "Mano", "Rongo", "Eka", "Lono", "Kimo", "Niko", "Jiro", "Hale", "Ika"],
		"female": ["Alana", "Keira", "Lani", "Malia", "Nalani", "Kailani", "Moana", "Leilani", "Pua", "Hina", "Ailani", "Kalani", "Noa", "Malu", "Elei"],
		"surnames": ["Wavecrest", "Seaborn", "Tideward", "Coralward", "Isleward", "Reefhollow", "Saltwind", "Deepwater", "Shoreward"]
	},
	"highland": {
		"male": ["Alaric", "Bran", "Caelum", "Duncan", "Ewan", "Fergus", "Gavin", "Hamish", "Iain", "Jamie", "Kellan", "Lachlan", "Murdo", "Nevin", "Oisin"],
		"female": ["Ailsa", "Bridget", "Caitlin", "Deirdre", "Eilis", "Fiona", "Grainne", "Iona", "Jenna", "Keira", "Maeve", "Nessa", "Orla", "Riona", "Sorcha"],
		"surnames": ["Highward", "Glenmore", "Stoneward", "Braemere", "Dunhill", "Craigward", "Moorfield", "Heatherward", "Cliffmere", "Glenward", "Hillward"]
	},
}

const CULTURES: PackedStringArray = ["northern", "southern", "eastern", "desert", "island", "highland"]
const GENDERS: PackedStringArray = ["male", "female"]

static func pick_culture(raw: String) -> String:
	var c := raw.to_lower().strip_edges()
	if POOLS.has(c):
		return c
	return "highland"

static func random_gender(rng: RandomNumberGenerator) -> String:
	return GENDERS[rng.randi_range(0, 1)]

static func first_name(culture: String, gender: String, rng: RandomNumberGenerator) -> String:
	var key := pick_culture(culture)
	var g := gender.to_lower()
	if g != "male" and g != "female":
		g = random_gender(rng)
	var pool: Dictionary = POOLS[key]
	var arr: Array = pool.get(g, pool["male"])
	return str(arr[rng.randi_range(0, arr.size() - 1)])

static func surname(culture: String, rng: RandomNumberGenerator) -> String:
	var key := pick_culture(culture)
	var pool: Dictionary = POOLS[key]
	var arr: Array = pool["surnames"]
	return str(arr[rng.randi_range(0, arr.size() - 1)])

static func full_name(culture: String, gender: String, rng: RandomNumberGenerator) -> String:
	return "%s %s" % [first_name(culture, gender, rng), surname(culture, rng)]

static func generate(culture: String, gender: String, rng: RandomNumberGenerator) -> String:
	return full_name(culture, gender, rng)
