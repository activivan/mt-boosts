# Minetest Boosts
This Minetest mod adds boosts, technically privileges that are granted temporarily. Users can buy or gift them.

## Configuration
You can configure your boosts in the `boosts.lua` file in the mod folder or configure them world-specific by creating a `boosts.lua` file in your world folder.

The file has to return a table including the configured boosts:

#### **`boosts.lua`**
```lua
return {
    ["fly"] = { -- ID of boost, to be used with /boost
        priv = "fly", -- Name of the privilege the player should be granted temporarily
        duration = 90, -- Duration of the temporary privilege grant in seconds
        cost = {
            type = "item", -- Cost type "item" when paying with item
            stack = {
                item = "default:diamond", -- Item name (id-string)
                count = 3 -- Item count
            }
        }
    },
    ["fast"] = {
        priv = "fast",
        duration = 60,
        cost = {
            type = "money", -- Cost type "money" when using supported payment mod
            amount = 20 -- Amount to be withdrawn
        }
    },
    ["time"] = {
        priv = "settime",
        duration = 15,
        cost = false -- Cost equal to false when boost should be free
    },
    ...
}
```

A boost configuration is made up of (all fields are required):
* `priv` - Name of the privilege the player should be granted temporarily
* `duration` - Timespan of the temporary privilege grant in seconds
* `cost` - Table defining the cost of the boost - for a boost to be free set this to `false`
    * `type` - "item" when paying with item, "money" when using payment mod
    * `stack` - ***conditionally required** with "item" cost type* - table defining an ItemStack
        * `item` - Name (or id-string) of item
        * `count` - Item count
    * `amount` - ***conditionally required** with "money" cost type* - amount to be withdrawn from user

The mod validates the configuration. If any errors occur, the boost will be disabled.

When listing the available boosts using `/boosts`, the formspec includes a currency string into the description of boosts with the "money" cost type to indicate the amount of money. The money mods feature a setting to set the currency name. This will be adopted, otherwise it defaults to "Minegeld". If you want to overwrite this, set the `currency` parameter in your `minetest.conf` file.

## Supported payment mods
This mod supports the following payment mods when using the "money" cost type:

* [money3](https://content.minetest.net/packages/luk3yx/money3/) by luk3yx
* [jeans_economy](https://content.minetest.net/packages/Jean3219/jeans_economy/) by Jean3219 (please make sure to update to the latest version, as the previous contained a bug that made this mod not work)

When using item-based money mods like [currency](https://content.minetest.net/packages/VanessaE/currency/), please use the "item" cost type instead.

### Deprecated
The following mods are also supported, but it's strongly recommended to use money3 instead:
* [money](https://github.com/ChaosWormz/minetest-money) by kotolegokot and Xiong
* [money2](https://github.com/Bremaweb/money2) by kotolegokot and Bad_Command

## Usage
Users can list all available boosts using the `/boosts` command. 
To buy or gift a boost, you have to use the `/boost` command.

### Examples
* `/boost buy fly` User buys a fly boost for himself
* `/boost gift userB fly` User gifts userB a fly boost

## booster-Privilege
This mod ships with a `booster` privilege, with which users can buy and gift boosts for free.

## License
Copyright © 2022 activivan activivan.studios@gmail.com

Licensed under GNU Lesser General Public License v3 or later
