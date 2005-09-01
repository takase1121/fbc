/*
 *  libfb - FreeBASIC's runtime library
 *	Copyright (C) 2004-2005 Andre V. T. Vicentini (av1ctor@yahoo.com.br) and others.
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2.1 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

/*
 * io_cls.c -- cls (console, no gfx) function for Linux
 *
 * chng: jan/2005 written [lillo]
 *       feb/2005 rewritten to remove ncurses dependency [lillo]
 *
 */

#include "fb.h"
#include "fb_linux.h"


/*:::::*/
void fb_ConsoleClear( int mode )
{
	int start, end, i;
	
	if (!fb_con.inited)
		return;
	
	fb_hResize();
	
	fb_ConsoleGetView(&start, &end);
	if ((mode != 1) && (mode != 0xFFFF0000)) {
		start = 1;
		end = fb_ConsoleGetMaxRow();
	}
	for (i = start; i <= end; i++) {
		memset(fb_con.char_buffer + ((i - 1) * fb_con.w), ' ', fb_con.w);
		memset(fb_con.attr_buffer + ((i - 1) * fb_con.w), fb_con.fg_color | (fb_con.bg_color << 4), fb_con.w);
		fb_hTermOut(SEQ_LOCATE, 0, i-1);
		fb_hTermOut(SEQ_CLEOL, 0, 0);
	}
	fb_hTermOut(SEQ_HOME, 0, 0);
	fb_con.cur_y = start;
	fb_con.cur_x = 1;
}


