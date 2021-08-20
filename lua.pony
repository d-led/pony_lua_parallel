use "path:./deps/lua/windows" if windows
use "path:./deps/lua/linux" if linux
use "path:./deps/lua/osx" if osx
use "lib:lua53"
use "debug"
use "promises"
use "collections"

// FFI
use @luaL_checklstring[Pointer[U8] val](l: Pointer[None], narg: I32, size: Pointer[None])
use @luaL_loadstring[I32](l: Pointer[None], chunk: Pointer[U8] tag)
use @lua_pcallk[I32](l: Pointer[None], nargs: I32, nresults: I32, msgh: I32, ctx: I32, k: Pointer[None])
use @luaL_newstate[Pointer[None]]()
use @luaL_openlibs[I32](l: Pointer[None])
use @lua_pushlightuserdata[None](l: Pointer[None], p: Lua ref)
use @lua_setglobal[None](l: Pointer[None], name: Pointer[None] tag)
use @lua_pushcclosure[None](l: Pointer[None], c: @{(Pointer[None]): I32} val, v: I32)
use @lua_tolstring[Pointer[U8]](l: Pointer[None], index: I32, len: Pointer[None])
use @lua_getglobal[I32](l: Pointer[None], name: Pointer[U8] tag)
use @lua_touserdata[Lua](l: Pointer[None], index: I32)
use @lua_settop[None](l: Pointer[None], index: I32)
use @lua_close[I32](l: Pointer[None])

// LuaAsync holds its own Lua instance, but calculates asynchronously
actor LuaAsync
    let _l: Lua = Lua

    // https://patterns.ponylang.io/async/actorpromise.html
    be fibonacci(n: I32, promise: Promise[String]) =>
        let res = _l.fibonacci(n)
        promise("fibonacci("+n.string()+")="+res.string())

    fun _final() =>
        _l.dispose()

type LuaCallback is {(Pointer[None]): I32}

class Lua
    var _l: Pointer[None] = Pointer[None]
    var _name_to_pony_function: Map[String, LuaCallback] = Map[String, LuaCallback]

    // calculate synchronously in Lua
    fun ref fibonacci(n: I32): String =>
        (var res, var err) = run_string("return fibonacci("+n.string()+")")

        if err != "" then
            err
        else
            res
        end

    // return the string from the stack top or the default value
    fun ref top_string(default: String): String =>
        var res: Pointer[U8] val = @luaL_checklstring(_l, I32(-1), Pointer[None])
        var s = recover String.copy_cstring(res) end
        if s == "" then
            default
        else
            s
        end

    // executes code and expects a single return value, which is convertable to a string
    // returns result, error
    fun ref run_string(code: String): (String, String) =>
        if @luaL_loadstring( _l, code.cstring() ) != 0 then
            return ("", top_string("luaL_loadstring error"))
        end

        if @lua_pcallk( _l, I32(0), I32(1), I32(0), I32(0), Pointer[None]) != 0 then
            return ("", top_string("lua_pcallk error"))
        end

        let res = top_string("")
        if res == "" then
            ("", "could not fetch the result")
        else
            (res, "")
        end

    new create() =>
        // creates a new Lua instance
        _l = @luaL_newstate()

        // loads the built-in libraries
        if @luaL_openlibs( _l ) != 0 then
            Debug.err("luaL_openlibs error")
        end

        // defines a function in the Lua instance
        (var res, var err) = run_string("
            -- http://progopedia.com/example/fibonacci/37/
            function fibonacci(n)
                if n<3 then
                    return 1
                else
                    return fibonacci(n-1) + fibonacci(n-2)
                end
            end

            return 'ok'
        ")
        if err != "" then
            Debug.err(err)
        end

        // Lets the Lua instance know the reference to this object.
        // Global is ok here, as the Lua object is not shared among actors
        // although, the callbacks will for the moment get access to the raw Lua state
        @lua_pushlightuserdata(_l, this)
        @lua_setglobal(_l, "this".cstring())

    fun callback(name: String, l: Pointer[None]): I32 =>
        try
            _name_to_pony_function(name)?(l)
        else
            @lua_pushstring(l, ("Error running: "+name).cstring())
            @lua_error(l)
            1
        end

    fun ref register_function(name: String, cb: LuaCallback) =>
        // the mapping is now tracked in parallel in Pony and Lua,
        // as free functions (C->Pony callbacks) cannot create a closure

        // track function in Pony
        _name_to_pony_function.update(name, cb)
        // track function in Lua
        @lua_pushstring(_l, name.cstring())
        // https://www.lua.org/manual/5.3/manual.html#lua_pushcclosure
        // the function name is available in the bound closure as an upvalue
        @lua_pushcclosure(_l, @{(l: Pointer[None]): I32 =>
            Debug.out("callback called")
            // https://github.com/lua/lua/blob/d7bb8df8414f71a290c8a4b1c9f7c6fe839a94df/lua.h#L44
            let l_LUAI_MAXSTACK: I32 = 1000000
            let l_LUA_REGISTRYINDEX: I32 = (-l_LUAI_MAXSTACK - 1000)
            let lua_upvalueindex: I32 = l_LUA_REGISTRYINDEX - 1
            let name: String val = recover String.copy_cstring(@lua_tolstring(l,lua_upvalueindex, Pointer[None])) end

            // should not happen, unless callbacks mess up the global registry or there is a bug
            if name == "" then
                Debug.err("could not correlate the callback to a Pony function")
                @lua_pushstring(l, "could not correlate the callback to a Pony function".cstring())
                @lua_error(l)
                return 1
            end

            // push the Lua class instance onto the stack
            @lua_getglobal(l, "this".cstring())
            let recovered_lua = @lua_touserdata(l, @lua_gettop(l))
            // pop the global from the stack
            @lua_settop(l, -@lua_gettop(l)-1)

            // call the Pony callback
            recovered_lua.callback(name, l)
        }, I32(1)) // 1 == 1 closure value
        @lua_setglobal(_l, name.cstring())

    fun dispose() =>
        // destroy the Lua instance
        @lua_close(_l)
