/******************************************************************************
  main.c

  Author            : Andrea Caforio and Gabriel Tornare
  Revision          : 0.1
  Modification Date : 07/01/2020

  This file contains the main function of the TRDB-D5M NIOS2 process.
******************************************************************************/

#include <stdio.h>
#include <inttypes.h>

#include "system.h"
#include "io.h"

#include "i2c/i2c.h"
#include "i2c/i2c.c"

#include "trdb_d5m.h"

/** Programmable interface register offsets. */
#define PI_WIDTH       (4)
#define PI_REG_RESET   (0*PI_WIDTH)
#define PI_REG_ADDRESS (1*PI_WIDTH)
#define PI_REG_SIZE    (2*PI_WIDTH)
#define PI_REG_READY   (3*PI_WIDTH)
#define PI_REG_TRIGGER (4*PI_WIDTH)

/**
 * ppm_dump reads a raw 320x240 565-RGB, with blue at bit 0, picture
 * from memory and converts into the viewable PPM format. Note this
 * function may block for several seconds.
 *
 * Code taken from http://rosettacode.org/wiki/Bitmap/Write_a_PPM_file#C
 */
void ppm_dump(uint32_t offset, char *filename) {
  const int x = 320, y = 240;

  uint32_t base = HPS_0_BRIDGES_BASE;

  FILE *fp = fopen(filename, "wb");
  fprintf(fp, "P6\n%d %d\n255\n", x, y); // ppm version 6 header

  for (int i = 0; i < x; i++) {
	  printf("%d\n", i); // row progress indicator
      for (int j = 0; j < y; j++) {
          uint16_t pixel = IORD_16DIRECT(base, offset);

          // shift individual colors into focus and increase their intensity
          uint8_t color[3] = {0x0};
          color[2] = ((pixel >> 11) & 0x1F) << 3; // red
          color[1] = ((pixel >> 5) & 0x3F) << 2;  // green
          color[0] = ((pixel >> 0) & 0x1F) << 3;  // blue

          fwrite(color, 1, 3, fp);

          offset += 2;
      }
  }
  fclose(fp);

  return;
}

/**
 * api_dump prints all the registers of the programmable interface
 * to stdout. The API consists of four registers:
 *
 *   - address:	32-bit read-write
 *   - size:	32-bit read-write
 *   - trigger:	1-bit read-write
 *   - ready:	1-bit read-only
 */
void api_dump(void) {
	uint32_t addr = IORD_32DIRECT(CAMERA_MODULE_0_BASE, PI_REG_ADDRESS);
	uint32_t size = IORD_32DIRECT(CAMERA_MODULE_0_BASE, PI_REG_SIZE);
	uint32_t ready = IORD_32DIRECT(CAMERA_MODULE_0_BASE, PI_REG_READY) & 0x1;
	uint32_t trigger = IORD_32DIRECT(CAMERA_MODULE_0_BASE, PI_REG_TRIGGER) & 0x1;

	printf("base:\t%08lX\n", addr);
	printf("size:\t%08lX\n", size);
	printf("ready:\t%08lX\n", ready);
	printf("trigger:\t%08lX\n", trigger);

	return;
}

/**
 * trdb_init initializes and returns the i2c object handler through
 * which the TRDB-D5M registers can be accessed.
 *
 * Note that due to a strange Eclipse Makefile bug this function cannot
 * be place alongside the other TRDB-D5M routines in the trdb_d5m.h header.
 */
i2c_dev trdb_init(void) {
	i2c_dev i2c = i2c_inst(TRDB_D5M_I2C_BASE);

	i2c_init(&i2c, TRDB_D5M_I2C_FREQ);
	i2c_configure(&i2c, false);

	return i2c;
}

/**
 * api_init initializes the registers of the master-slave unit.
 */
void api_init(uint32_t addr) {
	IOWR_32DIRECT(CAMERA_MODULE_0_BASE, PI_REG_ADDRESS, addr);
	IOWR_32DIRECT(CAMERA_MODULE_0_BASE, PI_REG_SIZE, 320*240/2);

	return;
}

/**
 * trigger_sensor triggers a new frame capture of in both the master-slave unit
 * and the TRDB-D5M module.
 */
void trigger_sensor(i2c_dev *i2c) {
	IOWR_32DIRECT(CAMERA_MODULE_0_BASE, PI_REG_TRIGGER, 0x0);

	// The trigger pin of the TRDB-D5M does not work correctly, hence
	// this is a *ugly* through the trigger register.
	trdb_write_part(i2c, TRDB_D5M_I2C_REG_TRIGGER, TRDB_D5M_I2C_TRIGGER, TRDB_D5M_I2C_TRIGGER_MASK);
	trdb_write_part(i2c, TRDB_D5M_I2C_REG_TRIGGER, 0x0, TRDB_D5M_I2C_TRIGGER_MASK);

	return;
}

/**
 * loop is the main program loop that takes care of triggering the
 * capture of new frames.
 */
void loop(i2c_dev *i2c) {
	for (int i = 0; i < 10; i++) {
		IOWR_32DIRECT(CAMERA_MODULE_0_BASE, PI_REG_ADDRESS, 0);

		trigger_sensor(i2c);
		while (!(IORD_32DIRECT(CAMERA_MODULE_0_BASE, PI_REG_READY) & 0x1));

		IOWR_32DIRECT(CAMERA_MODULE_0_BASE, PI_REG_ADDRESS, 153600);

		trigger_sensor(i2c);
		while (!(IORD_32DIRECT(CAMERA_MODULE_0_BASE, PI_REG_READY) & 0x1));

		IOWR_32DIRECT(CAMERA_MODULE_0_BASE, PI_REG_ADDRESS, 2*153600);

		trigger_sensor(i2c);
		while (!(IORD_32DIRECT(CAMERA_MODULE_0_BASE, PI_REG_READY) & 0x1));
	}

	IOWR_32DIRECT(CAMERA_MODULE_0_BASE, PI_REG_ADDRESS, 3*153600);
	trigger_sensor(i2c);

	return;
}

int main(void) {
	api_init(HPS_0_BRIDGES_BASE);
	i2c_dev i2c = trdb_init();

	trdb_reset(&i2c);

	trdb_config(&i2c);
	trdb_dump(&i2c);

	//loop(&i2c);

	trigger_sensor(&i2c);
	ppm_dump(0, "/mnt/host/image.ppm");

//	dump_ppm(0, "/mnt/host/image1.ppm");
//	dump_ppm(153600, "/mnt/host/image2.ppm");
//	dump_ppm(2*153600, "/mnt/host/image3.ppm");
	//ppm_dump(3*153600, "/mnt/host/test.ppm");

	return 0;
}
