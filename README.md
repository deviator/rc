### Reference counting

##### simple using
```d
import rc;
class A { }

class B
{
    A a;
    this( A a )
    {
        this.a = a;
        RC.incRef(a);
    }
    ~this()
    {
        RC.decRef(a);
    }
}

void main()
{
    auto a = rcMake!A;
    auto b = rcMake!B(a);

    import std.stdio;
    writeln( RC.refCount(a) ); // 2
}
```

##### using arrays and wraps
```d
import rc;

class A {}

void main()
{
    import std.stdio;

    RCObject!A obj;

    {
        RCArray!(RCObject!A) tmp;
        {
            auto arr = rcMakeArray!(RCObject!A)(4);
            foreach( ref a; arr )
                a = rcMake!A;
            assert( arr[0].refCount == 1 );
            assert( arr[1].refCount == 1 );
            assert( arr[2].refCount == 1 );
            assert( arr[3].refCount == 1 );

            tmp = arr[1..3];
            assert( arr[0].refCount == 1 );
            assert( arr[1].refCount == 2 );
            assert( arr[2].refCount == 2 );
            assert( arr[3].refCount == 1 );

            obj = arr[2];
            assert( arr[2].refCount == 3 );
        }
        // objects in arr[0] and arr[3] are deleted
        assert( tmp[0].refCount == 1 );
        assert( tmp[1].refCount == 2 ); // second in `obj`
    }
    // now delete arr[0]
    assert( obj.refCount == 1 );
}

```
