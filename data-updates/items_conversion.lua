local flib_locale = require("__flib__.locale")
local atdt_utils = require("__all-the-damage-types__.atdt_utils")

--- @class ATDTAmmoTemplate
---
--- @field name string
--- @field item data.ItemPrototype
--- @field recipes data.RecipePrototype[]
--- @field recipes_unlocks {[string]: data.TechnologyPrototype}
--- @field type {[data.DamageTypeID]: boolean}
--- @field related_entities {[data.EntityID]: data.EntityPrototype}

--- @param original_icon data.IconData[]
--- @param pic string | nil
--- @param tint data.Color | nil
--- @return data.IconData[]
local function generate_icons(original_icon, pic, tint)
	local c_scale = 0.64
	local layers = original_icon
	for _, layer in pairs(layers) do
		layer.scale = (layer.scale or 1) * c_scale
		local sx, sy = atdt_utils.vec_xy(layer.shift or { 0, 0 })
		layer.shift = { x = sx * c_scale + 2, y = sy * c_scale + 2 }
		layer.draw_background = true
	end

	if pic ~= nil then
		layers[#layers + 1] = {
			icon = pic,
			scale = 0.45,
			icon_size = 64,
			shift = { x = -11, y = -11 },
			tint = tint,
		}
	end

	return layers
end

--- @param dt data.DamageType
--- @return string | nil
local function icon_for_dt(dt)
	local icon_name = dt.atdt_icon_name
	if icon_name == nil then
		return nil
	end
	local name = "__all-the-damage-types__/graphics/icons/" .. icon_name .. ".png"
	return name
end

--- @param effs data.TriggerEffect|(data.TriggerEffect[])
--- @param cb? fun(eff:data.TriggerEffect)
--- @param delivery_cb? fun(eff:data.TriggerDelivery)
local function process_trigger_effect(effs, cb, delivery_cb)
	if effs == nil then
		return
	end
	if effs[1] == nil then
		effs = { effs }
	end
	for _, eff in pairs(effs) do
		if eff ~= nil then
			if eff.type == "nested-result" then
				for_each_trigger_effect(eff.action, cb, delivery_cb)
			elseif eff.non_colliding_fail_result ~= nil then
				for_each_trigger_effect(eff.non_colliding_fail_result, cb)
			else
				if cb ~= nil then
					cb(eff)
				end
			end
		end
	end
end

--- @param trigger data.Trigger|((data.Trigger|nil)[])|nil
--- @param cb? fun(eff:data.TriggerEffect)
--- @param delivery_cb? fun(act:data.TriggerDelivery)
function for_each_trigger_effect(trigger, cb, delivery_cb)
	if trigger == nil then
		return
	end

	if trigger[1] == nil then
		trigger = { trigger }
	end

	for _, tr in pairs(trigger) do
		if tr ~= nil then
			if #tr > 0 then
				error("Triggers list got passed to for_each_trigger_effect")
			end
			local action = tr.action_delivery
			if action ~= nil then
				if action[1] == nil then
					action = { action }
				end

				for _, act in pairs(action) do
					if delivery_cb ~= nil then
						delivery_cb(act)
					end
					process_trigger_effect(act.source_effects, cb, delivery_cb)
					process_trigger_effect(act.target_effects, cb, delivery_cb)
				end
			end
		end
	end
end

--- @param eff data.TriggerEffect | nil
--- @return data.Trigger | nil
local function wrap_trigger_effect(eff)
	if eff == nil then
		return nil
	end
	return {
		type = "direct",
		action_delivery = {
			type = "instant",
			target_effects = eff,
		},
	}
end

