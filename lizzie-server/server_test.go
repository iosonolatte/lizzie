package main

import (
	"errors"
	"io"
	"net"
	"testing"
)

func TestContainsFold(t *testing.T) {
	cases := []struct {
		s, sub string
		want   bool
	}{
		{"", "", true},
		{"abc", "", true},
		{"abc", "abcdef", false},
		{"Hello, World!", "world", true},
		{"Hello, World!", "WORLD", true},
		{"Hello, World!", "World!", true},
		{"closed connection", "Closed", true},
		{"broken pipe", "BROKEN PIPE", true},
		{"some error", "missing", false},
		{"", "x", false},
		{"x", "", true},
	}
	for _, c := range cases {
		if got := containsFold(c.s, c.sub); got != c.want {
			t.Errorf("containsFold(%q, %q) = %v, want %v", c.s, c.sub, got, c.want)
		}
	}
}

func TestIsClosed(t *testing.T) {
	cases := []struct {
		name string
		err  error
		want bool
	}{
		{"nil", nil, true},
		{"EOF", io.EOF, true},
		{"closed pipe", io.ErrClosedPipe, true},
		{"net closed", &net.OpError{Op: "read", Err: errors.New("use of closed network connection")}, true},
		{"use of closed", errors.New("use of closed connection"), true},
		{"broken pipe", errors.New("write: broken pipe"), true},
		{"forcibly closed", errors.New("connection forcibly closed by remote host"), true},
		{"random error", errors.New("connection reset by peer"), false},
		{"other", errors.New("some other failure"), false},
	}
	for _, c := range cases {
		if got := isClosed(c.err); got != c.want {
			t.Errorf("isClosed(%s: %v) = %v, want %v", c.name, c.err, got, c.want)
		}
	}
}
