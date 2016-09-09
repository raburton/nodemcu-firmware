// Module for interacting with rBoot

#include "module.h"
#include "lua.h"
#include "lauxlib.h"

#include "user_config.h"
#include "rboot-ota.h"
#include "user_interface.h"

// Lua: rom()
static int rboot_rom( lua_State* L ) {
	uint8 rom;
	rom = rboot_get_current_rom();
	lua_pushinteger(L, rom);
	return 1;
}

static void OtaUpdate_CallBack(bool result, uint8 rom_slot) {
	if(result == true) {
		// success
		if (rom_slot == FLASH_BY_ADDR) {
			c_printf("rBoot: FS update successful.\n");
		} else {
			// set to boot new rom and then reboot
			c_printf("rBoot: Firmware updated, rebooting to rom %d...\n", rom_slot);
			rboot_set_current_rom(rom_slot);
			system_restart();
		}
	} else {
		// fail
		c_printf("rBoot: Firmware update failed!\n");
	}
}

// Lua: ota()
static int rboot_ota( lua_State* L ) {
	// start the upgrade process
	if (rboot_ota_start((ota_callback)OtaUpdate_CallBack, false)) {
		c_printf("rBoot: Updating...\n");
	} else {
		c_printf("rBoot: Updating failed!\n\n");
	}
	return 0;
}

#ifdef OTA_FS_ENABLED
// Lua: otafs()
static int rboot_otafs( lua_State* L ) {
	// start the upgrade process
	if (rboot_ota_start((ota_callback)OtaUpdate_CallBack, true)) {
		c_printf("rBoot: Updating...\n");
	} else {
		c_printf("rBoot: Updating failed!\n\n");
	}
	return 0;
}
#endif

// Lua: swap()
static int rboot_swap( lua_State* L ) {
  	uint8 rom;
	rom = rboot_get_current_rom();
	if (rom != 0) rom = 0;
	else rom = 1;
	rboot_set_current_rom(rom);
	system_restart();
	return 0;
}

// Module function map
#define MIN_OPT_LEVEL 2
#include "lrodefs.h"
const LUA_REG_TYPE rboot_map[] = {
	{ LSTRKEY( "swap" ), LFUNCVAL( rboot_swap) },
	{ LSTRKEY( "ota" ), LFUNCVAL( rboot_ota) },
#ifdef OTA_FS_ENABLED
	{ LSTRKEY( "otafs" ), LFUNCVAL( rboot_otafs) },
#endif
	{ LSTRKEY( "rom" ), LFUNCVAL( rboot_rom) },
	{ LNILKEY, LNILVAL }
};

NODEMCU_MODULE(RBOOT, "rboot", rboot_map, NULL);