--- @param proto data.EntityID|data.EntityPrototype|data.FireFlamePrototype|data.ProjectilePrototype|data.ArtilleryProjectilePrototype|data.BeamPrototype|data.FluidStreamPrototype|data.StickerPrototype|data.ExplosionPrototype|data.SmokeWithTriggerPrototype|data.CombatRobotPrototype|data.ElectricTurretPrototype|data.LandMinePrototype
--- @return data.EntityPrototype | nil
--- @return (data.Trigger?)[]
local function triggers_of_entity(proto)
	if type(proto) == "string" then
		proto = data.raw["projectile"][proto]
			or data.raw["artillery-projectile"][proto]
			or data.raw["beam"][proto]
			or data.raw["stream"][proto]
			or data.raw["fire"][proto]
			or data.raw["sticker"][proto]
			or data.raw["explosion"][proto]
			or data.raw["smoke-with-trigger"][proto]
			or data.raw["combat-robot"][proto]
			or data.raw["turret"][proto]
			or data.raw["electric-turret"][proto]
			or data.raw["fluid-turret"][proto]
			or data.raw["land-mine"][proto]
		if proto == nil then
			return nil, {}
		end
	end
	if proto.type == "projectile" then
		return proto, atdt_utils.flatten({
			proto.action,
			proto.final_action,
		})
	elseif proto.type == "artillery-projectile" then
		return proto, atdt_utils.flatten({
			proto.action,
			proto.final_action,
		})
	elseif proto.type == "beam" then
		return proto, atdt_utils.flatten({ proto.action })
	elseif proto.type == "stream" then
		return proto, atdt_utils.flatten({
			proto.initial_action,
			proto.action,
		})
	elseif proto.type == "fire" then
		return proto, atdt_utils.flatten({ proto.on_fuel_added_action, proto.on_damage_tick_effect })
	elseif proto.type == "sticker" then
		if proto.update_effects == nil then
			return proto, {}
		end
		local effs = {}
		for _, eff in pairs(proto.update_effects) do
			effs[#effs + 1] = wrap_trigger_effect(eff.effect)
		end
		return proto, effs
	elseif proto.type == "explosion" then
		return proto, atdt_utils.flatten({ proto.explosion_effect })
	elseif proto.type == "smoke-with-trigger" then
		return proto, atdt_utils.flatten({ proto.action, proto.created_effect })
	elseif
		proto.type == "combat-robot"
		or proto.type == "electric-turret"
		or proto.type == "turret"
		or proto.type == "fluid-turret"
		or proto.type == "land-mine"
	then
		local triggers = {
			proto.destroy_action,
			proto.created_effect,
			wrap_trigger_effect(proto.dying_trigger_effect),
			wrap_trigger_effect(proto.damaged_trigger_effect),
		}
		if proto.type == "land-mine" then
			triggers[#triggers + 1] = proto.action
		end
		if proto.attack_parameters ~= nil and proto.attack_parameters.ammo_type ~= nil then
			triggers[#triggers + 1] = proto.attack_parameters.ammo_type.action
		end
		return proto, atdt_utils.flatten(triggers)
	end
	return nil, {}
end

--- @param proto data.EntityID|data.EntityPrototype|data.FireFlamePrototype
--- @return (data.DamageParameters|nil)[]
local function nontrigger_damages_of_entity(proto)
	if (proto.type == "fire" or proto.type == "sticker") and proto.damage_per_tick ~= nil then
		return { proto.damage_per_tick }
	end
	return {}
end

--- @param item string|data.ItemPrototype|data.CapsulePrototype|data.AmmoItemPrototype|data.GunPrototype
--- @return (data.Trigger?)[]
local function triggers_of_item(item)
	if type(item) == "string" then
		item = data.raw["ammo"][item] or data.raw["capsule"][item] or data.raw["gun"][item]
		if item == nil then
			return {}
		end
	end

	if item.type == "ammo" then
		if item.ammo_type == nil then
			return {}
		end
		if item.ammo_type[1] == nil then
			return atdt_utils.flatten({ item.ammo_type.action })
		else
			local triggers = {}
			for _, act in pairs(item.ammo_type) do
				triggers[#triggers + 1] = act.action
			end
			return triggers
		end
	elseif item.type == "capsule" then
		if
			item.capsule_action ~= nil
			and item.capsule_action.attack_parameters ~= nil
			and item.capsule_action.attack_parameters.ammo_type ~= nil
		then
			return atdt_utils.flatten({ item.capsule_action.attack_parameters.ammo_type.action })
		end
	end
	return {}
end

--- @param anim any
--- @param tint data.Color
local function tint_aimation_or_sprite_or_whatever(anim, tint)
	if anim == nil then
		return
	end
	if #anim > 0 then
		for _, an in pairs(anim) do
			tint_aimation_or_sprite_or_whatever(an, tint)
		end
		return
	end

	tint_aimation_or_sprite_or_whatever(anim.layers, tint)
	tint_aimation_or_sprite_or_whatever(anim.sheet, tint)
	tint_aimation_or_sprite_or_whatever(anim.sheets, tint)
	tint_aimation_or_sprite_or_whatever(anim.pictures, tint)
	tint_aimation_or_sprite_or_whatever(anim.animation, tint)
	tint_aimation_or_sprite_or_whatever(anim.base_visualisation, tint)
	tint_aimation_or_sprite_or_whatever(anim.water_reflection, tint)

	if anim.north ~= nil then
		tint_aimation_or_sprite_or_whatever(anim.north, tint)
		tint_aimation_or_sprite_or_whatever(anim.north_east, tint)
		tint_aimation_or_sprite_or_whatever(anim.east, tint)
		tint_aimation_or_sprite_or_whatever(anim.south_east, tint)
		tint_aimation_or_sprite_or_whatever(anim.south, tint)
		tint_aimation_or_sprite_or_whatever(anim.south_west, tint)
		tint_aimation_or_sprite_or_whatever(anim.west, tint)
		tint_aimation_or_sprite_or_whatever(anim.north_west, tint)
	end

	if anim.beam ~= nil then
		tint_aimation_or_sprite_or_whatever(anim.beam.start, tint)
		tint_aimation_or_sprite_or_whatever(anim.beam.ending, tint)
		tint_aimation_or_sprite_or_whatever(anim.beam.head, tint)
		tint_aimation_or_sprite_or_whatever(anim.beam.tail, tint)
		tint_aimation_or_sprite_or_whatever(anim.beam.body, tint)
	end

	if

		anim.filename ~= nil
		or type(anim.icon) == "string"
		or anim.tint ~= nil
		or anim.filenames ~= nil
		or anim.stripes ~= nil
	then
		anim.tint = tint
		-- anim.apply_runtime_tint = true
		-- anim.invert_colors = false
	end
end

--- @param light data.LightDefinition | nil
--- @param tint data.Color
local function tint_light(light, tint)
	if light == nil then
		return
	end

	light.color = tint
end

--- @param entity data.EntityPrototype|data.FireFlamePrototype|data.ProjectilePrototype|data.ArtilleryProjectilePrototype|data.BeamPrototype|data.FluidStreamPrototype|data.StickerPrototype|data.ExplosionPrototype|data.SmokeWithTriggerPrototype|data.CombatRobotPrototype|data.TurretPrototype|data.FluidTurretPrototype|data.LandMinePrototype
--- @param tint data.Color | nil
local function tint_entity(entity, tint)
	if tint == nil then
		return
	end
	if entity.type == "projectile" then
		tint_aimation_or_sprite_or_whatever(entity.animation, tint)
	elseif entity.type == "artillery-projectile" then
		tint_aimation_or_sprite_or_whatever(entity.picture, tint)
	elseif entity.type == "beam" then
		tint_aimation_or_sprite_or_whatever(entity.graphics_set, tint)
	elseif entity.type == "stream" then
		tint_aimation_or_sprite_or_whatever(entity.spine_animation, tint)
		tint_aimation_or_sprite_or_whatever(entity.particle, tint)
		tint_light(entity.stream_light, tint)
		tint_light(entity.ground_light, tint)
	elseif entity.type == "fire" then
		tint_aimation_or_sprite_or_whatever(entity.small_tree_fire_pictures, tint)
		tint_aimation_or_sprite_or_whatever(entity.pictures, tint)
		tint_aimation_or_sprite_or_whatever(entity.smoke_source_pictures, tint)
		tint_aimation_or_sprite_or_whatever(entity.secondary_pictures, tint)
		tint_light(entity.light, tint)
	elseif entity.type == "sticker" then
		tint_aimation_or_sprite_or_whatever(entity.animation, tint)
	elseif entity.type == "explosion" then
		tint_aimation_or_sprite_or_whatever(entity.animations, tint)
		tint_light(entity.light, tint)
	elseif entity.type == "smoke-with-trigger" then
		tint_aimation_or_sprite_or_whatever(entity.animation, tint)
		entity.color = tint
	elseif entity.type == "combat-robot" then
		tint_aimation_or_sprite_or_whatever(entity.idle, tint)
		tint_aimation_or_sprite_or_whatever(entity.in_motion, tint)
		tint_light(entity.light, tint)
		entity.color = tint
	elseif entity.type == "turret" or entity.type == "fluid-turret" or entity.type == "electric-turret" then
		tint_aimation_or_sprite_or_whatever(entity.folded_animation, tint)
		tint_aimation_or_sprite_or_whatever(entity.graphics_set, tint)
		tint_aimation_or_sprite_or_whatever(entity.preparing_animation, tint)
		tint_aimation_or_sprite_or_whatever(entity.prepared_animation, tint)
		tint_aimation_or_sprite_or_whatever(entity.prepared_alternative_animation, tint)
		tint_aimation_or_sprite_or_whatever(entity.starting_attack_animation, tint)
		tint_aimation_or_sprite_or_whatever(entity.attacking_animation, tint)
		tint_aimation_or_sprite_or_whatever(entity.energy_glow_animation, tint)
		tint_aimation_or_sprite_or_whatever(entity.resource_indicator_animation, tint)
		tint_aimation_or_sprite_or_whatever(entity.ending_attack_animation, tint)
		tint_aimation_or_sprite_or_whatever(entity.folding_animation, tint)
		tint_aimation_or_sprite_or_whatever(entity.integration, tint)
		tint_light(entity.muzzle_light, tint)
	elseif entity.type == "land-mine" then
		tint_aimation_or_sprite_or_whatever(entity.picture_safe, tint)
		tint_aimation_or_sprite_or_whatever(entity.picture_set, tint)
	end
end

--- @type {[string]: ATDTAmmoTemplate}
local ammos = {}

--- @param item data.ItemPrototype
--- @param trigger data.Trigger|(data.Trigger[])
--- @return {[data.DamageTypeID]: boolean}
--- @return {[data.EntityID]: data.EntityPrototype}
local function parse_triggers_for_damage_projectiles(item, trigger)
	--- @type {[data.DamageTypeID]: boolean}
	local dts = {}
	--- @type {[data.EntityID]: data.EntityPrototype}
	local related_ents = {}
	--- @type {[data.EntityID]: boolean}
	local new_ents = {}

	--- @param proto data.EntityPrototype|data.FireFlamePrototype|nil
	--- @param trigger data.Trigger|(data.Trigger[])|nil
	local function traverse_trigger(proto, trigger)
		for_each_trigger_effect(trigger, function(eff)
			if eff.type == "damage" and eff.damage ~= nil and eff.damage.amount > 0 then
				dts[eff.damage.type] = true
			elseif eff.type == "create-sticker" then
				new_ents[eff.sticker] = true
			elseif
				eff.type == "create-entity"
				or eff.type == "create-explosion"
				or eff.type == "create-smoke"
				or eff.type == "create-fire"
			then
				new_ents[eff.entity_name] = true
			end
		end, function(act)
			if act.type == "projectile" then
				new_ents[act.projectile] = true
			elseif act.type == "artillery" then
				new_ents[act.projectile] = true
			elseif act.type == "beam" then
				new_ents[act.beam] = true
			elseif act.type == "stream" then
				new_ents[act.stream] = true
			end
		end)
		if proto ~= nil and proto.type == "fire" then
			for _, dmg in pairs(nontrigger_damages_of_entity(proto)) do
				if dmg.amount > 0 then
					dts[dmg.type] = true
				end
			end
		end
	end

	if item.place_result ~= nil then
		new_ents[item.place_result] = true
	end

	traverse_trigger(nil, trigger)

	while next(new_ents) ~= nil do
		local swap = new_ents
		new_ents = {}
		for id, _ in pairs(swap) do
			if related_ents[id] == nil then
				proto, triggers = triggers_of_entity(id)
				if proto ~= nil then
					related_ents[id] = proto
					traverse_trigger(proto, triggers)
				end
			end
		end
	end
	return dts, related_ents
end

--- @param item data.ItemPrototype
local function ingest_item(item)
	local triggers = triggers_of_item(item)
	local dts, related_ents = parse_triggers_for_damage_projectiles(item, triggers)

	if next(dts) ~= nil then
		ammos[item.name] = {
			name = item.name,
			item = item,
			recipes = {},
			related_entities = related_ents,
			type = dts,
			recipes_unlocks = {},
		}
	end
end

for _, ammo in pairs(data.raw["ammo"]) do
	ingest_item(ammo)
end

for _, capsule in pairs(data.raw["capsule"]) do
	ingest_item(capsule)
end

for _, gun in pairs(data.raw["gun"]) do
	ingest_item(gun)
end

for _, item in pairs(data.raw["item"]) do
	if item.place_result ~= nil then
		ingest_item(item)
	end
end

--- @type {[string]: ATDTAmmoTemplate}
local tracked_recipes = {}

for _, rec in pairs(data.raw["recipe"]) do
	if rec.results == nil then
		goto continue
	end

	for _, res in pairs(rec.results) do
		if res.type == "item" then
			local at = ammos[res.name]
			if at ~= nil then
				at.recipes[#at.recipes + 1] = rec
				tracked_recipes[rec.name] = at
			end
		end
	end

	::continue::
end

for _, tech in pairs(data.raw["technology"]) do
	if tech.effects ~= nil then
		for _, eff in pairs(tech.effects) do
			if eff.type == "unlock-recipe" then
				local at = tracked_recipes[eff.recipe]
				if at ~= nil then
					at.recipes_unlocks[eff.recipe] = tech
				end
			end
		end
	end
end

local items_mapping = {}

for _, dt in pairs(data.raw["damage-type"]) do
	items_mapping[dt.name] = {}
	for _, ammo in pairs(ammos) do
		-- skip items that already belong to this damage type or without recipes
		if ammo.type[dt.name] ~= true and #ammo.recipes > 0 then
			items_mapping[dt.name][ammo.name] = "atdt-" .. dt.name .. "-" .. ammo.name
		end
	end
end

--- @type data.DamageType[]
local known_dts = {}

--- @type {[data.DamageTypeName]: {[data.DamageTypeName]: data.DamageTypeName}}
local damage_pairs = {}

for id, dt in pairs(data.raw["damage-type"]) do
	if dt.atdt_supported then
		known_dts[#known_dts + 1] = dt
	end
end

---@param damages data.DamageParameters[]
---@param dt data.DamageType
local function modify_damages(damages, dt)
	if #damages == 0 then
		return
	end
	local max = damages[1].amount
	local primary = damages[1].type

	for _, dmg in ipairs(damages) do
		if dmg.amount > max then
			max = dmg.amount
			primary = dmg.type
		end
	end

	damage_pairs[dt.name] = damage_pairs[dt.name] or {}

	for _, dmg in ipairs(damages) do
		if dmg.type == primary then
			dmg.type = dt.name
		else
			local pair = damage_pairs[dt.name][dmg.type]
			if pair == nil then
				local sec_dt = data.raw["damage-type"][dmg.type] or dt
				if sec_dt.atdt_seed == nil then
					sec_dt.atdt_seed = atdt_utils.hash_of(sec_dt.name)
				end
				local rng = atdt_utils.new_rng(
					atdt_utils.hash_sum(sec_dt.atdt_seed, dt.atdt_seed or atdt_utils.hash_of(dt.name))
				)
				local new_type = known_dts[math.floor(atdt_utils.next_rng(rng) * #known_dts) + 1]
				damage_pairs[dt.name][dmg.type] = new_type.name
				pair = new_type.name
			end
			dmg.type = pair
		end

		local edt = data.raw["damage-type"][dmg.type]
		if edt ~= nil and edt.atdt_power_mult ~= nil then
			dmg.amount = dmg.amount * edt.atdt_power_mult
		end
	end
end

--- @param ammo ATDTAmmoTemplate
--- @param dt data.DamageType
local function generateAmmoWithType(ammo, dt)
	if items_mapping[dt.name][ammo.name] == nil then
		return
	end

	local new_item = table.deepcopy(ammo.item)
	new_item.name = items_mapping[dt.name][ammo.name]
	local loc_name = flib_locale.of_item(ammo.item) --[[@as data.LocalisedString]]
	local dt_loc_name = dt.localised_name or { "damage-type-name." .. dt.name }

	local tint = dt.atdt_custom_tint

	if new_item.icons == nil then
		new_item.icons = {
			{
				icon = new_item.icon,
				icon_size = new_item.icon_size,
			},
		}
		new_item.icon = nil
	end

	new_item.icons = generate_icons(new_item.icons, icon_for_dt(dt), tint)

	if dt.atdt_localised_item_name_template ~= nil then
		new_item.localised_name = {
			dt.atdt_localised_item_name_template,
			loc_name,
		}
	else
		new_item.localised_name = { "item-name.atdt-name-template", loc_name, dt_loc_name }
	end

	local new_ents = {}
	local ent_mapping = {}

	local damages = {}

	for _, ent in pairs(ammo.related_entities) do
		local new_ent = table.deepcopy(ent)
		new_ent.name = "atdt-" .. dt.name .. "-" .. ent.name

		new_ents[#new_ents + 1] = new_ent
		ent_mapping[ent.name] = new_ent.name

		tint_entity(new_ent, tint)

		if new_ent.minable ~= nil then
			if new_ent.minable.result == ammo.item.name then
				new_ent.minable.result = new_item.name
			elseif new_ent.minable.results ~= nil then
				for i, res in ipairs(new_ent.minable.results) do
					if res.type == "item" and res.name == ammo.item.name then
						new_ent.minable.results[i].name = new_item.name
					end
				end
			end
		end

		local ent_loc_name = ent.localised_name or { "entity-name." .. ent.name }
		if dt.atdt_localised_item_name_template ~= nil then
			new_ent.localised_name = {
				dt.atdt_localised_item_name_template,
				ent_loc_name,
			}
		else
			new_ent.localised_name = { "item-name.atdt-name-template", ent_loc_name, dt_loc_name }
		end

		for _, dmg in pairs(nontrigger_damages_of_entity(new_ent)) do
			damages[#damages + 1] = dmg
		end
	end

	local triggers = {}

	for _, ent in pairs(new_ents) do
		local _, ent_trigs = triggers_of_entity(ent)
		for _, trig in pairs(ent_trigs) do
			triggers[#triggers + 1] = trig
		end
	end

	for _, trig in pairs(triggers_of_item(new_item)) do
		triggers[#triggers + 1] = trig
	end

	for_each_trigger_effect(triggers, function(eff)
		if eff.type == "damage" and eff.damage ~= nil then
			damages[#damages + 1] = eff.damage
		elseif
			eff.type == "create-fire"
			or eff.type == "create-entity"
			or eff.type == "create-explosion"
			or eff.type == "create-smoke"
		then
			eff.entity_name = ent_mapping[eff.entity_name] or eff.entity_name
		elseif eff.type == "create-sticker" then
			eff.sticker = ent_mapping[eff.sticker] or eff.sticker
		end
	end, function(act)
		if act.type == "projectile" then
			act.projectile = ent_mapping[act.projectile] or act.projectile
		elseif act.type == "artillery" then
			act.projectile = ent_mapping[act.projectile] or act.projectile
		elseif act.type == "beam" then
			act.beam = ent_mapping[act.beam] or act.beam
		elseif act.type == "stream" then
			act.stream = ent_mapping[act.stream] or act.stream
		end
	end)

	new_item.place_result = ent_mapping[new_item.place_result] or new_item.place_result

	modify_damages(damages, dt)

	local recipes = {}
	for _, rec in pairs(ammo.recipes) do
		local new_rec = table.deepcopy(rec)
		new_rec.name = "atdt-" .. dt.name .. "-" .. rec.name
		for _, res in pairs(new_rec.results) do
			if res.type == "item" and res.name == ammo.name then
				res.name = new_item.name
			end
		end

		if new_rec.ingredients ~= nil then
			for _, ing in pairs(new_rec.ingredients) do
				if ing.type == "item" then
					ing.name = items_mapping[dt.name][ing.name] or ing.name
				end
			end
		end

		recipes[#recipes + 1] = new_rec
		local unlocked_with = ammo.recipes_unlocks[rec.name]
		if unlocked_with ~= nil then
			unlocked_with.effects[#unlocked_with.effects + 1] = {
				type = "unlock-recipe",
				recipe = new_rec.name,
			}
		end
	end

	data:extend({ new_item })
	data:extend(recipes)
	if #new_ents > 0 then
		data:extend(new_ents)
	end
end

for _, dt in pairs(data.raw["damage-type"]) do
	if dt.atdt_supported then
		for _, ammo in pairs(ammos) do
			generateAmmoWithType(ammo, dt)
		end
	end
end
