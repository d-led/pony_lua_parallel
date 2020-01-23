use "time"

class val Stopwatch
    var _t1: U64

    new val create() =>
        _t1 = Time.nanos()

    fun elapsedSeconds() : F64 =>
        let t2: U64 = Time.nanos()
        (t2-_t1).f64()/1000000000.0