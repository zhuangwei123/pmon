/*
rules:
use #define to define varible
the varible is valid between #define and #undef. 
*/
#define TEST 1
#define SRAM_DATA0 0x1494
#define SDRAM_OPERATION                                     0x1418
#define DFCDL_CONFIG0                                       0x1480
#define DFCDL_CONFIG1                                       0x1484
#define SDRAM_MODE                                          0x141c
#define SDRAM_CONFIG	 				0x1400
#define SDRAM_OPEN_PAGES_CONTROL	0x1414
#define D_UNIT_CONTROL_LOW	0x1404
#define SDRAM_ADDR_CONTROL  0x1410
#define SDRAM_TIMING_CONTROL_LOW 0x1408
#define SDRAM_TIMING_CONTROL_HIGH 0x140c

#define GT_REGWR_R(offs, reg)		\
	sw	reg, GT_BASE_ADDR+(offs)

#define GT_REGRD(offs)			\
	lw	v0, GT_BASE_ADDR+(offs)

#define GT_REGWR(offs, value)		\
	li	v0, HTOLE32(value);	\
	sw	v0, GT_BASE_ADDR+(offs)
#ifdef FASTBOOT
#undef PRINTSTR
#define PRINTSTR(a)
#define HEXSERIAL nullfunction
#else
#define HEXSERIAL hexserial
#endif

#define I2C_RD_SPD(addr) \
    li  a0, 0x000|(addr);\
  	bal boot_i2c_read; \
	nop;

/*	
可能需要预先设置StBurstDel
*/
sdram_init:

	PRINTSTR("\r\nI2C data 0-31:\r\n");
	 li t2,0
1:
	 move a0, t2
	 bal  boot_i2c_read
	 nop
	 move a0,v0
	 bal  HEXSERIAL
	 nop
	 li   a0,'\r'
	 bal  tgt_putchar
	 nop
	 li   a0,'\n'
	 bal  tgt_putchar
	 nop
	 addiu t2,t2,1
	 li  a0, 31
	 bne t2,a0,1b
	 nop

	
#if 1
	/* set SDRAM mode NOP */ /* To_do check it */
	GT_REGWR(SDRAM_OPERATION, 0x5);

	1:
	GT_REGRD (SDRAM_OPERATION)
	beqz v0,1f;	
	nop
	TTYDBG("\n*** SDRAM_OPERATION 1418: Module still busy ... please wait... ***\n");
	b 1b
	nop
1:
#endif

//	I2C_RD_SPD(12) /*refresh rate*/
#define sdram_config s1
#define REFRESH_COUNTER 0x200
	li sdram_config,REFRESH_COUNTER
	I2C_RD_SPD(21) /*registered ddr?*/
	
	andi v0,v0,(1<<1)
	beqz v0,1f
	nop
	or sdram_config,(1<<17)
1:
	I2C_RD_SPD(11) /*ecc suported?*/
	li v1,2
	bne v0,v1,1f
	nop
	or sdram_config,(1<<18)
1:
	
	I2C_RD_SPD(13) /*ddr width*/

	li v1,4
	beq v0,v1,width4
	nop
	li v1,8
	beq v0,v1,width8_16
	nop
	li v1,16
	beq v0,v1,width8_16
	nop
width32:
	b width_end
	nop
width4:
	or sdram_config,3<<20
	b width_end
	nop
width8_16:
	or sdram_config,2<<20
width_end:
	or  sdram_config,1<<27 /*default read buffer*/
	or  sdram_config,1<<24 /* leave self refresh mode upon new requests */
	sw	sdram_config, GT_BASE_ADDR+(SDRAM_CONFIG)
#undef sdram_config
	GT_REGWR (SDRAM_OPEN_PAGES_CONTROL, 0x1);/*keep bank open if possible*/
	
#define registered t8
	I2C_RD_SPD(21); /* registered? */
	andi registered,v0,(1<<1)
	I2C_RD_SPD(18) /*supported lattency*/
