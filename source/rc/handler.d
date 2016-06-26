module rc.handler;

import rc.allocator;

version(rcdebugprint)
{
    pragma(msg,"!!use rc debug print");
    import std.stdio;
}

version(unittest)
{
    import std.range;
    import std.array;
    import std.format;
    import std.algorithm;
}

///
struct RCObject(T)
{
    ///
    T obj;
    ///
    alias obj this;

    ///
    this(this) { incRef(); }

    ///
    this( T o ) { obj = o; incRef(); }

    /// no increment ref
    package static auto make( T o )
    {
        RCObject!T ret;
        ret.obj = o;
        return ret;
    }

    version(rcdebugprint)
    {
        /// no increment ref
        package static auto make( string n, T o )
        {
            RCObject!T ret;
            ret.name = n;
            ret.obj = o;
            return ret;
        }

        this( string n, T o ) { name = n; obj = o; incRef(); }
        string name = "__obj__";
    }

    /// nothrow need for dispose
    ~this() nothrow
    {
        if( obj is null ) return;
        try
        {
            version(rcdebugprint)
                writefln( "  ** %12s dtor", name );
            decRef();
        }
        catch(Exception e)
        {
            import std.experimental.logger;
            try errorf( "ERROR: ", e );
            catch(Exception e) {}
        }
    }

    ///
    void incRef(string file=__FILE__,size_t line=__LINE__) // file and line for debug
    {
        version(rcdebugprint)
            writef( "  ** +++ ref %12s:  ", name );
        if( obj is null )
        {
            version(rcdebugprint)
                writefln( "is null (%s:%d)", file, line );
            return;
        }
        RC.incRef(obj);
        version(rcdebugprint)
            writefln( "ok [%d] (%s:%d)", refCount, file, line );
    }

    /// dispose object if refCount == 0
    void decRef(string file=__FILE__,size_t line=__LINE__) // file and line for debug
    {
        version(rcdebugprint)
            writef( "  ** --- ref %12s: ", name );
        if( obj is null )
        {
            version(rcdebugprint)
                writefln( "is null (%s:%d)", file, line ); // debug
            return;
        }
        assert( refCount > 0, "not null object have 0 refs" );

        obj = RC.decRef(obj);

        version(rcdebugprint)
        {
            if( obj is null )
                writefln( " ok no refs (%s:%d)", file, line );
            else
                writefln( " ok [%d] (%s:%d)", refCount, file, line );
        }
    }

    /// return 0 if object is null
    size_t refCount() @property const
    {
        if( obj is null ) return 0;
        return RC.refCount(obj);
    }

    ///
    void opAssign(X=this)( auto ref RCObject!T r )
    {
        version(rcdebugprint)
            writefln( "  opAssign %12s <- %12s", name, r.name );
        decRef();
        obj = r.obj;
        version(rcdebugprint)
            name = "<" ~ r.name ~ ">";
        incRef();
    }

    ///
    void opAssign(X=this)( auto ref T r )
    {
        version(rcdebugprint)
            writefln( "  opAssign %12s <- %12s", name, r.name );
        decRef();
        obj = r;
        version(rcdebugprint)
            name = "<" ~ r.name ~ ">";
        incRef();
    }
}

///
struct RCArray(T)
{
    /// if a slice this link to original array
    private T[] orig;
    ///
    T[] work;

    ///
    private void init( T[] origin, T[] slice )
    {
        if( slice !is null )
            assert( slice.ptr >= origin.ptr &&
                    slice.ptr < origin.ptr + origin.length,
                    "slice is not in original" );

        orig = origin;
        incRef();

        work = slice is null ? orig : slice;

        static if( isRCType!T )
            foreach( ref w; work ) w.incRef;
    }

    ///
    alias work this;

    ///
    this(this) { incRef(); }

    ///
    this( T[] orig, T[] slice=null ) { init( orig, slice ); }

    /// no increment ref
    package static auto make( T[] o )
    {
        RCArray!T ret;
        ret.orig = o;
        ret.work = o;
        return ret;
    }

