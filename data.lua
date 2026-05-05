local atdt_utils = require("__all-the-damage-types__.atdt_utils")

--- @class ATDTDamageDef
--- @field name string
--- @field has_localised_item_name_template boolean
--- @field custom_tint? data.Color
--- @field skip? boolean

--- @class data.DamageType
--- @field atdt_custom_tint? data.Color
--- @field atdt_localised_item_name_template? string
--- @field atdt_icon_name? string
--- @field atdt_power_mult? number
--- @field atdt_seed? number
--- @field atdt_supported? boolean

---@param name string
---@param has_localised_item_name_template? boolean
---@param custom_tint? data.Color|string
---@return ATDTDamageDef
local function dt(name, has_localised_item_name_template, custom_tint)
	return {
		name = name,
		has_localised_item_name_template = has_localised_item_name_template,
		custom_tint = custom_tint,
	}
end

--- @type (string|ATDTDamageDef)[]
local damage_types = {
	dt("stinky", false, "915b05"),
	dt("psychic", false, "0d52e8"),
	dt("holy", false, "ffff00"),
	dt("evil", false, "6a0dc6"),
	dt("curse", true, "bf0553"),
	dt("demonic", false, "bf1505"),
	dt("devastation", true, "9b9b9b"),
	dt("hypersonic", false, "0edef9"),
	dt("temporal", false, "58b5e8"),
	dt("eradication", true, "e8c858"),
	dt("natural-selection", true, "318413"),
	dt("kinky", false, "f954a4"),
	dt("water", true, "078fea"),
	dt("astrological", false, "f2cd18"),
	dt("love", true, "f21852"),
	dt("slimy", false, "09f915"),
	dt("automated", false, "bfba0a"),
	dt("eldritch", false, "830591"),
	dt("theoretical", false, "f8fc0f"),
	dt("algebraical", false, "adf907"),
	dt("emotional", false, "04f79e"),

	-- Vanilla types
	dt("electric", false, "fcf005"),
	dt("explosion", false, "fc7805"),
	dt("poison", false, "560232"),
	dt("physical", false, "a0b9c1"),
	dt("impact", false, "c1a7a0"),
	dt("laser", false, "fc0707"),
	dt("fire", false, "fc8607"),
	dt("acid", false, "82fc07"),
}

for _, ty in pairs(damage_types) do
	if type(ty) == "string" then
		ty = {
			name = ty,
			has_localised_item_name_template = false,
			custom_tint = nil,
		}
	end

	if type(ty.custom_tint) == "string" then
		ty.custom_tint = util.color(ty.custom_tint --[[@as string]])
	end

	local cdt = data.raw["damage-type"][ty.name]
	if cdt == nil then
		cdt = {
			type = "damage-type",
			name = "atdt-" .. ty.name,
		}
	end

	cdt.atdt_supported = true

	local hash = atdt_utils.hash_of(cdt.name)
	cdt.atdt_seed = hash

	local rng = atdt_utils.new_rng(hash)
	cdt.atdt_power_mult = 0.8 + atdt_utils.next_rng(rng) * 0.4

	if ty.custom_tint ~= nil then
		cdt.atdt_custom_tint = ty.custom_tint
	else
		local r, g, b = atdt_utils.hsv2rgb(rng, 1.0, 1.0)
		cdt.atdt_custom_tint = { r, g, b }
	end

	if ty.has_localised_item_name_template then
		cdt.atdt_localised_item_name_template = "damage-type-name." .. cdt.name .. "-item-template"
	end

	cdt.atdt_icon_name = ty.name

	data:extend({ cdt })
end