local atdt_utils = require("__all-the-damage-types__.atdt_utils")

--- @type {[string]: data.DamageType}
local known_dts = {}

for id, dt in pairs(data.raw["damage-type"]) do
	if dt.atdt_supported then
		known_dts[id] = dt
	end
end

---@param ent data.EntityWithHealthPrototype
local function patch_entity(ent)
	local seed = atdt_utils.hash_of(ent.name)

	local min_percentage = 1e9
	local max_percentage = 0
	local min_flat = 1e9
	local max_flat = 0

	local retains = {}
	if ent.resistances == nil then
		ent.resistances = {}
	end

	for _, res in pairs(ent.resistances) do
		if known_dts[res.type] == nil then
			retains[#retains + 1] = res
		end
		if res.decrease ~= nil then
			max_flat = math.max(max_flat, res.decrease)
			min_flat = math.min(min_flat, res.decrease)
		else
			min_flat = 0
		end
		if res.percent ~= nil and res.percent ~= 100 then
			max_percentage = math.max(max_percentage, res.percent)
			min_percentage = math.min(min_percentage, res.percent)
		else
			min_percentage = 0
		end
	end
	min_flat = math.max(min_flat, 0)
	min_percentage = math.max(min_percentage, 0)

	if #ent.resistances == 0 then
		min_percentage = 0
		max_percentage = 10
		min_flat = 0
	else
		max_percentage = math.min(max_percentage, 99)
		min_percentage = min_percentage / 2
		max_flat = max_flat * 2
		min_flat = min_flat / 2
	end
	max_flat = math.max(max_flat, math.floor(5 + math.pow(ent.max_health, 0.4)))

	ent.resistances = retains

	for _, dt in pairs(known_dts) do
		local rng = atdt_utils.new_rng(atdt_utils.hash_sum(seed, dt.atdt_seed or atdt_utils.hash_of(dt.name)))

		local flat = 0
		local percentage = 0
		-- full immunity
		if atdt_utils.next_rng(rng) < 1 / 3 then
			percentage = 100
		else
			if atdt_utils.next_rng(rng) < 0.5 then
				flat = atdt_utils.next_rng_range(rng, min_flat, max_flat)
			end
			percentage = atdt_utils.next_rng_range(rng, min_percentage, max_percentage)
		end

		-- vulnerability
		if atdt_utils.next_rng(rng) < 1 / 10 then
			flat = -flat
			percentage = math.floor(atdt_utils.next_rng(rng) * 3 + 1) * -25
		end

		ent.resistances[#ent.resistances + 1] = {
			type = dt.name,
			decrease = math.floor(flat + 0.5),
			percent = atdt_utils.round_to_nearest(percentage, 5),
		}
	end
end

local protos =
	{ "asteroid", "unit-spawner", "segment", "segmented-unit", "spider-leg", "spider-unit", "unit", "turret" }
for _, proto in pairs(protos) do
	if data.raw[proto] ~= nil then
		for _, ent in pairs(data.raw[proto]) do
			patch_entity(ent)
		end
	end
end