    version(rcdebugprint)
    {
        /// no increment ref
        package static auto make( string n, T[] o )
        {
            RCArray!T ret;
            ret.name = n;
            ret.orig = o;
            ret.work = o;
            return ret;
        }

        this( string n, T[] orig, T[] slice=null ) // debug
        {
            name = n;
            init( orig, slice );
        }

        auto opSlice( size_t i, size_t j )
        { return RCArray!T( name~".p", orig, work[i..j] ); }
    }
    else
    {
        ///
        auto opSlice( size_t i, size_t j )
        { return RCArray!T( orig, work[i..j] ); }
    }

    ///
    void opAssign(X=this)( auto ref RCArray!T arr )
    {
        decRef();
        init( arr.orig, arr.work );
        // incRef in init
    }

    ///
    void incRef(string file=__FILE__,size_t line=__LINE__) // file and line for debug
    {
        version(rcdebugprint)
            writef( "  [] +++ ref %12s:  ", name );
        if( orig is null )
        {
            version(rcdebugprint)
                writefln( "is null (%s:%d)", file, line );
            return;
        }
        RC.incRef(orig);
        version(rcdebugprint)
            writefln( "ok [%d] (%s:%d)", refCount, file, line );
    }

    /// dispose array if `refCount == 0`
    void decRef(string file=__FILE__,size_t line=__LINE__) // file and line for debug
    {
        version(rcdebugprint)
            writef( "  [] --- ref %12s: ", name );
        if( orig is null )
        {
            version(rcdebugprint)
                writefln( "is null (%s:%d)", file, line );
            return;
        }

        assert( refCount > 0, "not null object have 0 refs" );

        orig = RC.decRef(orig);

        version(rcdebugprint)
        {
            if( orig is null )
                writefln( " ok no refs (%s:%d)", file, line );
            else
                writefln( " ok [%d] (%s:%d)", refCount, file, line );
        }
    }

    ///
    size_t refCount() @property const
    {
        if( orig is null ) return 0;
        return RC.refCount(orig);
    }

    version(rcdebugprint)
    {
        private string _name = "__arr__";
        string name() const @property { return _name; }
        void name( string n ) @property { _name = n; }
    }

    ~this()
    {
        version(rcdebugprint)
            writefln( "[] %s dtor start", name );

        if( refCount )
        {
            /+ logic:
                if `orig` saved only in this object
                it means what only `work` set must have `refCount` > 0
                otherwise it means what one ore more elements are saved
                outside of `orig` and on dispose(orig) they must be saved
             +/
            if( refCount == 1 )
            {
                static if( isRCType!T )
                    foreach( ref w; orig )
                        if( w.refCount )
                            // `work` set decriments futher
                            w.incRef;
            }

            static if( isRCType!T )
                foreach( ref w; work ) w.decRef;

            // if `orig` saved only in this object
            // additional decriment for all performs
            // if they isRCType because RCObject and
            // RCArray have decriment in destructor
            decRef;
        }
    }
}

/// true if T is RCObject or RCArray
template isRCType(T)
{
    static if( is( T E == RCObject!X, X ) || is( T E == RCArray!X, X ) )
        enum isRCType = true;
    else
        enum isRCType = false;
}

///
auto rcMake(T,A...)( A args )
{ return RCObject!(T).make( RC.make!T(args) ); }

///
unittest
{
    static string[] log;

    static class Par
    {
        this( uint i ) { log ~= "+par"; }
        ~this() { log ~= "-par"; }
    }

    static class Ch : Par
    {
        this() { super(1); log ~= "+ch"; }
        ~this() { log ~= "-ch"; }
    }

    assert( log.length == 0 );

    auto inc = 0;
    {
        RCObject!Ch c;
        {
            auto a = rcMake!Ch();
            assert( equal( log, ["+par","+ch"] ) );
            assert( a.refCount == 1 );
            auto b = a;
            assert( equal( log, ["+par","+ch"] ) );
            assert( a.refCount == 2 );
            assert( b.refCount == 2 );
            c = a;
            assert( a.refCount == 3 );
            assert( b.refCount == 3 );
            assert( c.refCount == 3 );
            b = rcMake!Ch();
            assert( a.refCount == 2 );
            assert( b.refCount == 1 );
            assert( c.refCount == 2 );
            assert( equal( log, ["+par","+ch","+par","+ch"] ) );
            b = rcMake!Ch();
            assert( a.refCount == 2 );
            assert( b.refCount == 1 );
            assert( c.refCount == 2 );
            assert( equal( log, ["+par","+ch","+par","+ch",
                                 "+par","+ch", // new Ch stored in b
                                 "-ch","-par" // old Ch in b
                                ] ) );
        }
        assert( c.refCount == 1 );
    }
    assert( equal( log, ["+par","+ch","+par","+ch",
                         "+par","+ch","-ch","-par",
                         "-ch","-par","-ch","-par"] ) );
}