#ifdef TEST
	b cas_3 /*Notice just for TEST*/
	nop
#endif
	andi v1,v0,1<<1
	bnez v1,cas_1_5
	nop
	andi v1,v0,1<<2
	bnez v1,cas_2
	nop
	andi v1,v0,1<<3
	bnez v1,cas_2_5
	nop
	andi v1,v0,1<<4
	bnez v1,cas_3
	nop
	andi v1,v0,1<<5
	bnez v1,cas_4
	nop
	b cas_2_5
	nop;
#define sdram_mode a2
#define dunit_ctrol_low a3
cas_4:
	li sdram_mode,0x42
	li dunit_ctrol_low,0xc6000540; /* registered and sync */
	bnez registered,cas_check_end
	nop
	li dunit_ctrol_low,0xc5000540 /* unregistered ans sync */
	b cas_check_end
	nop
cas_3:
	li sdram_mode,0x32
	li dunit_ctrol_low,0xc5000540; /* registered and sync */
	bnez registered,cas_check_end
	nop
	li dunit_ctrol_low,0xc4000540 /* unregistered ans sync */
	b cas_check_end
	nop
cas_2_5:
	li sdram_mode,0x62
	li dunit_ctrol_low,0xc5000540 /* registered and sync */
	bnez registered,cas_check_end
	nop
	li dunit_ctrol_low,0xc4000540 /* unregistered ans sync */
	b cas_check_end
	nop
cas_2:
	li sdram_mode,0x22
	li dunit_ctrol_low,0xc4000540 /* registered and sync */
	bnez registered,cas_check_end
	nop
	li dunit_ctrol_low,0xc3000540 /* unregistered ans sync */
	b cas_check_end
	nop
cas_1_5:
	li sdram_mode,0x52
	li dunit_ctrol_low,0xc4000540 /* registered and sync */
	bnez registered,cas_check_end
	nop
	li dunit_ctrol_low,0xc3000540 /* unregistered ans sync */
	b cas_check_end
	nop
cas_check_end:
#undef registered
	GT_REGRD (D_UNIT_CONTROL_LOW);
#define clock_sync s1
	andi clock_sync,v0,1	/*clock not sync*/
	beqz clock_sync,synced
	nop
	ori dunit_ctrol_low,1
	and dunit_ctrol_low,~(1<<8)
#undef clock_sync
synced:
	/* Write results of CL detection procedure */
	/* set SDRAM mode reg. 0x141c */
	GT_REGWR_R(SDRAM_MODE, sdram_mode);
#undef sdram_mode

#if 1
	/* set SDRAM modeSet Command 0x1418 */
	GT_REGWR (SDRAM_OPERATION, 0x3);
1:
	GT_REGRD (SDRAM_OPERATION)
	beqz v0,1f;	
	nop
	PRINTSTR("\n*** SDRAM_OPERATION 1418: Module still busy ... please wait... ***\n");
	b 1b
	nop
1:
#endif

/* SDRAM D_UNIT_CONTROL_LOW 0x1404 */
	GT_REGWR_R (D_UNIT_CONTROL_LOW, dunit_ctrol_low);

	/* set SDRAM modeSet Command 0x1418 */
	GT_REGWR (SDRAM_OPERATION, 0x3);
1:
	GT_REGRD (SDRAM_OPERATION)
	beqz v0,1f;	
	nop
	TTYDBG("\n*** SDRAM_OPERATION 1418: Module still busy ... please wait... ***\n");
	b 1b
	nop
1:

	GT_REGRD(0x1424);
	
	/*change WrBuff to 4*/
	and v0, 0xffffffff

	/*change WrTrig to 4*/
	and v0, 0xffff0333
	
	/*change 25:24 to 00*/
	and v0, 0xfcffffff

	GT_REGWR_R (0x1424, v0);

