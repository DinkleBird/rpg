extends Panel

# Logic to update the item icon and count
func update_slot(item):
	if item:
		$Icon.texture = item.texture
		if item.stackable:
			$Count.text = str(item.count)
		else:
			$Count.text = ""
	else:
		$Icon.texture = null
		$Count.text = ""
