/*
 * Bonito Register Map 
 * Copyright (c) 1999 Algorithmics Ltd
 *
 * Algorithmics gives permission for anyone to use and modify this file
 * without any obligation or license condition except that you retain
 * this copyright message in any source redistribution in whole or part.
 *
 * Updated copies of this and other files can be found at
 * ftp://ftp.algor.co.uk/pub/bonito/
 * 
 * Users of the Bonito controller are warmly recommended to contribute
 * any useful changes back to Algorithmics (mail to
 * bonito@algor.co.uk).
 */

/* Revision 1.48 autogenerated on 08/17/99 15:20:01 */

#ifndef _FCR_H__

#ifdef __ASSEMBLER__
#else /* !__ASSEMBLER */
extern char           *heaptop;

#endif /* __ASSEMBLER__ */

/* APB bus control registers */
#define APB_MISC_BASE 0x1f004100

#define GPIO_OE28_0    0x00
#define GPIO_R28_0     0x10
#define GPIO_W28_0     0x20
#define APB_MISC_CTL   0x40


/*
#define GPIO_OE47_20	0x00
#define GPIO_OE77_48	0x08
#define GPIO_R47_20	0x10
#define GPIO_R77_48	0x18
#define GPIO_W47_20	0x20
#define GPIO_W77_48	0x28
#define APB_MISC_CTL	0x40
*/
#define AHB_MISC_BASE 0x1f003200

#define GPIO_OE60_29	0x20
#define GPIO_R60_29	0x24
#define GPIO_W60_29	0x28



#define RTC_INDEX_REG 0x70
#define RTC_DATA_REG 0x71
#define RTC_NVRAM_BASE		0x0e

#ifndef UART_BASE_ADDR
#ifdef IPCAMERA
	#define	COM1_BASE_ADDR	0xbfe4c000
#else
	#define COM1_BASE_ADDR	0xbfe48000
#endif
#else
#define COM1_BASE_ADDR	UART_BASE_ADDR
#endif
//#define COM1_BASE_ADDR	0xbfe48000		//1B uart8 主串口
#define COM2_BASE_ADDR	0xbfd003f8
#define COM3_BASE_ADDR	0xbfe48000		//1B uart0
//#define COM3_BASE_ADDR	0xbfe4c000		//1B uart9
//#define COM3_BASE_ADDR	0xbfe6c000		//1B uart10

#define	NS16550HZ	(APB_CLK/4)
/*********************************************************************/
/*nvram define                                                       */
/*********************************************************************/
#if 0

#ifdef NVRAM_IN_FLASH
#	define	NVRAM_SIZE		494
#	define	NVRAM_SECSIZE		500
#	define	NVRAM_OFFS		0x00070000
#	define ETHER_OFFS		494 	/* Ethernet address base */
#else	/* Use clock ram, 256 bytes only */
#	define NVRAM_SIZE	        512	
#	define NVRAM_SECSIZE		NVRAM_SIZE	/* Helper */
#	define NVRAM_OFFS		0
#	define ETHER_OFFS		(NVRAM_SIZE-6) 	/* Ethernet address base */
#endif

#else

#ifdef NVRAM_IN_FLASH
#	define	NVRAM_SIZE		512
#	define	NVRAM_SECSIZE		0x10000
#	define	NVRAM_OFFS		0x00070000
#	define	NVRAM_POS		NVRAM_OFFS
#	define ETHER_OFFS		(NVRAM_SIZE-6) 	/* Ethernet address base */
#	define PLL_OFFS			(ETHER_OFFS-10)
#	define XRES_OFFS		(PLL_OFFS-2)
#	define YRES_OFFS		(PLL_OFFS-4)
#	define DEPTH_OFFS		(PLL_OFFS+8)
#else	/* Use clock ram, 256 bytes only */
#	define NVRAM_SECSIZE		512	/* Helper */
#	define NVRAM_SIZE	        (NVRAM_SECSIZE-20)
#	define NVRAM_OFFS		0
#	define NVRAM_POS	    0x00070000
//#	define NVRAM_POS	    0x000F0000	//当PMON大小超过512K时需要修改该值,保留给环境变量的大小为0x10000=65536字节
                                        //如果SPI Flash大小为1MB，则NVRAM_POS=0x00100000-0x00010000=0x000F0000
#	define ETHER_OFFS		(NVRAM_SECSIZE-6) 	/* Ethernet address base */
#	define PLL_OFFS			(ETHER_OFFS-10)
#	define XRES_OFFS		(PLL_OFFS-2)
#	define YRES_OFFS		(PLL_OFFS-4)
#	define DEPTH_OFFS		(PLL_OFFS+8)
#endif

#endif
/*********************************************************************/
/*PCI map	                                                     */
/*********************************************************************/

#ifdef X86_LIKE_SPACE
/* To make address spaces alike with x86 system, we put sdram
 * start address at 0 and pci devices' start address at 0x14000000 for
 * both CPU address space & PCI memory address space.
 *
 * We have 3 64M window in CPU address space to access PCI memory,but the
 * legacy PCI  start pci memory from 0x10000000, so we can use the same address to access
 * them from cpu memory space. But to access the 0xc0000 vga ram, we have to
 * reserve the first window. Only the last two are used for pci devices. 
 * --zfx 060716
 */
/* make sdram appear at both cpu & pci memory space 0,
 * so for dma the physical address can be directly used 
 * as bus address. --zfx 060716
 */

#define PCI_MEM_SPACE_PCI_BASE		0x10000000
#define PCI_LOCAL_MEM_PCI_BASE		0x00000000
#define PCI_LOCAL_MEM_ISA_BASE		0x80000000
#define PCI_LOCAL_REG_PCI_BASE		0x90000000

#else

#define PCI_MEM_SPACE_PCI_BASE		0x00000000
#define PCI_LOCAL_MEM_PCI_BASE		0x80000000
#define PCI_LOCAL_MEM_ISA_BASE		0x00800000
#define PCI_LOCAL_REG_PCI_BASE		0x90000000

#endif

#define PCI_IO_SPACE_BASE		0x00000000

#endif /* _BONITO_H_ */