#define tmp t8
#define numOfRowAddresses t6
#define numOfColAddresses t7
	li tmp,0x02;
	I2C_RD_SPD(3)
	move numOfRowAddresses,v0
	I2C_RD_SPD(4)
	move numOfColAddresses,v0
	addu t0,numOfRowAddresses,numOfColAddresses
#define sdram_chip_size t7
	li t7,1
	sll sdram_chip_size,t7,t0	
#define sdramWidth v0
	I2C_RD_SPD(13) //width
	mult sdram_chip_size,sdramWidth
#undef sdramWidth
	mflo sdram_chip_size
	sll sdram_chip_size,2 /* 4 banks */
	/* divide sdram chip size by 64 Mbits */
	srl sdram_chip_size,sdram_chip_size,26
	li v1,1 /*64 M*/
	beq  sdram_chip_size,v1,I64_128M
	nop
	li v1,2 /*128 M*/
	beq  sdram_chip_size,v1,I64_128M
	nop
	li v1,4 /*256 M*/
	beq  sdram_chip_size,v1,I256_512M
	nop
	li v1,8 /*512 M*/
	beq  sdram_chip_size,v1,I256_512M
	nop
	li v1,16 /*1G*/
	beq  sdram_chip_size,v1,I1G_2G
	nop
	li v1,32 /*2G*/
	beq  sdram_chip_size,v1,I1G_2G
	nop
#undef sdram_chip_size
I64_128M:
	or tmp,tmp,0<<4
	b memsize_end
	nop
I256_512M:
	or tmp,tmp,1<<4
	b memsize_end
	nop
I1G_2G:
	or tmp,tmp,(0x02 << 4)
	b memsize_end
	nop
memsize_end:
GT_REGWR_R (SDRAM_ADDR_CONTROL, tmp);

/*the data bellow is very complex for caculation*/
GT_REGWR (SDRAM_TIMING_CONTROL_LOW, 0x01701420);
GT_REGWR (SDRAM_TIMING_CONTROL_HIGH, 0x9);

/*map window*/
/*
if(ecc)datawidth=datawidth(1-1/8);
1<<(rows+cols)*numOfbankOnChip*datawidth/8
*/

#define numOfRowAddresses t6
#define numOfColAddresses t7
	I2C_RD_SPD(3)
	move numOfRowAddresses,v0
	I2C_RD_SPD(4)
	move numOfColAddresses,v0
	addu t0,numOfRowAddresses,numOfColAddresses
	li t7,1
#define sdram_size t7
	sll sdram_size,t7,t0	
#define BANKS_ON_DEVICE_OFS 17
	I2C_RD_SPD(BANKS_ON_DEVICE_OFS)
	mult sdram_size,v0
	mflo sdram_size
#define module_width t6
#define MODULE_WIDTH_OFS 6
#define ECC_OFS 11
	I2C_RD_SPD(MODULE_WIDTH_OFS)
	move module_width,v0
	I2C_RD_SPD(ECC_OFS)
	li v1,1
	beq v0,v1,_ecc
	nop
	li v1,2
	beq v0,v1,_ecc
	nop
	li v1,3
	beq v0,v1,_ecc
	nop
	b _noecc
	nop
_ecc:
	srl v1,module_width,3
	subu module_width,v1
_noecc:
	mult sdram_size,module_width
#undef sdram_size
#define banksize a2
	mflo banksize
	srl  banksize,banksize,3

	/* clear banks */
	GT_REGWR(0x8,0);
	GT_REGWR(0x10,0);
	GT_REGWR(0x208,0);
	GT_REGWR(0x210,0);
	GT_REGWR(0x18,0);
	GT_REGWR(0x20,0);
	GT_REGWR(0x218,0);
	GT_REGWR(0x220,0);

#define bankno a0
#define bankbase a1
#define NUMS_MODULE_OFS 5
#define nums_modules s1
#define memsize t8
	I2C_RD_SPD(NUMS_MODULE_OFS)
	move nums_modules,v0
	li bankno,0
	li bankbase,0
	move memsize,banksize
