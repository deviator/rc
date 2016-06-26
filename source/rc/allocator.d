module rc.allocator;

import std.experimental.allocator;
import std.experimental.allocator.mallocator;
import std.experimental.allocator.building_blocks.affix_allocator;

static this() { RC.affixObj = allocatorObject(RC.affix); }

///
struct RC
{
static:
    ///
    alias affix = AffixAllocator!(Mallocator,size_t,size_t).instance;
    ///
    IAllocator affixObj;

    ///
    auto make(T,A...)( auto ref A args )
    { return incRef( affixObj.make!T(args) ); }

    ///
    T[] makeArray(T,A...)( size_t length )
    { return incRef( affixObj.makeArray!T(length) ); }

    ///
    T[] makeArray(T,A...)( size_t length, auto ref T init )
    { return incRef( affixObj.makeArray!T(length,init) ); }

    ///
    private void dispose(T)( T* p ) { affixObj.dispose(p); }

    ///
    private void dispose(T)( T p )
        if( is(T == class) || is(T == interface) )
    { affixObj.dispose(p); }

    ///
    private void dispose(T)( T[] arr ) { affixObj.dispose(arr); }

    ///
    ref size_t refCount(T)( T p )
        if( is(T == class) || is(T == interface) )
    { return affix.prefix( (cast(void*)p)[0..__traits(classInstanceSize,T)] ); }

    ///
    ref size_t refCount(T)( T* p )
    { return affix.prefix( (cast(void*)p)[0..T.sizeof] ); }

    ///
    ref size_t refCount(T)( T[] arr )
    { return affix.prefix( cast(void[])arr ); }

    ///
    auto incRef(T)( auto ref T p )
    {
        if( p is null ) return null;
        refCount(p)++;
        return p;
    }

    ///
    auto decRef(T)( T p )
    {
        if( p is null ) return null;

        if( refCount(p) > 0 )
        {
            refCount(p)--;
            if( refCount(p) == 0 )
            {
                dispose(p);
                return null;
            }
        }

        return p;
    }
}

unittest
{
    auto p = RC.make!int( 10 );
    assert( is( typeof(p) == int* ) );
    assert( *p == 10 );
    assert( RC.refCount(p) == 1 );
    p = RC.decRef(p);
    assert( p is null );
}

unittest
{
    static int inc = 0;

    static class A
    {
        this() { inc = 5; }
        ~this() { inc = 2; }
    }

    assert( inc == 0 );
    auto a = RC.make!A();
    assert( RC.refCount(a) == 1 );
    auto b = a;
    assert( RC.refCount(a) == 1 );
    RC.incRef(b);
    assert( RC.refCount(a) == 2 );
    assert( RC.refCount(b) == 2 );
    assert( inc == 5 );
    a = RC.decRef(a);
    assert( inc == 5 );
    assert( a !is null );
    a = RC.decRef(a);
    assert( inc == 2 );
    assert( a is null );
}
