use "promises"
use "cli"
use "math"
use "collections"
use "itertools"

// FFI
use @lua_tointegerx[I32](l: Pointer[None], index: I32, isnum: Pointer[None])
use @lua_gettop[I32](l: Pointer[None])
use @lua_pushstring[None](l: Pointer[None], s: Pointer[U8] tag)
use @lua_error[I32](l: Pointer[None])
use @lua_pushinteger[None](l: Pointer[None], n: I32)

actor Main
    let _env: Env
    var max_num: I32 = 40

    new create(env: Env) =>
        _env = env

        configure()
        synchronous_demo()
        asynchronous_demo()
        c_code_calling_pony_demo()
        lua_sending_messages_demo()

    fun ref configure() =>
        try
            max_num = EnvVars(_env.vars)("MAX_NUM")?.i32()?
        end

    fun synchronous_demo() =>
        _env.out.print("MAX_NUM="+max_num.string())
        _env.out.print("synchronous...")
        let stopwatch = Stopwatch
        // calculate the results in sequence
        with l = Lua do
            var count: I32 = max_num
            while count >= 0 do
                // and print the results one by one
                let res = l.fibonacci(count)
                _env.out.print("fibonacci(" + count.string() + ")=" + res.string())
                count = count - 1
            end
        end
        _env.out.print("--> elapsed seconds: "+stopwatch.elapsedSeconds().string())

    fun asynchronous_demo() =>
        _env.out.print("asynchronous...")
        var count: I32 = max_num
        var stopwatch = Stopwatch
        // collect all asynchronous result promises in an array
        let results = Array[Promise[String]]

        // fill the array of result promises
        while count >= 0 do
            let async_lua = LuaAsync
            let promise = Promise[String]
            // start calculating asynchronously
            async_lua.fibonacci(count, promise)
            results.push(promise)
            count = count - 1
        end

        // wait for all results
        Promises[String].join(results.values())
            // when all promises are fulfilled
            .next[None]({(a: Array[String val] val) =>
                // print all values at once in the order received
                for s in a.values() do
                    _env.out.print(s)
                end
                // done
                _env.out.print("--> elapsed seconds: "+stopwatch.elapsedSeconds().string())
            })

        _env.out.print("main: done, waiting for promises")

    fun c_code_calling_pony_demo() =>
        _env.out.print("Calling Pony from Lua...")
        let l = Lua

        // register a Pony lambda as a lua function
        l.register_function("pony_fibonacci", {(_l: Pointer[None]): I32 =>
            _env.out.print("Pony called from Lua")

            // get the expected single parameter (no parameter count check for now)
            let n = @lua_tointegerx(_l, @lua_gettop(_l), Pointer[None])

            // perform some validation in Pony
            if (n > U8.max_value().i32()) or (n < 0) then
                @lua_pushstring(_l, (n.string() + " is out of range").cstring())
                @lua_error(_l)
            else
                let res = Fibonacci(n.u8())
                @lua_pushinteger(_l, res.i32())
            end

            // return value count (here, 1: either an error, or a result)
            I32(1)
        })
        // valid input
        (var res, var err) = l.run_string("return 'pony_fibonacci(10)='..pony_fibonacci(10)")
        _env.out.print(res+err)

        // invalid input
        _env.out.print("Trying to pass invalid input to Pony...")
        (res, err) = l.run_string("return 'pony_fibonacci(-42)='..pony_fibonacci(-42)")
        _env.out.print(res+err)

    fun lua_sending_messages_demo() =>
        _env.out.print("Sending messages to Pony actors from Lua ...")

        let max_workers = USize(4)
        let workers = Iter[USize].create(Range(0, max_workers))
            .map[Worker]({(id) => Worker(_env, id.string()) })
            .collect(Array[Worker](max_workers))


        //
        let l = Lua

        //
        l.register_function("send_work", {(_l: Pointer[None]): I32 =>
            // get the expected single parameter (no parameter count check for now)
            let n = @lua_tointegerx(_l, @lua_gettop(_l), Pointer[None])

            let worker_id: USize = n.abs().usize() % max_workers

            try
                workers(worker_id)?.work(n.string())
            else
                _env.out.print("Wrong worker id: " + worker_id.string())
            end

            I32(0)
        })

        l.run_string("
            for i = 0, 12 do
                send_work(i)
            end
            return 'ok'
        ")