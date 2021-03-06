type UDT1
	i as integer
end type

type UDT2
	i as integer
end type

type FWDREF1 as FWDREF1_
type FWDREF2 as FWDREF2_

dim b     as sub( byval as byte      )
dim ub    as sub( byval as ubyte     )
dim sh    as sub( byval as short     )
dim ush   as sub( byval as ushort    )
dim l     as sub( byval as long      )
dim ul    as sub( byval as ulong     )
dim ll    as sub( byval as longint   )
dim ull   as sub( byval as ulongint  )
dim i     as sub( byval as integer   )
dim ui    as sub( byval as uinteger  )
dim f     as sub( byval as single    )
dim d     as sub( byval as double    )
dim s     as sub( byval as string    )
dim udt1  as sub( byval as UDT1      )
dim udt2  as sub( byval as UDT2      )
dim psub  as sub( byval as sub( )    )
dim pfi   as sub( byval as function( ) as integer )
dim pany  as sub( byval as any      ptr )
dim pb    as sub( byval as byte     ptr )
dim pub   as sub( byval as ubyte    ptr )
dim psh   as sub( byval as short    ptr )
dim push  as sub( byval as ushort   ptr )
dim pl    as sub( byval as long     ptr )
dim pul   as sub( byval as ulong    ptr )
dim pll   as sub( byval as longint  ptr )
dim pull  as sub( byval as ulongint ptr )
dim pi    as sub( byval as integer  ptr )
dim pui   as sub( byval as uinteger ptr )
dim pf    as sub( byval as single   ptr )
dim pd    as sub( byval as double   ptr )
dim ps    as sub( byval as string   ptr )
dim pz    as sub( byval as zstring  ptr )
dim pw    as sub( byval as wstring  ptr )
dim pudt1 as sub( byval as UDT1     ptr )
dim pudt2 as sub( byval as UDT2     ptr )
dim pfwd1 as sub( byval as FWDREF1  ptr )
dim pdwf2 as sub( byval as FWDREF2  ptr )
dim ppsub as sub( byval as typeof( sub( ) ) ptr )
dim ppfi  as sub( byval as typeof( function( ) as integer ) ptr )

#macro test( lhs, rhs, amountofwarnings )
	#ifndef __tested__##lhs##__##rhs
	#define __tested__##lhs##__##rhs
		#print lhs = rhs, amountofwarnings warning:
		lhs = rhs
	#endif
#endmacro

#macro testNoWarning( lhs, rhs )
	test( lhs, rhs, no )
	test( rhs, lhs, no )
#endmacro

''
'' Filter out cases that shouldn't trigger a warning:
''
'' assignments between same size but signed/unsigned,
'' assignments between zstring and [u]byte,
'' assignments between wstring and the integer type with matching size (depends on the OS),
'' assignments between integer and long/longint (depends on 32bit or 64bit)
''

testNoWarning( b   , ub   )
testNoWarning( sh  , ush  )
testNoWarning( l   , ul   )
testNoWarning( ll  , ull  )
testNoWarning( i   , ui   )
testNoWarning( pb  , pub  )
testNoWarning( pb  , pz   )
testNoWarning( pub , pz   )
testNoWarning( psh , push )
testNoWarning( pl  , pul  )
testNoWarning( pll , pull )
testNoWarning( pi  , pui  )

#ifdef __FB_64BIT__
	'' integer = longint
	testNoWarning( ll  , i   )
	testNoWarning( ll  , ui  )
	testNoWarning( ull , i   )
	testNoWarning( ull , ui  )
	testNoWarning( pll , pi  )
	testNoWarning( pll , pui )
	testNoWarning( pull, pi  )
	testNoWarning( pull, pui )
#else
	'' integer = long
	testNoWarning( l  , i   )
	testNoWarning( l  , ui  )
	testNoWarning( ul , i   )
	testNoWarning( ul , ui  )
	testNoWarning( pl , pi  )
	testNoWarning( pl , pui )
	testNoWarning( pul, pi  )
	testNoWarning( pul, pui )
#endif

