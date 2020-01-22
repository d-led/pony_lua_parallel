use "path:./deps/lua/windows" if windows
use "lib:lua53"
use "debug"

actor Main
    new create(env: Env) =>
        let max_num:I32 = 39
        env.out.print("synchronous...")
        with l = Lua do
            var count: I32 = max_num
            while count >= 0 do
                env.out.print("fibonacci("+count.string()+")="+l.fibonacci(count).string())
                count = count - 1
            end
        end

        env.out.print("asynchronous...")
        var count: I32 = max_num
        while count >= 0 do
            let al = LuaAsync(env)
            al.fibonacci(count)
            count = count - 1
        end

actor LuaAsync
    let _env: Env
    let _l: Lua = Lua

    new create(env: Env) =>
        _env = env

    be fibonacci(n: I32) =>
        _env.out.print("fibonacci("+n.string()+")="+_l.fibonacci(n).string())
        // to do: Promise the result

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

    fun ref dispose() =>
        @lua_close[I32](_l)
        _l = Pointer[None]
        Debug.out("Closing Lua state")