1:
	bal map_bank
	nop
#define NUMS_MODULE_OFS 5
	subu nums_modules,1
	beqz nums_modules,_map_end
	nop
	addu memsize,banksize
	addu bankbase,bankbase,banksize
	addiu bankno,bankno,1
	b 1b
	nop
	
mem_ofs:
.word  8,0x208,0x18,0x218

LEAF(map_bank)
#define bankno a0
#define bankbase a1
#define banksize a2
#define link_offs s0
#define register_base s2
#define relocation s0
	la t7,mem_ofs
	sll t1,bankno,2
	addu t7,t1
	addu t7,relocation
	lw t6,(t7)
	addu t6,register_base
/*setup memory base address and size */
	srl t0,bankbase,16
	sw t0,(t6)
	addiu t0,banksize,-1
	srl t0,16
	sw t0,8(t6)
/*enable ddr memory window*/
	li t1,1
	sll t1,bankno
	not t1
	lw t0,BASE_ADDRESS_ENABLE_REG(register_base);	
	and t0,t1;
	sw t0,BASE_ADDRESS_ENABLE_REG(register_base);	
	jr ra
	nop
END(map_bank)
	
_map_end:
    /* save memsize to s1 register */
	move s1,memsize

#dump memory registers 
    PRINTSTR("memsize=");
	move a0,t8
	bal HEXSERIAL
	nop

	#undef memsize
	#undef bankno
	#undef bankbase
	#undef banksize

#if 1

	#define dfcdl_word t1
	//GT_REGWR(DFCDL_CONFIG0, 0x20300000);	/* enable dynamic delay line updating */
	//GT_REGWR(DFCDL_CONFIG0, 0x20377000);	/* enable dynamic delay line updating */

	 PRINTSTR("\r\npopulating DFCDL data sequence\r\n")
	 li t0, 0
	 GT_REGWR_R(SRAM_DATA0, t0);
	 li t0, 1
	 GT_REGWR_R(SRAM_DATA0, t0);
	 li t0, 2
	 GT_REGWR_R(SRAM_DATA0, t0);
	 li t7, 61
	 move  t8, t0
1:
	 addiu t8,t8,1
	 addiu t1,t8,-2
	 sll   t1,t1,6
	 or    t1,t1,t8
	 GT_REGWR_R(SRAM_DATA0, t1);
#if 0
	 move a0,t1
	 bal  HEXSERIAL
	 nop
	 li   a0,'\r'
	 bal  tgt_putchar
	 nop
	 li   a0,'\n'
	 bal  tgt_putchar
	 nop
#endif
	 addiu t7,t7,-1
	 bnez  t7,1b
	 nop

	#undef dfcdl_word
	
	GT_REGWR(DFCDL_CONFIG0, 0x00300000);	/* enable dynamic delay line updating */
#endif

#if 0

	#define dfcdl_word t1

	 PRINTSTR("\r\npopulating DFCDL data sequence\r\n")
	 li t0, 0
	 GT_REGWR_R(SRAM_DATA0, t0);
	 li t0, 1
	 GT_REGWR_R(SRAM_DATA0, t0);
	 li t0, 2
	 GT_REGWR_R(SRAM_DATA0, t0);
	 li t7, 29
	 move  t8, t0
1:
	 addiu t8,t8,1
	 addiu t1,t8,-2
	 sll   t1,t1,6
	 or    t1,t1,t8
	 GT_REGWR_R(SRAM_DATA0, t1);
#if 1
	 move a0,t1
	 bal  HEXSERIAL
	 nop
	 li   a0,'\r'
	 bal  tgt_putchar
	 nop
	 li   a0,'\n'
	 bal  tgt_putchar
	 nop
#endif
	 addiu t7,t7,-1
	 bnez  t7,1b
	 nop

	 li t7,32
1:
	 GT_REGWR_R(SRAM_DATA0, t1);
