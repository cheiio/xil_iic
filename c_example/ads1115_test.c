/******************************************************************************
*
* Copyright (C) 2009 - 2014 Xilinx, Inc.  All rights reserved.
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* Use of the Software is limited solely to applications:
* (a) running on a Xilinx device, or
* (b) that interact with a Xilinx device through a bus or interconnect.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
* XILINX  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
* WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
* OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*
* Except as contained in this notice, the name of the Xilinx shall not be used
* in advertising or otherwise to promote the sale, use or other dealings in
* this Software without prior written authorization from Xilinx.
*
******************************************************************************/

/*
 * helloworld.c: simple test application
 *
 * This application configures UART 16550 to baud rate 9600.
 * PS7 UART (Zynq) is not initialized by this application, since
 * bootrom/bsp configures it to baud rate 115200
 *
 * ------------------------------------------------
 * | UART TYPE   BAUD RATE                        |
 * ------------------------------------------------
 *   uartns550   9600
 *   uartlite    Configurable only in HW design
 *   ps7_uart    115200 (configured by bootrom/bsp)
 */

#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "xparameters.h"
#include "xil_io.h"
#include "axi_iic-master.h"

// AXI IIC Master Reg
#define ADS_AXI_ADDR	XPAR_AXI_IIC_MASTER_0_S00_AXI_BASEADDR

// ADS1115 Reg
#define ADS_ADDR 		0x90 // IIC ADDRESS of ADS1115
#define P0 				0x00 // Conversion Reg
#define P1 				0x01 // Config Reg
#define P2 				0x02 // Lo_tresh Reg
#define P3 				0x03 // Hi_tresh Reg

// COnstants
#define mask_24msb		0xFFFFFF00

//@ Config Register Fields
//{
uint8_t OS = 0x1; 			// bit 15
uint8_t MUX = 0x4;			// bit 14-12
uint8_t PGA = 0x2;			// bit 11-9
uint8_t MODE = 0x1;			// bit 8
uint8_t DR = 0x7;			// bit 7-5
uint8_t COMP_MODE = 0x1;	// bit 4
uint8_t COMP_POL = 0x0;		// bit 3
uint8_t COMP_LAT = 0x0;		// bit 2
uint8_t COMP_QUE = 0x3;		// bit 1-0
//}

int main()
{
    init_platform();
    print("\n\r---- Test AXI IIC Master with ADS1115\n\r");

    while (1){
		uint8_t rw = 0; 			// rw bit
		uint16_t conf_reg = 0;	// configuration register

		uint8_t buffer[4];		// io buffer (max size = 4)
		uint8_t buff_size; 		// buffer size
		uint32_t axi_data = 0;

		// Build Configuration Register
		conf_reg = conf_reg | OS << 15;
		conf_reg = conf_reg | MUX << 12;
		conf_reg = conf_reg | PGA << 9;
		conf_reg = conf_reg | MODE << 8;
		conf_reg = conf_reg | DR << 5;
		conf_reg = conf_reg | COMP_MODE << 4;
		conf_reg = conf_reg | COMP_POL << 3;
		conf_reg = conf_reg | COMP_LAT << 2;
		conf_reg = conf_reg | COMP_QUE;

		//-------------------------- Writing to ADS ----------------------------------
		clear_buffer(buffer, 4);
		buff_size = 3;
		buffer[2] = conf_reg;
		buffer[1] = conf_reg >> 8;
		buffer[0] = P1;
		xil_iic_write(ADS_AXI_ADDR, ADS_ADDR, buff_size, buffer);

		//-------------------------- Reading from ADS ----------------------------------
		clear_buffer(buffer, 4);
		buff_size = 1;
		buffer[0] = P0;
		xil_iic_write(ADS_AXI_ADDR, ADS_ADDR, buff_size, buffer);

		clear_buffer(buffer, 4);
		buff_size = 2;
		xil_iic_read(ADS_AXI_ADDR, ADS_ADDR, buff_size, buffer);

		usleep(10000);
    }

	cleanup_platform();
    return 0;
}