+++
description = "Using pointers with Go sync.Pool is not the only thing that you have to consider to avoid allocations, you'll have to pay attention what can cause to move to heap when using the objects that you get from and put into the pool"
date = "2025-10-15T17:00:00Z"
title = "Moved to the heap in Go standard pool"
tags = ["golang"]
categories = [
  "software development"
]
+++

The other day I was applying some changes to make a logic that was processing a list of "objects" sequentially to do it
concurrently<sup>[1](#footnote-1)</sup>.

The logic itself doesn't matter for the purpose of this blog, what it only matters is that that to avoid a slice
allocation of N element on each batch that was processing, the sequential logic was reusing a slice, so to reuse slices
on the current implementation, I used the standard [sync.Pool](https://pkg.go.dev/sync#Pool).

In this post, I will use a slice of bytes as simple example, to make clear what my explanations and avoid confusion with
the all the stuff that the original implementation entails.

## Use pointers

Reading the documentation, one can realize (if you slide to the [example](https://pkg.go.dev/sync#example-Pool)) that
pool must use pointers to avoid allocations

```go
var bufPool = sync.Pool{
	New: func() any {
		// The Pool's New function should generally only return pointer
		// types, since a pointer can be put into the return interface
		// value without an allocation:
		return new(bytes.Buffer)
	},
}
```

## Pointers to slices

Because the pool was storing slices, I started to mess with pointers to manipulate the slices gotten from it.

Let's see in code, what I mean

```go
s := pool.Get().(*[]byte)
s2 := *s
s2 = s2[:0] // Reset the slice before use
s2 = append(s2, 10)

// you'll do something else here and  when you don't need this slice anymore
pool.Put(&s2)
```

This doesn't seem that much, but if you account that, the current logic has to keep the gotten slice during iterations
until the N elements configured in that batch is reached, you get in the call back function which is called for each
element retrieved the following logic

```go
s = pool.Get().(*[]byte)

ranger.Range(func() {
	s2 := *s
	s2 = append(s2, 10)

	// Some more logic goes here, and at some point under a conditional you
	// capture `s2` into a goroutine and you put back the slice into the pool
	// before exiting, and this callback get a new slice from the pool an
	// assigned to `s`.
})
```

OK, not to complex, but then I though, instead of using a temporary variable, use the pointer directly with some utility
functions/wrappers, something like this

```go
get := func() []byte {
	s := pool.Get().(*[]byte)
	return *s
}

put := func(s []byte) {
	pool.Put(&s)
}
```

## Evil allocations

During the review of my changes, there was a comment to replace my utility functions/wrapper by others more ergonomic.

That made me think, all these wrappers going to save the allocations saved because of using pointers in the pool?

Myself response was: I don't know, let's write some **dirty** benchmarks abstracting a pool usage, not from the real
implementation, for simplicity and because I was only interested in finding out the pool behavior. Actually, the
previous snippets of codes were extracted from these benchmarks.

I started to write 3 different options, including using values in the pool instead of pointers, but when I saw that
using values was doing the same allocations than using pointers with wrappers, I wrote a few more, some of them with a
minimal changes that were expected not to provoke any allocation change because they were more about to reduce lines of
code while eliminating intermediary variables by moving the operations into the same line.

You can find it [here](https://gist.github.com/ifraixedes/912c6260ac5de02c649c05140b27f9bb) if you're interested in
looking at it.

Running the benchmarks with `go test -bench . -benchmem`, I quickly saw which approach was fine because it didn't
produce any allocation.

Based on those results, it looked that it isn't a good idea to wrap anything in functions and just use directly the
pointers to make sure that there isn't unexpected allocations.

As a side note, the idea of having some wrappers was to avoid code repetition that was using intermediate variables to
dereference the pointer to the slice to add elements and reset it, until my colleague mentioned that I could simplified
with online just dereferencing when passed to `append` and when resetting, but also dereferencing when assigning the
result of those operations, so this ended up like

```go
s = pool.Get().(*[]byte)
*s = (*s)[:0]
*s = append(*s, 10)
```

And with that simplification, there weren't needed wrappers anymore because there was nothing to encapsulate, unless
that seeing those many `*` bothers you.

## The culprit was "moved to heap"

This could end up here, but I was curious about where those allocations where originated. I took 3 of the benchmarks and
check the output of `go test -gcflags='-m' pool_test.go`.

The output is quite verbose, but looking at it, I found that the important parts for this matter was the lines that
contained `moved to heap`.

Following are the 3 benchmarks that I put in a single file to be easy to inspect the `moved to heap` lines.

### Benchmark with 1 allocation

```go
package tmp

import (
	"sync"
	"testing"
)

func BenchmarkPoolGetPut(b *testing.B) {
	pool := sync.Pool{
		New: func() any {
			s := make([]byte, 0, 10000)
			return &s
		},
	}

	get := func() []byte {
		s := pool.Get().(*[]byte)
		return *s
	}

	put := func(s []byte) {
		pool.Put(&s)
	}

	s := get()
	if len(s) != 0 {
		b.Error("returned slice doesn't have the expected number of elements")
	}
	s = s[:0]
	put(s)

	for b.Loop() {
		s := get()
		s = append(s, 10)
		if len(s) != 1 {
			b.Error("returned slice doesn't have the expected number of elements")
		}
		s = s[:0]
		put(s)
	}
}
```

`go test -gcflags='-m' bench_get_put_test.go 2>&1 | grep 'moved to heap'`

```
./bench_get_put_test.go:11:4: moved to heap: s
./bench_get_put_test.go:9:2: moved to heap: pool
./bench_get_put_test.go:30:5: moved to heap: s
./bench_get_put_test.go:21:14: moved to heap: s
```

We can ignore line 9 and 11 for this one and for the rest, that's obvious that a new slice has to be allocated in the
heap when it's created.

The important ones are 21 and 30, which is where a passed slice to the `put` function makes the slice to be moved to the
heap.

### Benchmark with 2 allocations

```go
package tmp

import (
	"sync"
	"testing"
)

func BenchmarkDoubleAllocation(b *testing.B) {
	pool := sync.Pool{
		New: func() any {
			s := make([]byte, 0, 10000)
			return &s
		},
	}

	appendByte := func(buffer *[]byte, val byte) *[]byte {
		b := *buffer
		b = append(b, val)
		return &b
	}

	reset := func(buffer *[]byte) *[]byte {
		b := *buffer
		b = b[:0]
		return &b
	}

	s := pool.Get().(*[]byte)
	if len(*s) != 0 {
		b.Error("returned slice doesn't have the expected number of elements")
	}
	s = reset(s)
	pool.Put(s)

	for b.Loop() {
		s := pool.Get().(*[]byte)
		s = appendByte(s, 10)
		if len(*s) != 1 {
			b.Error("returned slice doesn't have the expected number of elements")
		}
		s = reset(s)
		pool.Put(s)
	}
}
```

`go test -gcflags='-m' bench_double_allocation_test.go  2>&1 | grep 'moved to heap'`

```
./bench_double_allocation_test.go:11:4: moved to heap: s
./bench_double_allocation_test.go:17:3: moved to heap: b
./bench_double_allocation_test.go:23:3: moved to heap: b
./bench_double_allocation_test.go:9:2: moved to heap: pool
./bench_double_allocation_test.go:32:11: moved to heap: b
```

The important ones are the 17 and 23. My understanding is that 32 is moved to the heap, but because it's a pointer it
doesn't allocate.

### Benchmark with 0 allocations

```go
package tmp

import (
	"sync"
	"testing"
)

func BenchmarkZero(b *testing.B) {
	pool := sync.Pool{
		New: func() any {
			s := make([]byte, 0, 10000)
			return &s
		},
	}

	appendByte := func(buffer *[]byte, val byte) *[]byte {
		b := *buffer
		b = append(b, val)
		*buffer = b
		return buffer
	}

	reset := func(buffer *[]byte) *[]byte {
		b := *buffer
		b = b[:0]
		*buffer = b
		return buffer
	}

	s := pool.Get().(*[]byte)
	if len(*s) != 0 {
		b.Error("returned slice doesn't have the expected number of elements")
	}
	s = reset(s)
	pool.Put(s)

	for b.Loop() {
		s := pool.Get().(*[]byte)
		s = appendByte(s, 10)
		if len(*s) != 1 {
			b.Error("returned slice doesn't have the expected number of elements")
		}
		s = reset(s)
		pool.Put(s)
	}
}
```

`go test -gcflags='-m' bench_zero_allocation_test.go 2>&1 | grep 'moved to heap'`

```
./bench_zero_allocation_test.go:11:4: moved to heap: s
./bench_zero_allocation_test.go:9:2: moved to heap: pool
```

There is nothing moved to the heap, hurray!

Obviously, simplifying the wrappers to online dereferencing the pointers as commented above

```go
	appendByte := func(buffer *[]byte, val byte) *[]byte {
		*buffer = append(*buffer, val)
		return buffer
	}

	reset := func(buffer *[]byte) *[]byte {
		*buffer = (*buffer)[:0]
		return buffer
	}
```

produces the same result, but it defeats the purpose of them, because we can place the one line wrappers where they are
called.

## Conclusion

When dealing with `sync.Pool` use the same pointers that you get to put them into to avoid "moved to heap" and cause
undesired allocations.

If a function creates a variable and it returns a reference to it, it's moved to the heap. Although, I could expect
this because of Rust learned lessons, I missed the point in Go.

---
<sup id="footnote-1">1</sup> https://review.dev.storj.tools/c/storj/storj/+/18859
These are the changes that I worked and were I had to use `sync.Pool` if it's your interest