#if 1
	 move a0,t1
	 bal  HEXSERIAL
	 nop
	 li   a0,'\r'
	 bal  tgt_putchar
	 nop
	 li   a0,'\n'
	 bal  tgt_putchar
	 nop
#endif
	 addiu t7,t7,-1
	 bnez  t7,1b
	 nop

	#undef dfcdl_word
	
	GT_REGWR(DFCDL_CONFIG0, 0x00300000);	/* enable dynamic delay line updating */
#endif

    PRINTSTR("\r\nbank number=");
	I2C_RD_SPD(5)
	move a0,v0
	bal HEXSERIAL
	nop

    PRINTSTR("\r\nSDRAM_CONFIG=");
	GT_REGRD(SDRAM_CONFIG)
	move a0,v0
	bal HEXSERIAL
	nop
    PRINTSTR("\r\nSDRAM_ADDR_CONTROL=");
	GT_REGRD(SDRAM_ADDR_CONTROL);
	move a0,v0
	bal HEXSERIAL
	nop
    PRINTSTR("\r\nSDRAM_MODE=");
	GT_REGRD(SDRAM_MODE);
	move a0,v0
	bal HEXSERIAL
	nop
    PRINTSTR("\r\nSDRAM_TIMING_CONTROL_LOW=");
	GT_REGRD(SDRAM_TIMING_CONTROL_LOW);
	move a0,v0
	bal HEXSERIAL
	nop
    PRINTSTR("\r\nSDRAM_TIMING_CONTROL_HIGH=");
	GT_REGRD(SDRAM_TIMING_CONTROL_HIGH);
	move a0,v0
	bal HEXSERIAL
	nop
    PRINTSTR("\r\nD_UNIT_CONTROL_LOW=");
	GT_REGRD(D_UNIT_CONTROL_LOW);
	move a0,v0
	bal HEXSERIAL
	nop

    PRINTSTR("\r\nD_UNIT_CONTROL_HIGH=");
	GT_REGRD(0x1424);
	move a0,v0
	bal HEXSERIAL
	nop

    PRINTSTR("\r\naddress enable reg=");
	GT_REGRD(BASE_ADDRESS_ENABLE_REG);
	move a0,v0
	bal HEXSERIAL
	nop

    PRINTSTR("\r\nbank0 base=");
	GT_REGRD(8);
	sll a0,v0,16
	bal HEXSERIAL
	nop
    PRINTSTR("\r\nbank0 size=");
	GT_REGRD(0x10);
	sll a0,v0,16
	bal HEXSERIAL
	nop

    PRINTSTR("\r\nbank1 base=");
	GT_REGRD(0x208);
	sll a0,v0,16
	bal HEXSERIAL
	nop
    PRINTSTR("\r\nbank1 size=");
	GT_REGRD(0x210);
	sll a0,v0,16
	bal HEXSERIAL
	nop

    PRINTSTR("\r\nbank2 base=");
	GT_REGRD(0x18);
	sll a0,v0,16
	bal HEXSERIAL
	nop
    PRINTSTR("\r\nbank2 size=");
	GT_REGRD(0x20);
	sll a0,v0,16
	bal HEXSERIAL
	nop

    PRINTSTR("\r\nbank3 base=");
	GT_REGRD(0x218);
	sll a0,v0,16
	bal HEXSERIAL
	nop
    PRINTSTR("\r\nbank3 size=");
	GT_REGRD(0x220);
	sll a0,v0,16
	bal HEXSERIAL
	nop

    PRINTSTR("\r\ndev bank0 base=");
	GT_REGRD(0x28);
	sll a0,v0,16
	bal HEXSERIAL
	nop
    PRINTSTR("\r\ndev bank0 size=");
	GT_REGRD(0x30);
	sll a0,v0,16
	bal HEXSERIAL
	nop

    PRINTSTR("\r\ndev bank1 base=");
	GT_REGRD(0x228);
	sll a0,v0,16
	bal HEXSERIAL
	nop
    PRINTSTR("\r\ndev bank1 size=");
	GT_REGRD(0x230);
	sll a0,v0,16
	bal HEXSERIAL
	nop

    PRINTSTR("\r\ndev bank2 base=");
	GT_REGRD(0x248);
	sll a0,v0,16
	bal HEXSERIAL
	nop
    PRINTSTR("\r\ndev bank2 size=");
	GT_REGRD(0x250);
	sll a0,v0,16
	bal HEXSERIAL
	nop

    PRINTSTR("\r\ndev bank3 base=");
	GT_REGRD(0x38);
	sll a0,v0,16
	bal HEXSERIAL
	nop
    PRINTSTR("\r\ndev bank3 size=");
	GT_REGRD(0x40);
	sll a0,v0,16
	bal HEXSERIAL
	nop

    PRINTSTR("\r\nbootcs base=");
	GT_REGRD(0x238);
	sll a0,v0,16
	bal HEXSERIAL
	nop
    PRINTSTR("\r\nbootcs size=");
	GT_REGRD(0x240);
	sll a0,v0,16
	bal HEXSERIAL
	nop

    PRINTSTR("\r\pci io base=");
	GT_REGRD(0x48);
	sll a0,v0,16
	bal HEXSERIAL
	nop
    PRINTSTR("\r\npci size=");
	GT_REGRD(0x50);
	sll a0,v0,16
	bal HEXSERIAL
	nop

    PRINTSTR("\r\npci bank0 base=");
	GT_REGRD(0x58);
	sll a0,v0,16
	bal HEXSERIAL
	nop
    PRINTSTR("\r\npci bank0 size=");
	GT_REGRD(0x60);
	sll a0,v0,16
	bal HEXSERIAL
	nop

    PRINTSTR("\r\npci bank1 base=");
	GT_REGRD(0x80);
	sll a0,v0,16
	bal HEXSERIAL
	nop
    PRINTSTR("\r\npci bank1 size=");
	GT_REGRD(0x88);
	sll a0,v0,16
	bal HEXSERIAL
	nop

    PRINTSTR("\r\npci bank2 base=");
	GT_REGRD(0x258);
	sll a0,v0,16
	bal HEXSERIAL
	nop
    PRINTSTR("\r\npci bank2 size=");
	GT_REGRD(0x260);
	sll a0,v0,16
	bal HEXSERIAL
	nop

    PRINTSTR("\r\npci bank3 base=");
	GT_REGRD(0x280);
	sll a0,v0,16
	bal HEXSERIAL
	nop
    PRINTSTR("\r\npci bank3 size=");
	GT_REGRD(0x288);
	sll a0,v0,16
	bal HEXSERIAL
	nop

    PRINTSTR("\r\ninternal space base=");
	GT_REGRD(0x68);
	sll a0,v0,16
	bal HEXSERIAL
	nop

    PRINTSTR("\r\nsdramXmode");
	GT_REGRD(0x1420);
	move a0,v0
	bal HEXSERIAL
	nop

    PRINTSTR("\r\ncrossbar control low");
	GT_REGRD(0x1430);
	move a0,v0
	bal HEXSERIAL
	nop

    PRINTSTR("\r\ncrossbar control high");
	GT_REGRD(0x1434);
	move a0,v0
	bal HEXSERIAL
	nop

    PRINTSTR("\r\npad control");
	GT_REGRD(0x14c0);
	move a0,v0
	bal HEXSERIAL
	nop

    PRINTSTR("\r\nDFCDL conf0");
	GT_REGRD(0x1480);
	move a0,v0
	bal HEXSERIAL
	nop

    PRINTSTR("\r\nDFCDL conf1");
	GT_REGRD(0x1484);
	move a0,v0
	bal HEXSERIAL
	nop

    PRINTSTR("\r\n");


//initdram先运行.
