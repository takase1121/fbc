''	FreeBASIC - 32-bit BASIC Compiler.
''	Copyright (C) 2004-2006 Andre Victor T. Vicentini (av1ctor@yahoo.com.br)
''
''	This program is free software; you can redistribute it and/or modify
''	it under the terms of the GNU General Public License as published by
''	the Free Software Foundation; either version 2 of the License, or
''	(at your option) any later version.
''
''	This program is distributed in the hope that it will be useful,
''	but WITHOUT ANY WARRANTY; without even the implied warranty of
''	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
''	GNU General Public License for more details.
''
''	You should have received a copy of the GNU General Public License
''	along with this program; if not, write to the Free Software
''	Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA.

'' AST scope and break nodes
'' scope: l = NULL; r = NULL
'' break: l = branch (used as reference, not loaded)
''
'' chng: mar/2006 written [v1ctor]


#include once "inc\fb.bi"
#include once "inc\fbint.bi"
#include once "inc\lex.bi"
#include once "inc\parser.bi"
#include once "inc\ast.bi"
#include once "inc\ir.bi"
#include once "inc\emit.bi"

declare function hCheckBranch _
	( _
		byval proc as ASTNODE ptr, _
		byval n as ASTNODE ptr _
	) as integer

declare sub hDelLocals _
	( _
		byval n as ASTNODE ptr, _
		byval check_backward as integer _
	)

declare sub hDestroyVars _
	( _
		byval scp as FBSYMBOL ptr _
	)

'':::::
function astScopeBegin _
	( _
		_
	) as ASTNODE ptr

    dim as ASTNODE ptr n = any
    dim as FBSYMBOL ptr s = any

	if( parser.scope >= FB_MAXSCOPEDEPTH ) then
		return NULL
	end if

	''
	n = astNewNode( AST_NODECLASS_SCOPEBEGIN, INVALID )
	if( n = NULL ) then
		return NULL
	end if

	s = symbAddScope( n )

	'' must update the stmt count or any internal label
	'' allocated/emitted previously will lie in the same stmt
	parser.stmt.cnt += 1

    '' change to scope's symbol tb
    n->sym = s
    n->block.parent = ast.currblock
	n->block.inistmt = parser.stmt.cnt

    n = astAdd( n )

	''
	parser.scope += 1
	parser.currblock = s
    ast.currblock = n

	symbSetCurrentSymTb( @s->scp.symtb )

	''
	irScopeBegin( s )

	''
	astAdd( astNewDBG( AST_OP_DBG_SCOPEINI, cint( s ) ) )

	function = n

end function

'':::::
private sub hAddToBreakList _
	( _
		byval list as AST_BREAKLIST ptr, _
		byval node as ASTNODE ptr _
	) static

	if( list->tail <> NULL ) then
		list->tail->next = node
	else
		list->head = node
	end if

	node->prev = list->tail
	node->next = NULL
	list->tail = node

end sub

'':::::
function astScopeBreak _
	( _
		byval target as FBSYMBOL ptr _
	) as integer

	dim as ASTNODE ptr n = any

	function = FALSE

	n = astNewNode( AST_NODECLASS_SCOPE_BREAK, INVALID, NULL )

	n->sym = target
	n->break.parent = ast.currblock
	n->break.scope = parser.scope
	n->break.linenum = lexLineNum( )
	n->break.stmtnum = parser.stmt.cnt

	'' the branch node is added, not the break itself, any
	'' destructor will be added before this node when
	'' processing the proc's branch list
	n->l = astAdd( astNewBRANCH( AST_OP_JMP, target ) )

	''
	hAddToBreakList( @ast.proc.curr->block.breaklist, n )

	function = TRUE

end function

'':::::
sub astScopeEnd _
	( _
		byval n as ASTNODE ptr _
	)

	dim as FBSYMBOL ptr s = any

	s = n->sym

	'' must update the stmt count or any internal label
	'' allocated/emitted previously will lie in the same stmt
	parser.stmt.cnt += 1

	n->block.endstmt = parser.stmt.cnt

	'' free dynamic vars
	hDestroyVars( s )

	'' remove symbols from hash table
	symbDelScopeTb( s )

	''
	irScopeEnd( s )

	'' back to preview symbol tb
	symbSetCurrentSymTb( s->symtb )

	ast.currblock = n->block.parent
	parser.currblock = ast.currblock->sym
	parser.scope -= 1

	''
	astAdd( astNewDBG( AST_OP_DBG_SCOPEEND, cint( s ) ) )

	n = astNewNode( AST_NODECLASS_SCOPEEND, INVALID )
    n->sym = s

    astAdd( n )

