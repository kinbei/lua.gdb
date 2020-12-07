#
set $NULL = 0
set $TRUE = 1

# basic types
set $LUA_TFUNCTION = 6

# convert a 'StackValue' to a 'TValue'
define s2v
	set $retval = (&($arg0)->val)
end

# raw type tag of a TValue
define rawtt
	set $retval = (($arg0)->tt_)
end

# add variant bits to a type
define makevariant
	set $t = $arg0
	set $v = $arg1
	set $retval = (($t) | (($v) << 4))
end

# Lua closure
makevariant $LUA_TFUNCTION 0
set $LUA_VLCL = $retval

# C closure
makevariant $LUA_TFUNCTION 2
set $LUA_VCCL = $retval

define ttisclosure
	rawtt $arg0
	set $o = $retval
	set $retval = (($o & 0x1F) == $LUA_VLCL)
end

define val_
	set $retval = (($arg0)->value_)
end

define cast_u
	set $retval = (union GCUnion *)($arg0)
end

define gco2cl
	cast_u $arg0
	set $retval = &(($retval)->cl)
end

define clvalue
	val_ $arg0
	gco2cl $retval.gc
end

define noLuaClosure
	if $arg0 == $NULL
		set $retval = $TRUE
	else
		set $retval = (($arg0)->c.tt == $LUA_VCCL)
	end
end

# call is running a C function
set $CIST_C = (1<<1)

define isLua
	set $retval = (!(($arg0)->callstatus & $CIST_C))
end

define gco2lcl
	cast_u $arg0
	set $retval = &(($retval)->cl.l)
end

define clLvalue
	val_ $arg0
	gco2lcl $retval.gc
end

# Active Lua function (given call info)
define ci_func
	s2v $arg0->func
	clLvalue $retval
end

define cast_int
	set $retval = ((int)($arg0))
end

# pcRel(pc, p)
define pcRel
	cast_int ($arg0-($arg1)->code)
	set $retval = ($retval - 1)
end

# currentpc (CallInfo *ci)
define currentpc
	ci_func $arg0
	pcRel $arg0->u.l.savedpc $retval->p
end

# getbaseline (const Proto *f, int pc, int *basepc)
define getbaseline
	if $arg0->sizeabslineinfo == 0 || $arg1 < $arg0->abslineinfo[0].pc
		set $arg2 = -1
		set $retval = $arg0->linedefined
	else
		if $arg1 >= $arg0->abslineinfo[$arg0->sizeabslineinfo - 1].pc
			set $v1 = (unsigned int)($arg0->sizeabslineinfo - 1)
		else
			set $v2 = (unsigned int)($arg0->sizeabslineinfo - 1)
			set $v1 = 0

			while $v1 < ($v2 - 1)
				set $v3 = ($v2 + $v1) / 2
				if $arg1 >= $arg0->abslineinfo[$v3].pc
					set $v1 = $v3
				else
					set $v2 = $v3
				end
			end
		end

		set $arg2 = $arg0->abslineinfo[$v1].pc
		set $retval = $arg0->abslineinfo[$v1].line
	end    
end

# int luaG_getfuncline (const Proto *f, int pc)
define luaG_getfuncline
	if $arg0->lineinfo == $NULL
		set $retval = -1
	else
		set $basepc = 0
		getbaseline $arg0 $arg1 $basepc
		set $baseline = $retval

		while $basepc++ < $arg1
			set $baseline = $baseline + $arg0->lineinfo[$basepc]
		end
		set $retval = $baseline
	end
end

# int getcurrentline (CallInfo *ci)
define getcurrentline
	ci_func $arg0
	set $v1 = $retval->p

	currentpc $arg0
	set $v2 = $retval
	
	luaG_getfuncline $v1 $v2
end

# getstr
define getstr
	set $retval = ($arg0)->contents
end

# void funcinfo (lua_Debug *ar, Closure *cl)
define funcinfo
	set $Closure = $arg0
	set $ci = $arg1

	# printf source
	noLuaClosure $Closure
	if $retval == $TRUE
		printf "=[C]"
	else
		set $proto = $Closure->l.p
		if $proto.source != $NULL
			getstr $proto.source
			printf "%s", $retval
		else
			printf "=?"
		end
	end
	
	# printf lineno
	isLua $ci
	if $ci != $NULL && $retval == $TRUE
		getcurrentline $ci
		printf ":%d", $retval
	else
		printf ":%d", -1
	end

	printf "\n"
end

define traceback
	if $argc == 0
		set $L = L
	else
		set $L = $arg0
	end

	set $ci = L.ci
	while ($ci != &(L.base_ci))
		# func = s2v(ci->func)
		s2v $ci->func
		set $func = $retval

		# is Lua closure?
		ttisclosure $func
		if $retval == 1
			clvalue $func
			set $Closure = $retval
		else
			set $Closure = (void *)(0)
		end
		
		funcinfo $Closure $ci
		set $ci = $ci.previous
	end
end
