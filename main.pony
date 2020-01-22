use "path:./deps/lua/windows" if windows
use "lib:lua53"
use "debug"
use "promises"
use "time"

actor Main
    let _env: Env
    let max_num: I32 = 40

    new create(env: Env) =>
        _env = env

        synchronous_demo()
        asynchronous_demo()

    fun synchronous_demo() =>
        _env.out.print("synchronous...")
        let sw1 = Stopwatch
        with l = Lua do
            var count: I32 = max_num
            while count >= 0 do
                _env.out.print("fibonacci("+count.string()+")="+l.fibonacci(count).string())
                count = count - 1
            end
        end
        _env.out.print("--> elapsed seconds: "+sw1.elapsedSeconds().string())

    fun asynchronous_demo() =>
        _env.out.print("asynchronous...")
        var count: I32 = max_num
        var sw2 = Stopwatch
        let results = Array[Promise[String]]
        while count >= 0 do
            let al = LuaAsync
            let p = Promise[String]
            al.fibonacci(count, p)
            results.push(p)
            count = count - 1
        end
        // wait for all results
        Promises[String].join(results.values())
            .next[None]({(a: Array[String val] val) =>
                for s in a.values() do
                    _env.out.print(s)
                end
                Time.nanos()
                _env.out.print("--> elapsed seconds: "+sw2.elapsedSeconds().string())
            })

        _env.out.print("main: done, waiting for promises")


actor LuaAsync
    let _l: Lua = Lua

    // https://patterns.ponylang.io/async/actorpromise.html
    be fibonacci(n: I32, p: Promise[String]) =>
        p("fibonacci("+n.string()+")="+_l.fibonacci(n).string())

    fun _final() =>
        _l.dispose()

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
        @lua_close[I32](_l)

class val Stopwatch
    var _t1: U64

    new val create() =>
        _t1 = Time.nanos()

    fun elapsedSeconds() : F64 =>
        let t2: U64 = Time.nanos()
        (t2-_t1).f64()/1000000000.0