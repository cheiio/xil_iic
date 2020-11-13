

/***************************** Include Files *******************************/
#include "axi_iic-master.h"

/************************** Function Definitions ***************************/
void xil_iic_write(uint32_t axi_addr, uint8_t iic_addr, uint8_t buff_size, uint8_t* buffer){
	// Build Axi_data with addres and buff_size and send xil_io
	uint32_t axi_data = 0;
	uint8_t rw = 0;
	axi_data = buff_size << 8 | iic_addr | rw;
	Xil_Out32(axi_addr + R0_Offset, axi_data);

	// Build axi_data with buffer and send xil_io
	axi_data = 0;
	for (uint8_t i=0; i<buff_size; i++){
		axi_data = axi_data << 8;
		axi_data = axi_data | buffer[i];
	}
	
	Xil_Out32(ADS_AXI_ADDR + R1_Offset, axi_data);

	// Wait Axi iic module
	xil_iic_wait(axi_addr);
}

void xil_iic_read(uint32_t axi_addr, uint8_t iic_addr, uint8_t buff_size, uint8_t* buffer){
	// Build Axi_data with addres and buff_size and send xil_io
	uint8_t i;
	uint32_t axi_data = 0;
	uint8_t rw = 1;
	axi_data = buff_size << 8 | iic_addr | rw;
	Xil_Out32(axi_addr | R0_Offset, axi_data);
	usleep(1);

	// Wait Axi iic module
	xil_iic_wait(axi_addr);

	// Read Axi Register with sed data
	axi_data = Xil_In32(axi_addr | R2_Offset);
	for (i=buff_size; i--; i>0){
		buffer[i-1] = axi_data >> (i-1)*8-1;
	}
}

void xil_iic_wait(uint32_t axi_addr){
	uint8_t flag = 1;
	while (flag == 1){
		uint32_t axi_data_in = Xil_In32(axi_addr | R0_Offset);
		usleep(1);
		if (axi_data_in >> 31 == 0){
			flag = 0;
		}
	}
}

void clear_buffer(uint8_t* buffer, uint8_t buff_size){
	for(uint8_t i=0; i++; i<buff_size-1){
		buffer[i] = 0;
	}
}