#if sizeof(wstring) = 4
	'' wstring = 4 bytes = long
	testNoWarning( pl , pw )
	testNoWarning( pul, pw )
	#ifndef __FB_64BIT__
		'' wstring = 4 bytes = integer
		testNoWarning( pi , pw )
		testNoWarning( pui, pw )
	#endif
#elseif sizeof(wstring) = 1
	'' wstring = byte = zstring
	testNoWarning( pb , pw )
	testNoWarning( pub, pw )
	testNoWarning( pz , pw )
#else
	'' wstring = 2 bytes = short
	testNoWarning( psh , pw )
	testNoWarning( push, pw )
#endif

''
'' Auto-generate tests for remaining combinations, except self-assignments
''

#macro checkLhsAndRhs( lhs, rhs )
	#if #lhs <> #rhs
		test( lhs, rhs, 1 )
	#endif
#endmacro

#macro checkLhs( lhs )
	checkLhsAndRhs( lhs, b     )
	checkLhsAndRhs( lhs, ub    )
	checkLhsAndRhs( lhs, sh    )
	checkLhsAndRhs( lhs, ush   )
	checkLhsAndRhs( lhs, l     )
	checkLhsAndRhs( lhs, ul    )
	checkLhsAndRhs( lhs, ll    )
	checkLhsAndRhs( lhs, ull   )
	checkLhsAndRhs( lhs, i     )
	checkLhsAndRhs( lhs, ui    )
	checkLhsAndRhs( lhs, f     )
	checkLhsAndRhs( lhs, d     )
	checkLhsAndRhs( lhs, s     )
	checkLhsAndRhs( lhs, udt1  )
	checkLhsAndRhs( lhs, udt2  )
	checkLhsAndRhs( lhs, psub  )
	checkLhsAndRhs( lhs, pfi   )
	checkLhsAndRhs( lhs, pany  )
	checkLhsAndRhs( lhs, pb    )
	checkLhsAndRhs( lhs, pub   )
	checkLhsAndRhs( lhs, psh   )
	checkLhsAndRhs( lhs, push  )
	checkLhsAndRhs( lhs, pl    )
	checkLhsAndRhs( lhs, pul   )
	checkLhsAndRhs( lhs, pll   )
	checkLhsAndRhs( lhs, pull  )
	checkLhsAndRhs( lhs, pi    )
	checkLhsAndRhs( lhs, pui   )
	checkLhsAndRhs( lhs, pf    )
	checkLhsAndRhs( lhs, pd    )
	checkLhsAndRhs( lhs, ps    )
	checkLhsAndRhs( lhs, pz    )
	checkLhsAndRhs( lhs, pw    )
	checkLhsAndRhs( lhs, pudt1 )
	checkLhsAndRhs( lhs, pudt2 )
	checkLhsAndRhs( lhs, pfwd1 )
	checkLhsAndRhs( lhs, pdwf2 )
	checkLhsAndRhs( lhs, ppsub )
	checkLhsAndRhs( lhs, ppfi  )
#endmacro

checkLhs( b     )
checkLhs( ub    )
checkLhs( sh    )
checkLhs( ush   )
checkLhs( l     )
checkLhs( ul    )
checkLhs( ll    )
checkLhs( ull   )
checkLhs( i     )
checkLhs( ui    )
checkLhs( f     )
checkLhs( d     )
checkLhs( s     )
checkLhs( udt1  )
checkLhs( udt2  )
checkLhs( psub  )
checkLhs( pfi   )
checkLhs( pany  )
checkLhs( pb    )
checkLhs( pub   )
checkLhs( psh   )
checkLhs( push  )
checkLhs( pl    )
checkLhs( pul   )
checkLhs( pll   )
checkLhs( pull  )
checkLhs( pi    )
checkLhs( pui   )
checkLhs( pf    )
checkLhs( pd    )
checkLhs( ps    )
checkLhs( pz    )
checkLhs( pw    )
checkLhs( pudt1 )
checkLhs( pudt2 )
checkLhs( pfwd1 )
checkLhs( pdwf2 )
checkLhs( ppsub )
checkLhs( ppfi  )
