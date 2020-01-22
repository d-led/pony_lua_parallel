use "path:./deps/lua/windows" if windows
use "lib:lua53"
use "debug"

actor Main
    new create(env: Env) =>
        with l = Lua do
            env.out.print(l.fibonacci(40))
            env.out.print("end")
        end

class Lua
    var _l: Pointer[None] = Pointer[None]

    new create() =>
        _l = @luaL_newstate[Pointer[None]]()
        if @luaL_openlibs[I32]( _l ) != 0 then
            Debug.err("luaL_openlibs error")
        end

        if @luaL_loadstring[I32]( _l, "
            -- http://progopedia.com/example/fibonacci/37/
            function fibonacci(n)
                if n<3 then
                    return 1
                else
                    return fibonacci(n-1) + fibonacci(n-2)
                end
            end
            ".cstring() ) != 0 then

            Debug.err("luaL_loadstring error")
        end

        if @lua_pcallk[I32]( _l, I32(0), I32(1), I32(0), I32(0), Pointer[None]) != 0 then
            var err: Pointer[U8] val = @luaL_checklstring[Pointer[U8] val](_l, I32(-1), Pointer[None])
            Debug.out(recover String.copy_cstring(err) end)
        end

    fun ref fibonacci(n: I32): String =>
        if @luaL_loadstring[I32]( _l, ("return fibonacci("+n.string()+")").cstring() ) != 0 then
            return "luaL_loadstring error"
        end

        if @lua_pcallk[I32]( _l, I32(0), I32(1), I32(0), I32(0), Pointer[None]) != 0 then
            // return "lua_pcallk error"
            var err: Pointer[U8] val = @luaL_checklstring[Pointer[U8] val](_l, I32(-1), Pointer[None])
            return recover String.copy_cstring(err) end
        end

        // return the result as a string
        var res: Pointer[U8] val = @luaL_checklstring[Pointer[U8] val](_l, I32(-1), Pointer[None])
        recover String.copy_cstring(res) end

    fun dispose() =>
        // to do: close lua state
        Debug.out("Closing Lua state")
//    dMob->name = strdup( luaL_checkstring( L, -1 ) );
//    lua_pop( L, 1 );
