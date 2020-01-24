actor Worker
    let _id: String
    let _env: Env

    new create(env: Env, id: String) =>
        _env = env
        _id = id

    be work(task: String) =>
        _env.out.print("Worker["+_id+"]: working on task '"+task+"'")
        //
        let l = Lua
        (var res, var err) = l.run_string("
            local sleep_seconds = math.random(1, 3)
            local t0 = os.clock()
            while os.clock() - t0 <= sleep_seconds do end
            return 'ok'
        ")
        _env.out.print("Worker["+_id+"]: finished task '"+task+"'")
