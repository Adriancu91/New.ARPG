extends TestCase
## Inventory: add, stack, remove, capacity, consume.


func test_stacking() -> void:
	var inv := Inventory.new()
	check(inv.add(Item.make_stack("potion_health", 3)), "add")
	check(inv.add(Item.make_stack("potion_health", 2)), "add more")
	eq(inv.items.size(), 1, "merged into one stack")
	eq(inv.count_of("potion_health"), 5)
	check(inv.consume("potion_health", 4), "consume")
	eq(inv.count_of("potion_health"), 1)
	check(not inv.consume("potion_health", 2), "cannot consume more than owned")


func test_stack_overflow_creates_new_stack() -> void:
	var inv := Inventory.new()
	inv.add(Item.make_stack("potion_health", 20))
	inv.add(Item.make_stack("potion_health", 5))
	eq(inv.count_of("potion_health"), 25)
	eq(inv.items.size(), 2, "max stack 20 -> two stacks")


func test_capacity_and_duplicates() -> void:
	var inv := Inventory.new()
	inv.capacity = 3
	var rng := RandomNumberGenerator.new()
	var a := ItemGenerator.generate(rng, 1, "common")
	check(inv.add(a), "add a")
	check(not inv.add(a), "same instance cannot be added twice")
	inv.add(ItemGenerator.generate(rng, 1, "common"))
	inv.add(ItemGenerator.generate(rng, 1, "common"))
	check(inv.is_full(), "full")
	check(not inv.add(ItemGenerator.generate(rng, 1, "common")), "rejects when full")


func test_remove_and_partial_stack_remove() -> void:
	var inv := Inventory.new()
	var rng := RandomNumberGenerator.new()
	var sword := ItemGenerator.generate(rng, 1, "rare", "sword", "weapon")
	inv.add(sword)
	inv.add(Item.make_stack("ash_shard", 10))
	var shard_uid: String = inv.items[1].uid
	var part := inv.remove(shard_uid, 4)
	eq(part.count, 4)
	eq(inv.count_of("ash_shard"), 6)
	var removed := inv.remove(sword.uid)
	check(removed == sword, "removed same instance")
	check(not inv.has_uid(sword.uid), "gone")


func test_salvage_and_craft() -> void:
	var cd := CharacterData.create("dawnwarden")
	var rng := RandomNumberGenerator.new()
	var it := ItemGenerator.generate(rng, 2, "rare")
	cd.inventory.add(it)
	var mats := Crafting.salvage(cd.inventory, it.uid)
	check(not mats.is_empty(), "salvage yields materials")
	check(not cd.inventory.has_uid(it.uid), "item consumed")
	cd.inventory.add(Item.make_stack("ash_shard", 3))
	cd.inventory.add(Item.make_stack("ember_dust", 1))
	cd.gold = 100
	var potions := cd.inventory.count_of("potion_health")
	check(Crafting.craft(cd, "potion_health"), "craft potion")
	eq(cd.inventory.count_of("potion_health"), potions + 1)
