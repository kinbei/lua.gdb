set $LUA_TFUNCTION = 6

define s2v
	set $retval = (&($arg0)->val)
end

define rawtt
	set $retval = (($arg0)->tt_)
end

define makevariant
	set $retval = (($arg0) | ($arg1 << 4))
end

# Lua closure
makevariant $LUA_TFUNCTION 0
set $LUA_VLCL = $retval

# light C function
makevariant $LUA_TFUNCTION 1
set $LUA_VLCF = $retval

# C closure
makevariant $LUA_TFUNCTION 2
set $LUA_VCCL = $retval

define ttisclosure
	rawtt $arg0
	set $o = $retval
	if (($o & 0x1F) == $LUA_VLCL)
		set $retval = 1
	else
		set $retval = 0
	end
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
	set $retval = 0
	
	if ($arg0 == (void *)0)
		set $retval = 1
	else
		# is C closure ?
		set $retval = (($arg0)->c.tt == $LUA_VCCL)
	end	
end

define btlua
	set $CallInfo = L.ci
	while ($CallInfo != &(L.base_ci))
		# convert a 'StackValue' to a 'TValue'
		s2v $CallInfo->func
		set $func = $retval

		rawtt $func
		set $ttype = $retval & 0x3F

		printf "type(%d) ", $ttype
		if ($ttype == 0x16)
			clvalue $func
			set $Closure = $retval
			set $proto = $Closure->l.p
			set $filename = ((char*)($proto.source) + sizeof(TString))
			set $lineno = $proto.lineinfo[$CallInfo.u.l.savedpc - $proto.code - 1]
			printf "Lua function: %s:%d \n", $filename, $lineno

			set $CallInfo = $CallInfo.previous
			loop_continue
		end
		
		if ($ttype == 0x36)
			clvalue $func
			set $Closure = $retval
			printf "C closure: "
			p $Closure.c.f

			set $CallInfo = $CallInfo.previous
			loop_continue
		end


		printf "Unknow: type = %d \n", $ttype
		clvalue $func
		set $Closure = $retval
		p *$Closure

		set $CallInfo = $CallInfo.previous
	end
end
