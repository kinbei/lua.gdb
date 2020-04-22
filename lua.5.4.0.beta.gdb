set $LUA_TFUNCTION = 6

define s2v
	set $retval = (&($arg0)->val)
end

define rawtt
	set $retval = (($arg0)->tt_)
end

define makevariant
	set $retval = (($arg0) | (($arg1) << 4))
end

makevariant $LUA_TFUNCTION 0
set $LUA_VLCL = $retval

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
	if ($arg0 == (void *)0)
		set $retval = 1
	else
		if (($arg0)->c.tt == $LUA_VCCL)
			set $retval = 1
		else
			set $retval = 0
		end
	end
end

define funcinfo
	set $Closure = $arg0

	noLuaClosure $Closure
	if ($retval == 1)
		printf "=[C] \n"
	else
		set $proto = $Closure->l.p
		if ($proto.source == (void *)0)
			printf "=[?] \n"
		else
			set $filename = ((char*)($proto.source) + sizeof(TString))
			p $filename
		end
	end
end

define btlua
	set $ci = L.ci
	while ($ci != &(L.base_ci))
		s2v $ci->func
		set $func = $retval

		ttisclosure $func
		if ($retval == 0)
			clvalue $func
			set $Closure = $retval
		else
			set $Closure = (void *)(0)
		end

		funcinfo $Closure
		set $ci = $ci.previous
	end
end
