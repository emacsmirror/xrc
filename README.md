xrc
===

Syntax sugar and other goodies for working with xml-rpc.el

Using xml-rpc is prone to code like:

    (setq myurl "http://hostname:port/path")
    (xml-rpc-method-call myurl 'method "arg")
    (xml-rpc-method-call myurl 'other-method "other-arg")

This library lets us instead write:

    (xrc-defcaller service :url "http://hostname:port/path")
    (service 'method "arg")
    (service 'other-method "other-arg")

Its syntactical sugar that makes a difference for exploratory programming, but could also provide benefits such as sanity checks on method names an arguments for XML-RPC services.

Append :checked-p t to the end of the xrc-defcaller line to have an error raised immediately by the library if a method is called that is not supported by the endpoint.