end sub

'':::::
function astScopeUpdBreakList _
	( _
		byval proc as ASTNODE ptr _
	) as integer

    dim as ASTNODE ptr n = any

    function = FALSE

    '' for each break in this proc..
    n = proc->block.breaklist.head
    do while( n <> NULL )

    	'' EXIT SUB | FUNCTION?
    	if( n->sym = proc->block.exitlabel ) then
    		'' special case due the non implicit scope block, that
    		'' can't be created for procs because the implicit
    		'' main() function
    		hDelLocals( n, FALSE )

		else
			if( hCheckBranch( proc, n ) = FALSE ) then
				exit function
			end if
		end if

        '' next
    	n = n->next
    loop

    function = TRUE

end function

'':::::
private function hBranchError _
	( _
		byval errnum as integer, _
		byval n as ASTNODE ptr, _
		byval s as FBSYMBOL ptr = NULL _
	) as integer static

	dim as integer showerror
	dim as string msg

	showerror = env.clopt.showerror
	env.clopt.showerror = FALSE

	if( symbGetName( n->sym ) <> NULL ) then
		msg = "to label: " + *symbGetName( n->sym )
		if( s <> NULL ) then
			msg += ", "
		end if
	end if

	if( s <> NULL ) then
		msg += "local "
		if( symbGetType( s ) = FB_DATATYPE_STRING ) then
			msg += "string: "
		elseif( symbGetArrayDimensions( s ) <> 0 ) then
			msg += "array: "
		else
			msg += "object: "
		end if

		msg += *symbGetName( s )
	end if

	function = errReportEx( errnum, msg, n->break.linenum )

	env.clopt.showerror = showerror

end function

'':::::
private sub hBranchWarning _
	( _
		byval errnum as integer, _
		byval n as ASTNODE ptr, _
		byval s as FBSYMBOL ptr = NULL _
	) static

	dim as integer showerror
	dim as string msg

	showerror = env.clopt.showerror
	env.clopt.showerror = FALSE

	if( symbGetName( n->sym ) <> NULL ) then
		msg = "to label: " + *symbGetName( n->sym )
		if( s <> NULL ) then
			msg += ", "
		end if
	end if

	if( s <> NULL ) then
		msg += "variable: "
		msg += *symbGetName( s )
	end if

	errReportWarnEx( errnum, msg, n->break.linenum )

	env.clopt.showerror = showerror

end sub

'':::::
private function hCheckCrossing _
	( _
		byval n as ASTNODE ptr, _
		byval blk as FBSYMBOL ptr, _
		byval top_stmt as integer, _
		byval bot_stmt as integer _
	) as integer

	dim as FBSYMBOL ptr s = any
	dim as integer stmt = any

	'' search for:
	'' 		goto label
	'' 		redim array(...) as type | dim obj as object() | dim str as string
	'' 		label:

    if( symbIsScope( blk ) ) then
    	s = symbGetScopeSymbtb( blk ).head
    else
    	s = symbGetProcSymbtb( blk ).head
    end if

    do while( s <> NULL )
    	if( symbIsVar( s ) ) then
    		stmt = symbGetVarStmt( s )
    		if( stmt > top_stmt ) then
    			if( stmt < bot_stmt ) then
    				if( symbGetVarHasCtor( s ) ) then
    					if( hBranchError( FB_ERRMSG_BRANCHCROSSINGDYNDATADEF, n, s ) = FALSE ) then
    						return FALSE
    					end if

    				else
    					'' not static, shared or temp?
    					if( (s->attrib and (FB_SYMBATTRIB_STATIC or _
    										FB_SYMBATTRIB_SHARED or _
    										FB_SYMBATTRIB_TEMP)) = 0 ) then
    						'' must be cleaned?
    						if( symbGetDontInit( s ) = FALSE ) then
    							hBranchWarning( FB_WARNINGMSG_BRANCHCROSSINGLOCALVAR, n, s )
    						end if
    					end if
    				end if
    			end if
    		end if
    	end if

    	s = s->next
    loop

	function = TRUE

end function