unittest
{
    static string[] log;

    static class A
    {
        this() { log ~= "+"; }
        ~this() { log ~= "-"; }
    }

    static class B
    {
        A a;
        this() { this.a = RC.make!A(); }
        this( A a )
        {
            this.a = a;
            RC.incRef(a);
        }

        ~this() { RC.decRef(a); }
    }

    {
        assert( log.length == 0 );
        RCObject!B b;
        {
            auto a = rcMake!A();
            auto x = rcMake!B(a);
            assert( equal( log, ["+"] ) );
            assert( RC.refCount(x.a) == 2 );
            assert( x.refCount == 1 );
            b = x;
            assert( a.refCount == 2 );
            assert( RC.refCount(x.a) == 2 );
            assert( x.refCount == 2 );
            x = rcMake!B();
            assert( b.refCount == 1 );
            assert( x.refCount == 1 );
            assert( a.refCount == 2 );
            assert( a.obj is b.a );
            assert( RC.refCount(b.a) == 2 );
            assert( RC.refCount(x.a) == 1 );
        }
        assert( RC.refCount(b.a) == 1 );
        assert( b.refCount == 1 );
        assert( equal( log, ["+","+","-"] ) );
    }
    assert( equal( log, ["+","+","-","-"] ) );
}

///
auto rcMakeArray(T,A...)( A args )
{ return RCArray!(T).make( RC.makeArray!T(args) ); }

unittest
{
    static string[] log;
    static string[] exp;
    static void change(string s)( int[] i... )
    { exp ~= i.map!(a=>format("%s%d",s,a)).array; }
    static void add( int[] i... ) { change!"+"(i); }
    static void rem( int[] i... ) { change!"-"(i); }

    static class A
    {
        int no;
        this( int i ) { no=i; log ~= format("+%d",i); }
        ~this() { log ~= format("-%d",no); }
    }

    alias RCA = RCObject!A;

    {
        RCA obj1;
        RCA obj2;

        assert( equal( log, exp ) );
        {
            RCArray!RCA tmp;
            {
                auto arr = rcMakeArray!RCA(6);
                assert( equal( log, exp ) );
                foreach( int i, ref a; arr )
                {
                    a = rcMake!A(i);
                    add(i);
                }
                assert( equal( log, exp ) );

                foreach( ref a; arr )
                    assert( a.refCount == 1 );

                obj1 = arr[1];
                obj2 = arr[2];

                assert( equal( log, exp ) );

                assert( obj1.refCount == 2 );
                assert( obj2.refCount == 2 );
                assert( arr[1].refCount == 2 );
                assert( arr[2].refCount == 2 );

                arr[2] = rcMake!A(11);
                add(11);
                assert( equal( log, exp ) );
                assert( obj2.refCount == 1 );
                assert( arr[2].refCount == 1 );
                assert( arr[2].obj != obj2.obj );

                arr[3] = rcMake!A(88);
                add(88); rem(3);
                assert( equal( log, exp ) );
                assert( arr[3].refCount == 1 );

                tmp = arr[3..5];
                assert( equal( log, exp ) );
                assert( arr[0].refCount == 1 );
                assert( arr[1].refCount == 2 );
                assert( arr[2].refCount == 1 );
                assert( arr[2].obj.no == 11 );
                assert( arr[3].refCount == 2 );
                assert( arr[3].obj.no == 88 );
                assert( arr[4].refCount == 2 );
                assert( arr[5].refCount == 1 );
            }
            rem( 0, 11, 5 );
            assert( equal( log, exp ) );
        }
        rem( 88, 4 );
        assert( equal( log, exp ) );
        assert( obj1.refCount == 1 );
        assert( obj1.obj.no == 1 );
        assert( obj2.refCount == 1 );
        assert( obj2.obj.no == 2 );
    }
    rem( 2, 1 );
    assert( equal( log, exp ) );
}

