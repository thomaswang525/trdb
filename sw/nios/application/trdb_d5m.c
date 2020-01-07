/******************************************************************************
  trdb_d5m.c

  Author            : Andrea Caforio and Gabriel Tornare
  Revision          : 0.1
  Modification Date : 07/01/2020

  This file contains the implementations of the TRDB-D5M interaction
  functions as defined in the header file.
******************************************************************************/

#include "trdb_d5m.h"

void trdb_reset(i2c_dev *i2c) {
	bool ok = true;

	ok &= trdb_write(i2c, TRDB_D5M_I2C_REG_RESET, TRDB_D5M_I2C_RESET);
	ok &= trdb_write(i2c, TRDB_D5M_I2C_REG_RESET, TRDB_D5M_I2C_RESET_DEFAULT);

	assert(ok && "unable to reset trdb-d5m");
}

void trdb_restart(i2c_dev *i2c) {
	bool ok = true;

	ok &= trdb_write_part(i2c, TRDB_D5M_I2C_REG_RESTART, TRDB_D5M_I2C_RESTART, TRDB_D5M_I2C_RESTART_MASK);

	assert(ok && "unable to restart trdb-d5m");
}

void trdb_config(i2c_dev *i2c) {
	bool ok = true;

	ok &= trdb_write(i2c, TRDB_D5M_I2C_REG_FRAME_WIDTH, TRDB_D5M_I2C_FRAME_WIDTH);
	ok &= trdb_write(i2c, TRDB_D5M_I2C_REG_FRAME_HEIGHT, TRDB_D5M_I2C_FRAME_HEIGHT);
	ok &= trdb_write(i2c, TRDB_D5M_I2C_REG_SHUTTER, TRDB_D5M_I2C_SHUTTER);

	ok &= trdb_write_part(i2c, TRDB_D5M_I2C_REG_MIRROR, TRDB_D5M_I2C_MIRROR, TRDB_D5M_I2C_MIRROR_MASK);
	ok &= trdb_write_part(i2c, TRDB_D5M_I2C_REG_READ, TRDB_D5M_I2C_SNAP, TRDB_D5M_I2C_SNAP_MASK);

	ok &= trdb_write_part(i2c, TRDB_D5M_I2C_REG_ROW, TRDB_D5M_I2C_ROW_BIN, TRDB_D5M_I2C_ROW_BIN_MASK);
	ok &= trdb_write_part(i2c, TRDB_D5M_I2C_REG_ROW, TRDB_D5M_I2C_ROW_SKIP, TRDB_D5M_I2C_ROW_SKIP_MASK);
	ok &= trdb_write_part(i2c, TRDB_D5M_I2C_REG_COL, TRDB_D5M_I2C_COL_BIN, TRDB_D5M_I2C_COL_BIN_MASK);
	ok &= trdb_write_part(i2c, TRDB_D5M_I2C_REG_COL, TRDB_D5M_I2C_COL_SKIP, TRDB_D5M_I2C_COL_SKIP_MASK);

	ok &= trdb_write_part(i2c, 0x02D, 0x003F, TRDB_D5M_I2C_GAIN_MASK);
	ok &= trdb_write_part(i2c, 0x02C, 0x003F, TRDB_D5M_I2C_GAIN_MASK);
	ok &= trdb_write_part(i2c, 0x02B, 0x003F, TRDB_D5M_I2C_GAIN_MASK);
	ok &= trdb_write_part(i2c, 0x02E, 0x003F, TRDB_D5M_I2C_GAIN_MASK);

	assert(ok && "unable to configure trdb-d5m");
}

void trdb_restore(i2c_dev *i2c) {
	bool ok = true;

	ok &= trdb_write(i2c, TRDB_D5M_I2C_REG_FRAME_WIDTH, TRDB_D5M_I2C_FRAME_WIDTH_DEFAULT);
	ok &= trdb_write(i2c, TRDB_D5M_I2C_REG_FRAME_HEIGHT, TRDB_D5M_I2C_FRAME_HEIGHT_DEFAULT);

	ok &= trdb_write(i2c, TRDB_D5M_I2C_REG_ROW, TRDB_D5M_I2C_ROW_BIN_DEFAULT);
	ok &= trdb_write(i2c, TRDB_D5M_I2C_REG_COL, TRDB_D5M_I2C_COL_BIN_DEFAULT);
	ok &= trdb_write(i2c, TRDB_D5M_I2C_REG_SHUTTER, TRDB_D5M_I2C_SHUTTER_DEFAULT);
	ok &= trdb_write(i2c, TRDB_D5M_I2C_REG_READ, TRDB_D5M_I2C_READ_DEFAULT);
	ok &= trdb_write(i2c, TRDB_D5M_I2C_REG_MIRROR, TRDB_D5M_I2C_MIRROR_DEFAULT);

	assert(ok && "unable to restore trdb-d5m default register values");
}

bool trdb_read(i2c_dev *i2c, uint8_t register_offset, uint16_t *data) {
    uint8_t byte_data[2] = {0, 0};

    int success = i2c_read_array(i2c, TRDB_D5M_I2C_ADDRESS, register_offset, byte_data, sizeof(byte_data));

    if (success != I2C_SUCCESS) {
        return false;
    } else {
        *data = ((uint16_t) byte_data[0] << 8) + byte_data[1];
        return true;
    }
}

bool trdb_write(i2c_dev *i2c, uint8_t register_offset, uint16_t data) {
    uint8_t byte_data[2] = {(data >> 8) & 0xff, data & 0xff};

    int success = i2c_write_array(i2c, TRDB_D5M_I2C_ADDRESS, register_offset, byte_data, sizeof(byte_data));

    if (success != I2C_SUCCESS) {
        return false;
    } else {
        return true;
    }
}

bool trdb_write_part(i2c_dev *i2c, uint8_t register_offset, uint16_t data, uint16_t mask) {
	bool ok = true;
	uint16_t reg;

	ok &= trdb_read(i2c,  register_offset, &reg);
    reg &= ~mask;
    reg |= data & mask;
    ok &= trdb_write(i2c, register_offset, reg);

    return ok;
}

void trdb_dump(i2c_dev *i2c) {
	uint16_t width;   trdb_read(i2c, TRDB_D5M_I2C_REG_FRAME_WIDTH, &width);
	uint16_t height;  trdb_read(i2c, TRDB_D5M_I2C_REG_FRAME_HEIGHT, &height);
	uint16_t read;    trdb_read(i2c, TRDB_D5M_I2C_REG_READ, &read);
	uint16_t shutter; trdb_read(i2c, TRDB_D5M_I2C_REG_SHUTTER, &shutter);
	uint16_t mirror;  trdb_read(i2c, TRDB_D5M_I2C_REG_MIRROR, &mirror);

	printf("width:\t%d\n", width);
	printf("height:\t%d\n", height);
	printf("read:\t%04X\n", read);
	printf("shutter:\t%04X\n", shutter);
	printf("mirror:\t%04X\n", mirror);

	return;
}
