/******************************************************************************
  trdb_d5m.h

  Author            : Andrea Caforio and Gabriel Tornare
  Revision          : 0.1
  Modification Date : 07/01/2020

  This file contains defines the relevant TRDB-D5M registers and its
  value as well as the functions to interact with them.
******************************************************************************/

#ifndef TRDB_D5M_H_
#define TRDB_D5M_H_

#include <inttypes.h>
#include <stdlib.h>
#include <stdbool.h>
#include <stdio.h>
#include <assert.h>

#include "system.h"
#include "io.h"

#include "i2c/i2c.h"

#define TRDB_D5M_I2C_BASE    ((void*)(0x10000808))
#define TRDB_D5M_I2C_FREQ    (50000000)
#define TRDB_D5M_I2C_ADDRESS (0xba)

#define TRDB_D5M_I2C_FRAME_WIDTH_DEFAULT  (0x0A1F)
#define TRDB_D5M_I2C_FRAME_HEIGHT_DEFAULT (0x0797)
#define TRDB_D5M_I2C_FRAME_WIDTH          (2559)
#define TRDB_D5M_I2C_FRAME_HEIGHT         (1919)
#define TRDB_D5M_I2C_REG_FRAME_WIDTH      (0x04)
#define TRDB_D5M_I2C_REG_FRAME_HEIGHT     (0x03)

#define TRDB_D5M_I2C_ROW_BIN_DEFAULT (0x0000)
#define TRDB_D5M_I2C_ROW_BIN         (0x0030)
#define TRDB_D5M_I2C_ROW_BIN_MASK    (0x0030)
#define TRDB_D5M_I2C_ROW_SKIP        (0x0003)
#define TRDB_D5M_I2C_ROW_SKIP_MASK   (0x0007)
#define TRDB_D5M_I2C_REG_ROW         (0x22)

#define TRDB_D5M_I2C_COL_BIN_DEFAULT (0x0000)
#define TRDB_D5M_I2C_COL_BIN         (0x0030)
#define TRDB_D5M_I2C_COL_BIN_MASK    (0x0030)
#define TRDB_D5M_I2C_COL_SKIP        (0x0003)
#define TRDB_D5M_I2C_COL_SKIP_MASK   (0x0007)
#define TRDB_D5M_I2C_REG_COL         (0x23)

#define TRDB_D5M_I2C_SHUTTER_DEFAULT (0x0797)
#define TRDB_D5M_I2C_SHUTTER         (0x01DE)
#define TRDB_D5M_I2C_SHUTTER_MASK    (0xFFFF)
#define TRDB_D5M_I2C_REG_SHUTTER     (0x009)

#define TRDB_D5M_I2C_READ_DEFAULT (0x4006)
#define TRDB_D5M_I2C_SNAP         (0x0100)
#define TRDB_D5M_I2C_SNAP_MASK    (0x0100)
#define TRDB_D5M_I2C_REG_READ     (0x01E)

#define TRDB_D5M_I2C_RESET         (0x0051)
#define TRDB_D5M_I2C_RESET_DEFAULT (0x0050)
#define TRDB_D5M_I2C_REG_RESET     (0x00D)

#define TRDB_D5M_I2C_RESTART      (0x0001)
#define TRDB_D5M_I2C_RESTART_MASK (0x0001)
#define TRDB_D5M_I2C_REG_RESTART  (0x00B)

#define TRDB_D5M_I2C_TRIGGER       (0x0004)
#define TRDB_D5M_I2C_TRIGGER_MASK  (0x0004)
#define TRDB_D5M_I2C_REG_TRIGGER   (0x00B)

#define TRDB_D5M_I2C_MIRROR_DEFAULT (0x0040)
#define TRDB_D5M_I2C_MIRROR         (0xC000)
#define TRDB_D5M_I2C_MIRROR_MASK    (0xC000)
#define TRDB_D5M_I2C_REG_MIRROR     (0x020)

#define TRDB_D5M_I2C_GAIN      (0x001F)
#define TRDB_D5M_I2C_GAIN_MASK (0x003F)
#define TRDB_D5M_I2C_REG_GAIN  (0x02D)

/** Write-bit a 16-bit value to a register. */
bool trdb_write(i2c_dev *i2c, uint8_t register_offset, uint16_t data);
/** Write a partial, masked value to a register. */
bool trdb_write_part(i2c_dev *i2c, uint8_t register_offset, uint16_t data, uint16_t mask);
/** Read a full 16 bits from a register. */
bool trdb_read(i2c_dev *i2c, uint8_t register_offset, uint16_t *data);

/** Reset all the registers. */
void trdb_reset(i2c_dev *i2c);

/** Configure the registers with the values above. */
void trdb_config(i2c_dev *i2c);

/** Restore all registers to their default value. */
void trdb_restore(i2c_dev *i2c);

/** Print all register values to stdout. */
void trdb_dump(i2c_dev *i2c);

#endif /* TRDB_D5M_H_ */
