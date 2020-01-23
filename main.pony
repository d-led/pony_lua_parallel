use "path:./deps/lua/windows" if windows
use "path:./deps/lua/linux" if linux
use "lib:lua53"
use "debug"
use "promises"
use "time"
use "cli"
use "collections"

actor Main
    let _env: Env
    var max_num: I32 = 40

    new create(env: Env) =>
        _env = env

        configure()
        // synchronous_demo()
        // asynchronous_demo()
        c_code_calling_pony_demo()

    fun ref configure() =>
        try
            max_num = EnvVars(_env.vars)("MAX_NUM")?.i32()?
        end

    fun synchronous_demo() =>
        _env.out.print("synchronous...")
        let sw1 = Stopwatch
        // calculate the results in sequence
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
        // to collect all asynchronous result promises
        let results = Array[Promise[String]]
        // create the result promises
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
                // print all values at once in the order received
                for s in a.values() do
                    _env.out.print(s)
                end
                // done
                _env.out.print("--> elapsed seconds: "+sw2.elapsedSeconds().string())
            })

        _env.out.print("main: done, waiting for promises")

    fun c_code_calling_pony_demo() =>
        _env.out.print("calling pony from lua")
        let l = Lua
        l.register_function("test", {(_l: Pointer[None]): I32 =>
            _env.out.print("Pony called from Lua")
            0
        })
        l.run_string("test() return 'ok'")



actor LuaAsync
    let _l: Lua = Lua

    // https://patterns.ponylang.io/async/actorpromise.html
    be fibonacci(n: I32, p: Promise[String]) =>
        p("fibonacci("+n.string()+")="+_l.fibonacci(n).string())

    fun _final() =>
        _l.dispose()

type LuaCallback is {(Pointer[None]): I32}

class Lua
    var _l: Pointer[None] = Pointer[None]
    var _cb: Map[String, LuaCallback] = Map[String, LuaCallback]

    fun ref fibonacci(n: I32): String =>
        (var res, var err) = run_string("return fibonacci("+n.string()+")")

        if err != "" then
            err
        else
            res
        end

    fun ref top_string(default: String): String =>
        var res: Pointer[U8] val = @luaL_checklstring[Pointer[U8] val](_l, I32(-1), Pointer[None])
        var s = recover String.copy_cstring(res) end
        if s == "" then
            default
        else
            s
        end

    // returns result, error
    fun ref run_string(code: String): (String, String) =>
        if @luaL_loadstring[I32]( _l, code.cstring() ) != 0 then
            return ("", top_string("luaL_loadstring error"))
        end

        if @lua_pcallk[I32]( _l, I32(0), I32(1), I32(0), I32(0), Pointer[None]) != 0 then
            return ("", top_string("lua_pcallk error"))
        end

        let res = top_string("")
        if res == "" then
            ("", "could not fetch the result")
        else
            (res, "")
        end

    new create() =>
        _l = @luaL_newstate[Pointer[None]]()

        if @luaL_openlibs[I32]( _l ) != 0 then
            Debug.err("luaL_openlibs error")
        end

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

        // global is ok here, as the Lua object is not shared among actors
        // although, the callbacks will for the moment get access to the raw Lua state
        @lua_pushlightuserdata[None](_l, this)
        @lua_setglobal[None](_l, "this".cstring())

    fun canary() =>
        Debug.out("canary")

    fun ref register_function(name: String, callback: LuaCallback) =>
        _cb.update(name, callback)
        @lua_pushcclosure[None](_l, @{(l: Pointer[None]) =>
            Debug.out("callback called")
            @lua_getglobal[I32](l, "this".cstring())
            let recovered_lua = @lua_touserdata[Lua](l, @lua_gettop[I32](l))
            recovered_lua.canary()
        }, I32(0))
        @lua_setglobal[None](_l, name.cstring())

    fun dispose() =>
        @lua_close[I32](_l)

// incomplete
struct LuaDebug
  var event: I32 = 0
  var name: Pointer[U8] = Pointer[U8]
  var namewhat: Pointer[U8] = Pointer[U8]
  var what: Pointer[U8] = Pointer[U8]
  var source: Pointer[U8] = Pointer[U8]
// int event;
//   const char *name;	/* (n) */
//   const char *namewhat;	/* (n) 'global', 'local', 'field', 'method' */
//   const char *what;	/* (S) 'Lua', 'C', 'main', 'tail' */
//   const char *source;	/* (S) */

class val Stopwatch
    var _t1: U64

    new val create() =>
        _t1 = Time.nanos()

    fun elapsedSeconds() : F64 =>
        let t2: U64 = Time.nanos()
        (t2-_t1).f64()/1000000000.0