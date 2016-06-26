#!/bin/env dub
/+ dub.sdl:
    name "rcexample"
    dependency "rc" path=".."
    versions "rcdebugprint"
 +/
import std.stdio;
import std.format;
import std.algorithm;

import rc;

version(rcdebugprint){}
else static assert(0,"need version 'rcdebugprint'");

class Base
{
    this() { writeln( "Base ctor" ); }
    ~this() { writeln( "Base dtor" ); }
}

class A : Base
{
    uint idx;
    this( uint i )
    {
        idx = i;
        writefln( "create #%04d", idx );
    }
    uint foo() { return idx; }
    ~this() { writefln( "destroy #%04d", idx ); }
}

void log(T)( ref RCObject!T rch, string file=__FILE__, size_t line=__LINE__ )
{
    writefln( "** %12s: #%04d (refs: %d) (%s:%d)",
            rch.name, rch.foo(), rch.refCount, file, line );
}

void logArr(T)( ref RCArray!T rca, string file=__FILE__, size_t line=__LINE__ )
{
    writefln( "[] %12s: len: %d (refs: %d) (%s:%d)",
            rca.name, rca.length, rca.refCount, file, line );
}

struct TestWriter
{
    string name;
    this( string n ) { name = n; writefln( "##### %s start #####", n ); }
    ~this() { writefln( "##### %s finish #####\n", name ); }
}

auto testWriter( string name=__FUNCTION__  ) { return TestWriter(name); }

void testScope()
{
    auto __ = testWriter;

    auto obj1 = rcMakeNamed!A( "obj1", 1 );
    log( obj1 );
    {
        auto obj2 = obj1;
        log( obj1 );
        obj2 = rcMakeNamed!A( "obj2", 2 );
        log( obj1 );
        log( obj2 );
        obj1 = obj2;
        log( obj1 );
        log( obj2 );
    }
    log( obj1 );
}

class B
{
    A a;

    this( A a )
    {
        this.a = a;
        RC.incRef(a);
        writeln( "B ctor" );
    }

    int foo() { return 0; }

    ~this()
    {
        RC.decRef(a);
        writeln( "B dtor" );
    }
}

void testObj()
{
    auto __ = testWriter;

    RCObject!B b;

    {
        auto x = rcMakeNamed!B( "x", RC.make!A(12) );
        log( x );
        b = x;
        log( x );
    }

    log( b );
}

class C
{
    uint idx;
    this( uint i )
    {
        idx = i;
        writefln( "+++ #%04d", idx );
    }
    uint foo() { return idx; }
    ~this() { writef( "--- #%04d", idx ); }
}

void testObjArr()
{
    auto __ = testWriter;

    RCObject!C obj1;
    RCObject!C obj2;

    obj1.name = "empty1";
    obj2.name = "empty2";

    {
        writeln( "enter 'tmp' scope" );
        RCArray!(RCObject!C) tmp;
        tmp.name = "tmp";

        {
            writeln( "enter 'arr' scope" );
            auto arr = rcMakeNamedArray!(RCObject!C)( "arr", 6 );
            logArr( arr );
            foreach( int i, ref a; arr )
                a = rcMakeNamed!C( format("arr[%d]", i), i );

            foreach( i, ref a; arr ) log( a );
            writeln();

            obj1 = arr[1];
            obj2 = arr[2];

            foreach( i, ref a; arr ) log( a );
            writeln();

            log( obj1 );
            log( obj2 );
            writeln();

            arr[2] = rcMakeNamed!C( "ex 11", 11 );
            arr[3] = rcMakeNamed!C( "ex 88", 88 );
            writeln();

            foreach( i, ref a; arr ) log( a );
            writeln();

            log( obj1 );
            log( obj2 );
            writeln();

            tmp = arr[3..5];
            writeln();

            logArr( arr );
            logArr( tmp );
            writeln();

            foreach( i, ref a; arr ) log( a );
            writeln();

            log( obj1 );
            log( obj2 );
            writeln("-------------------");
        }

        writeln( "'arr' scope exited" );

        logArr( tmp );
        foreach( i, ref a; tmp ) log( a );
        writeln();
        log( obj1 );
        log( obj2 );
        writeln("-------------------");
    }
    writeln( "'tmp' scope exited" );
    log( obj1 );
    log( obj2 );
}

void testObjArr2()
{
    auto __ = testWriter;

    alias RCC = RCObject!C;

    RCC obj;
    {
        RCArray!RCC tmp1;
        {
            RCArray!RCC tmp2;
            {
                writeln( "enter 'arr' scope" );
                auto arr = rcMakeNamedArray!RCC( "arr", 6 );
                logArr( arr );
                foreach( int i, ref a; arr )
                    a = rcMakeNamed!C( format("arr[%d]", i), i );

                tmp1 = arr[1..4];
                tmp2 = arr[3..5];
                obj = tmp2[0];
                tmp1.name = "tmp1";
                tmp2.name = "tmp2";

                writeln();
                foreach( i, ref a; arr ) log( a );
                writeln();
                log( obj );
                logArr( tmp1 );
                logArr( tmp2 );
                writeln();
                writeln("-------------------");
            }
            writeln( "'arr' scope exited" );

            logArr( tmp1 );
            foreach( i, ref a; tmp1 ) log( a );
            writeln();

            logArr( tmp2 );
            foreach( i, ref a; tmp2 ) log( a );
            writeln();

            log( obj );
            writeln("-------------------");
        }
        writeln( "'tmp' scope exited" );

        logArr( tmp1 );
        foreach( i, ref a; tmp1 ) log( a );
        writeln();

        log( obj );
        writeln("-------------------");
    }
    log( obj );
}

void main()
{
    testScope();
    testObj();
    testObjArr();
    testObjArr2();
}
