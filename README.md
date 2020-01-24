# pony_lua_parallel
 using Pony to parallelize a single threaded C program (Lua)

[![Build Status](https://travis-ci.org/d-led/pony_lua_parallel.svg?branch=master)](https://travis-ci.org/d-led/pony_lua_parallel) [![Build status](https://ci.appveyor.com/api/projects/status/wp5hcrquow7ye56p/branch/master?svg=true)](https://ci.appveyor.com/project/d-led/pony-lua-parallel/branch/master)


## Building and Running

### Docker

```
docker-compose build --build-arg MAX_NUM=40
```

### Contents

See [main.pony](main.pony):

- `synchronous_demo`: calling [Lua](https://www.lua.org/manual/5.3/) synchronously from [Pony](http://tutorial.ponylang.org/) via FFI
- `asynchronous_demo`: creating an actor owning a Lua instance upon each request, and [waiting](https://stdlib.ponylang.io/promises-Promises/#join) for asynchronously arriving results via [Promises](https://patterns.ponylang.io/async/actorpromise.html)
- `lua_sending_messages_demo`: creating a fixed number of worker actors in Pony, and dispatching work to them from Lua
- [lua.pony](lua.pony): the problem-specific FFI based Lua 5.3 wrapper class

### CI

- Travis-CI runs on 1 virtual core, thus parallelism effects cannot be observed there.

```
Can't have --ponymaxthreads > physical cores, the number of threads you'd be running with (2 > 1)
```

- Appveyor seems to run on more than 1 core, and thus some parallelism can be observed