'':::::
private function hCheckScopeLocals _
	( _
		byval n as ASTNODE ptr _
	) as integer

    dim as FBSYMBOL ptr dst = any, blk = any, src_blk = any
    dim as integer dst_stmt = any, src_stmt = any

    dst = n->sym
    dst_stmt = symbGetLabelStmt( dst )

    src_blk = n->break.parent->sym
    src_stmt = n->break.stmtnum

    blk = symbGetLabelParent( dst )
    do
    	'' check for any var allocated between the block's
    	'' beginning and the branch
    	if( hCheckCrossing( n, blk, 0, dst_stmt ) = FALSE ) then
    		return FALSE
    	end if

    	blk = symbGetParent( blk )

    	'' same parent?
    	if( symbIsProc( blk ) or (blk = src_blk) ) then
    		'' forward?
			if( dst_stmt > src_stmt ) then
    			if( hCheckCrossing( n, blk, src_stmt, dst_stmt ) = FALSE ) then
    				return FALSE
    			end if
    		end if

    		exit do
    	end if
    loop

	function = TRUE

end function

'':::::
private sub hDestroyBlockLocals _
	( _
		byval blk as FBSYMBOL ptr, _
		byval top_stmt as integer, _
		byval bot_stmt as integer, _
		byval base_expr as ASTNODE ptr _	'' the node before the branch, not itself!
	)

	dim as FBSYMBOL ptr s = any
	dim as ASTNODE ptr expr = any
	dim as integer stmt = any

    '' for each now (in reverse order)
    if( symbIsScope( blk ) ) then
    	s = symbGetScopeSymbTb( blk ).tail
    else
    	s = symbGetProcSymbTb( blk ).tail
    end if

    do while( s <> NULL )
    	if( symbIsVar( s ) ) then
    		stmt = symbGetVarStmt( s )
    		if( stmt > top_stmt ) then
    			if( stmt < bot_stmt ) then
                    '' has a dtor?
                    if( symbGetVarHasDtor( s ) ) then
                    	'' call it..
                    	expr = astBuildVarDtorCall( s )
                    	if( expr <> NULL ) then
                    		base_expr = astAddAfter( expr, base_expr )
                    	end if
                    end if
    			end if
    		end if
    	end if

    	s = s->prev
    loop

end sub

'':::::
private sub hDelBackwardLocals _
	( _
		byval n as ASTNODE ptr _
	)

    '' free any dyn var allocated between the block's
    '' beginning and the branch
    hDestroyBlockLocals( n->break.parent->sym, _
    				 	 symbGetLabelStmt( n->sym ), _
    				 	 n->break.stmtnum, _
    				 	 astGetPrev( n->l ) )

end sub


#define hisInside( blk, lbl_stmt ) _
	iif( lbl_stmt < blk->block.inistmt, FALSE, lbl_stmt < blk->block.endstmt )


'':::::
private sub hDelLocals _
	( _
		byval n as ASTNODE ptr, _
		byval check_backward as integer _
	)

	dim as FBSYMBOL ptr s = any
	dim as integer dst_stmt = any, src_stmt = any
	dim as ASTNODE ptr blk = any

	dst_stmt = symbGetLabelStmt( n->sym )
	src_stmt = n->break.stmtnum

    '' for each parent (starting from the branch ones)
    blk = n->break.parent
    do
    	'' destroy any var created between the beginning of
    	'' the block and the branch
    	hDestroyBlockLocals( blk->sym, _
    						 0, _
    						 src_stmt, _
    						 astGetPrev( n->l ) ) '' prev node will change

    	blk = blk->block.parent
    	if( blk = NULL ) then
    		exit do
    	end if

    	'' target label found?
    	if( hIsInside( blk, dst_stmt ) ) then
    		if( check_backward ) then
    			'' if backward, free any dyn var allocated
    			'' between the target label and the branch
				if( dst_stmt <= src_stmt ) then
    				hDestroyBlockLocals( blk->sym, _
    									 dst_stmt, _
    									 src_stmt, _
    									 astGetPrev( n->l ) )
    			end if
    		end if

    		exit do
    	end if
    loop

end sub

'':::::
private function hIsTargetOutside _
	( _
		byval proc as FBSYMBOL ptr, _
		byval label as FBSYMBOL ptr _
	) as integer

	'' main?
	if( (proc->stats and (FB_SYMBSTATS_MAINPROC or _
						  FB_SYMBSTATS_MODLEVELPROC)) <> 0 ) then

		function = symbGetParent( label ) <> @symbGetGlobalNamespc( )

	else
		function = symbGetParent( label ) <> proc
	end if

end function

