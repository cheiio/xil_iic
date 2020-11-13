
#ifndef AXI_IIC-MASTER_H
#define AXI_IIC-MASTER_H


/****************** Include Files ********************/
#include "xil_types.h"
#include "xstatus.h"
#include "xparameters.h"
#include "xil_io.h"

// AXI IIC Master Reg
#define R0_Offset		0x0
#define R1_Offset		0x4
#define R2_Offset		0x8
#define R3_Offset		0xC


/**************************** Type Definitions *****************************/
void xil_iic_write(uint32_t, uint8_t, uint8_t, uint8_t*);
void xil_iic_read(uint32_t, uint8_t, uint8_t, uint8_t*);
void xil_iic_wait(uint32_t);

void clear_buffer(uint8_t*, uint8_t);

#endif // AXI_IIC-MASTER_H
