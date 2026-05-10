extends Control
class_name InventoryOverlay


func get_controls() -> Dictionary:
	return {
		"inventory_overlay": self,
		"inventory_close_button": get_node_or_null("CloseButton"),
		"inventory_backdrop": get_node_or_null("Backdrop"),
		"inventory_energy_label": get_node_or_null("BagResourceBar/EnergyPlate/EnergyValue"),
		"inventory_capacity_label": get_node_or_null("BagResourceBar/CapacityPlate/CapacityValue"),
		"inventory_dominion_grid": get_node_or_null("RequirementPanel/DominionRequirementGrid"),
		"inventory_ascension_grid": get_node_or_null("RequirementPanel/AscensionRequirementGrid"),
		"inventory_item_grid": get_node_or_null("InventoryItemGrid")
	}
