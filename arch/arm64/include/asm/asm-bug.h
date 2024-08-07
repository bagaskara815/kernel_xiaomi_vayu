#ifndef __ASM_ASM_BUG_H
/*
 * Copyright (C) 2017  ARM Limited
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
#define __ASM_ASM_BUG_H

#include <asm/brk-imm.h>

#ifdef CONFIG_DEBUG_BUGVERBOSE
#define _BUGVERBOSE_LOCATION(file, line) __BUGVERBOSE_LOCATION(file, line)
#define __BUGVERBOSE_LOCATION(file, line)			\
		.pushsection .rodata.str,"aMS",@progbits,1;	\
	2:	.string file;					\
		.popsection;					\
								\
		.long 2b - 0b;					\
		.short line;
#else
#define _BUGVERBOSE_LOCATION(file, line)
#endif

#ifdef CONFIG_GENERIC_BUG

#define __BUG_ENTRY(flags) 				\
		.pushsection __bug_table,"aw";		\
		.align 2;				\
	0:	.long 1f - 0b;				\
_BUGVERBOSE_LOCATION(__FILE__, __LINE__)		\
		.short flags; 				\
		.align 2;				\
		.popsection;				\
	1:
#else
#define __BUG_ENTRY(flags)
#endif

#define ASM_BUG_FLAGS(flags)				\
	__BUG_ENTRY(flags)				\
	brk	BUG_BRK_IMM

#define ASM_BUG()	ASM_BUG_FLAGS(0)

#endif /* __ASM_ASM_BUG_H */