//
unittest
{
    static string[] log; // what happens
    static string[] exp; // expected

    // write to expected
    static void change(string s)( int[] i... )
    { exp ~= i.map!(a=>format("%s%d",s,a)).array; }

    // ditto
    static void add( int[] i... ) { change!"+"(i); }
    // ditto
    static void rem( int[] i... ) { change!"-"(i); }

    // writes to log construction and destruction events
    static class A
    {
        int no;
        this( int i ) { no=i; log ~= format("+%d",i); }
        ~this() { log ~= format("-%d",no); }
    }

    alias RCA = RCObject!A;

    {
        RCA obj;
        {
            RCArray!RCA tmp1;
            {
                RCArray!RCA tmp2;
                {
                    assert( equal( log, exp ) );
                    auto arr = rcMakeArray!RCA(6);
                    assert( equal( log, exp ) );
                    foreach( int i, ref a; arr )
                    {
                        a = rcMake!A(i);
                        add(i);
                    }
                    assert( equal( log, exp ) );
                    assert( arr[0].refCount == 1 );
                    assert( arr[1].refCount == 1 );
                    assert( arr[2].refCount == 1 );
                    assert( arr[3].refCount == 1 );
                    assert( arr[4].refCount == 1 );
                    assert( arr[5].refCount == 1 );

                    tmp1 = arr[1..4];
                    assert( equal( log, exp ) );
                    assert( arr[0].refCount == 1 );
                    assert( arr[1].refCount == 2 );
                    assert( arr[2].refCount == 2 );
                    assert( arr[3].refCount == 2 );
                    assert( arr[4].refCount == 1 );
                    assert( arr[5].refCount == 1 );

                    tmp2 = arr[3..5];
                    assert( equal( log, exp ) );
                    assert( arr[0].refCount == 1 );
                    assert( arr[1].refCount == 2 );
                    assert( arr[2].refCount == 2 );
                    assert( arr[3].refCount == 3 );
                    assert( arr[4].refCount == 2 );
                    assert( arr[5].refCount == 1 );

                    obj = tmp2[0];
                    assert( equal( log, exp ) );
                    assert( arr[0].refCount == 1 );
                    assert( arr[1].refCount == 2 );
                    assert( arr[2].refCount == 2 );
                    assert( arr[3].refCount == 4 );
                    assert( arr[4].refCount == 2 );
                    assert( arr[5].refCount == 1 );
                }
                rem(0,5);
                assert( equal( log, exp ) );
                assert( tmp1[0].refCount == 1 );
                assert( tmp1[1].refCount == 1 );
                assert( tmp1[2].refCount == 3 );

                assert( obj.refCount == 3 );

                assert( tmp2[0].refCount == 3 );
                assert( tmp2[0].obj.no == 3 );
                assert( tmp2[1].refCount == 1 );
                assert( tmp2[1].obj.no == 4 );
            }
            rem(4);
            assert( equal( log, exp ) );
            assert( tmp1[0].refCount == 1 );
            assert( tmp1[1].refCount == 1 );
            assert( tmp1[2].refCount == 2 );
            assert( obj.refCount == 2 );
        }
        rem(1,2);
        assert( equal( log, exp ) );
        assert( obj.refCount == 1 );
    }
    rem(3);
    assert( equal( log, exp ) );
}

version(rcdebugprint)
{
    auto rcMakeNamed(T,A...)( string name, A args )
    { return RCObject!(T).make( name, RC.make!T(args) ); }

    auto rcMakeNamedArray(T,A...)( string name, A args )
    { return RCArray!(T).make( name, RC.makeArray!T(args) ); }
}