'':::::
private function hCheckBranch _
	( _
		byval proc as ASTNODE ptr, _
		byval n as ASTNODE ptr _
	) as integer

    dim as ASTNODE ptr src_parent = any
    dim as FBSYMBOL ptr dst = any, dst_parent = any
    dim as integer src_scope = any, dst_scope = any
    dim as integer src_stmt = any, dst_stmt = any, isparent = any

	function = FALSE

    dst = n->sym

    '' not declared?
    if( symbGetLabelIsDeclared( dst ) = FALSE ) then
    	hBranchError( FB_ERRMSG_BRANCHTARTGETOUTSIDECURRPROC, n )
    	exit function
    end if

	'' branching to other procs or mod-level?
    if( hIsTargetOutside( proc->sym, dst ) ) then
    	hBranchError( FB_ERRMSG_BRANCHTARTGETOUTSIDECURRPROC, n )
        exit function
    end if

    ''
    dst_scope = symbGetScope( dst )
    dst_parent = symbGetLabelParent( dst )
    dst_stmt = symbGetLabelStmt( dst )

    src_scope = n->break.scope
    src_parent = n->break.parent
    src_stmt = n->break.stmtnum

    '' inside parent?
    if( hIsInside( src_parent, dst_stmt ) ) then
    	'' jumping to a child block?
    	if( dst_scope > src_scope ) then
           	'' any locals?
			if( hCheckScopeLocals( n ) = FALSE ) then
       			if( errGetLast( ) <> FB_ERRMSG_OK ) then
       				exit function
       			end if
       		end if

    		'' backward?
    		if( dst_stmt <= src_stmt ) then
    			hDelBackwardLocals( n )
    		end if

    	'' same level..
    	else
    		'' backward?
    		if( dst_stmt <= src_stmt ) then
    			hDelBackwardLocals( n )

    		'' forward..
    		else
    			'' crossing any declaration?
    			if( hCheckCrossing( n, dst_parent, src_stmt, dst_stmt ) = FALSE ) then
       				if( errGetLast( ) <> FB_ERRMSG_OK ) then
       					exit function
       				end if
    			end if
    		end if
    	end if

    	return TRUE
    end if

    '' outside..

   	'' jumping to a scope block?
	if( symbIsScope( dst_parent ) ) then
		isparent = (dst_parent->scp.backnode->block.inistmt <= _
					src_parent->block.inistmt) and _
  	    		   (dst_parent->scp.backnode->block.endstmt >= _
  	    		    src_parent->block.endstmt)

		'' not a parent block?
        if( isparent = FALSE ) then
			'' any locals?
			if( hCheckScopeLocals( n ) = FALSE ) then
       			if( errGetLast( ) <> FB_ERRMSG_OK ) then
       				exit function
       			end if
       		end if
       	end if

   	'' proc level..
   	else
   		isparent = TRUE
   	end if

   	if( isparent ) then
   	   	'' forward?
   		if( dst_stmt > src_stmt ) then
   			'' crossing any declaration?
   			if( hCheckCrossing( n, dst_parent, src_stmt, dst_stmt ) = FALSE ) then
       			if( errGetLast( ) <> FB_ERRMSG_OK ) then
       				exit function
       			end if
   			end if
   		end if
   	end if

   	'' jumping out, free any dyn var already allocated
   	'' until the target block if reached
   	hDelLocals( n, TRUE )

	function = TRUE

end function

'':::::
private sub hDestroyVars _
	( _
		byval scp as FBSYMBOL ptr _
	)

    dim as FBSYMBOL ptr s = any

	'' for each symbol declared inside the SCOPE block (in reverse order)..
	s = symbGetScopeSymbTb( scp ).tail
    do while( s <> NULL )
    	'' variable?
    	if( symbGetClass( s ) = FB_SYMBCLASS_VAR ) then
			'' has a dtor?
			if( symbGetVarHasDtor( s ) ) then
    			astAdd( astBuildVarDtorCall( s ) )
    		end if
    	end if

    	s = s->prev
    loop

end sub

'':::::
function astLoadSCOPEBEGIN _
	( _
		byval n as ASTNODE ptr _
	) as IRVREG ptr

    dim as FBSYMBOL ptr s = any

	s = n->sym

	s->scp.emit.baseofs = emitGetLocalOfs( parser.currproc )

	symbScopeAllocLocals( s )

	if( ast.doemit ) then
		irEmitSCOPEBEGIN( s )
	end if

	function = NULL

end function

'':::::
function astLoadSCOPEEND _
	( _
		byval n as ASTNODE ptr _
	) as IRVREG ptr

    dim as FBSYMBOL ptr s = any

    s = n->sym

	if( ast.doemit ) then
		irEmitSCOPEEND( s )
	end if

    emitSetLocalOfs( parser.currproc, s->scp.emit.baseofs )

    function = NULL

end function


