using Mux
using JSON
using WebIO

"""
    webio_serve(app, port=8000)

Serve a Mux app which might return a WebIO node.
"""
function webio_serve(app, port=8000)
    @app http = (
        Mux.defaults,
        app,
        Mux.notfound(),
    )

    @app websock = (
        Mux.wdefaults,
        route("/webio-socket", create_socket),
        Mux.wclose,
        Mux.notfound(),
    )

    serve(http, websock, port)
end

immutable WebSockConnection <: AbstractConnection
    sock
end

function create_socket(req)
    sock = req[:socket]
    conn = WebSockConnection(sock)

    t = @async while isopen(sock)
        try
            data = read(sock)

            msg = JSON.parse(String(data))
            WebIO.dispatch(conn, msg)
        catch err
            if isa(err, WebSockets.WebSocketClosedError)
                println("Caught WebSockets.WebSocketClosedError: $err")
                break
            else
                @show typeof(err) err
                rethrow(err)
            end
        end
    end

    wait(t)
end

function Base.send(p::WebSockConnection, data)
    @show isopen(p.sock)
    if isopen(p.sock)
        println("pre write to p.sock")
        write(p.sock, sprint(io->JSON.print(io,data)))
        println("post write to p.sock")
    else
        warn("attempting to write to closed connection in $(@__FILE__):59")
    end
end

Base.isopen(p::WebSockConnection) = isopen(p.sock)

function Mux.Response(o::Node)
    Mux.Response(
        """
        <!doctype html>
        <html>
          <head>
            <meta charset="UTF-8">
            <script src="/pkg/WebIO/webio.bundle.js"></script>
            <script src="/pkg/WebIO/providers/mux_setup.js"></script>
          </head>
          <body>
            $(stringmime(MIME"text/html"(), o))
          </body>
        </html>
        """
    )
end

function WebIO.register_renderable(T::Type)
    Mux.Response(x::T) = Mux.Response(WebIO.render(x))
    WebIO.register_renderable_common(T)
end
