/*
 *  libfb - FreeBASIC's runtime library
 *	Copyright (C) 2004-2005 Andre Victor T. Vicentini (av1ctor@yahoo.com.br)
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
 * str_bin_lng.c -- bin$ routine for long long's
 *
 * chng: apr/2005 written [v1ctor]
 *
 */

#include <malloc.h>
#include <stdlib.h>
#include "fb.h"

#ifndef TARGET_WIN32
/*:::::*/
static void hToBin( unsigned long long num, char *dst )
{
	int i, iszero = 1;

	for( i = 0; i < sizeof( long long )*8; i++ )
	{
		if( num & 0x8000000000000000ULL )
		{
			*dst++ = '1';
			iszero = 0;
		}
		else if( !iszero )
			*dst++ = '0';

		num <<= 1;
	}

	*dst = '\0';

}
#endif

/*:::::*/
FBCALL FBSTRING *fb_BIN_l ( unsigned long long num )
{
	FBSTRING 	*dst;

	FB_STRLOCK();

	/* alloc temp string */
	dst = (FBSTRING *)fb_hStrAllocTmpDesc( );
	if( dst != NULL )
	{
		fb_hStrAllocTemp( dst, sizeof( long long ) * 8 );

		/* convert */
#ifdef TARGET_WIN32
		_i64toa( num, dst->data, 2 );
#else
		hToBin( num, dst->data );
#endif

		dst->len = strlen( dst->data );				/* fake len */
		dst->len |= FB_TEMPSTRBIT;
	}
	else
		dst = &fb_strNullDesc;

	FB_STRUNLOCK();

	return dst;
}
