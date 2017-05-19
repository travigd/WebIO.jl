# WebIO

WebIO is a DSL for writing web-based widgets.

It works inside these interfaces to Julia:

- [Juno](http://junolab.org) - The hottest Julia IDE
- [IJulia](https://github.com/JuliaLang/IJulia.jl) - Jupyter notebooks for Julia
- [Blink](https://github.com/JunoLab/Blink.jl) - An [Electron](http://electron.atom.io/) wrapper you can use to make Desktop apps
- [Mux](https://github.com/JuliaWeb/Mux.jl) - A web server framework

Widgets once created with WebIO will work on any of these front-ends.

Setting up WebIO
---------------------

To install WebIO's Julia dependencies, run:

```julia
Pkg.clone("https://github.com/shashi/WebIO.jl.git")
```

## JavaScript dependencies

To use WebIO, you will need to install some JavaScript dependencies. This can be done on Linux and Mac by first installing [nodejs](https://nodejs.org/en/), and then running

```julia
using WebIO
WebIO.devsetup()
```
This will download and install [`yarn`](https://yarnpkg.com/) and then the dependencies, namely [webpack](https://webpack.github.io/) and [babel](https://babeljs.io/). These are used to develop and package the javascript parts of WebIO. The next step is to compile the JavaScript files into a *bundle*.

```julia
WebIO.bundlejs(watch=false)
```

This should create a file called `webio.bundle.js` under the `assets/` directory. `watch=true` starts a webpack server which watches for changes to the javascript files under `assets/` and recompiles them automatically. This is very useful as you incrementally make changes to the Javascript files.

_These steps will be optional once WebIO is released and will only be required when hacking on WebIO._

We plan to move this system to the build step once [julia#20082](https://github.com/JuliaLang/julia/issues/20082) is available in some form.

### Hello, World!: Getting things to display

After having loaded a front-end package, (one of IJulia, Atom, and Blink).

```julia
using WebIO
WebIO.setup()
```

If `WebIO.setup()` finished succesfully then you should be good to start creating simple UIs using the `dom""()` macro.

In IJulia, whenever a code cell returns a `WebIO.Node` object, IJulia will render it correctly.

![](assets/images/helloworld-ijulia.png)

On Blink, pass the object returned by `dom""` to `body!` of a window or page. This will replace the contents of the page with the rendered version of the object.

![](assets/images/helloworld-ijulia.png)

WebIO can be used with Mux with the following code

```
using WebIO
using Mux

WebIO.setup()

function myapp(req)
    dom"div"("Hello, World!")
end

webio_serve(page("/", req -> myapp(req)))
```

This will serve a page at port 8000 that will render the object returned by `myapp` function.

On Atom, when you execute an expression that returns a WebIO object, it will be rendered in a separate pane.

An introduction to the DOM
--------------------------

To create UIs with WebIO, we need to create something called [DOM](https://developer.mozilla.org/en-US/docs/Web/API/Document_Object_Model/Introduction) objects. DOM stands for "Document Object Model", you can think of the DOM as an intermediate structure that represents the underlying HTML. So for example,

```html
<div class="myDiv" id="myId">
    Hello, World!
</div>
```

would be represented as:

```julia
Node(:div, "Hello, World!", className="myDiv", id="myId")
```

In the DOM. This is of course, a virtual representation of the DOM in Julia. WebIO can take care of rendering that to the actual DOM inside a browser-based interface. (See setting up display section above to learn how to set up WebIO to display things)

Notice that in the HTML we used the `class` attribute, but we used `className` keyword argument while creating `Node`. This is because the DOM doesn't always closely resemble the HTML.

1. Keywords to `Node` are *properties*
2. Properties are [sometimes different from HTML *attributes*](http://stackoverflow.com/questions/258469/what-is-the-difference-between-attribute-and-property)

Specifically, here, the `class` attribute reflects as the `className` property of the DOM, hence we set it thus. To explicitly set an attribute instead of a property, pass in the attributes keyword argument. It must be set to the Dict of attribute-value pairs.

For example,
```julia
Node(:div, "Hello, World!", attributes=Dict("class"=>"myDiv"))
```

Another difference between HTML and DOM worth noting is in `style`

The purpose of `style` attribute or property is to define some [CSS](https://en.wikipedia.org/wiki/Cascading_Style_Sheets) that gives some style to a DOM node. The `style` *property* is a dictionary mapping properties to values. Whereas the `style` attribute in HTML is a string containing the CSS of the style!

Therefore, `<div style="background-color: black; color: white"></div>` in HTML is equivalent to `Node(:div, style=Dict(:color=>white, :backgroundColor=>"black"))`. Hiphenated CSS properties like 'background-color' are camelCased in the DOM version.

### The `dom""` macro

The `dom""` [*string macro*](http://docs.julialang.org/en/release-0.4/manual/metaprogramming/#non-standard-string-literals) can be used to simplify the syntax of creating DOM Nodes. The syntax for the macro is:

```julia
dom"div.<class>#<id>[<attr>=<value>,...]"(children...; props...)
```

And is equivalent to:

```julia
Node(:div, children..., className="<class>", id="<id>",
     attributes=Dict(attr1=>val1, attr2=>val2...); props...)
```

Everything except the tag ('div' in the example) is optional. So,

`dom"div"`, `dom"div.class1"`, `dom"div.class1.class2"`, `dom"div#my-id`, `dom"input.check[type=checkbox]"` are all valid invocations.

Todo list example
-----------------

The rest of the document describes the WebIO API. To illustrate the various affordances of WebIO, we will create a Todo list app as a running example.

Presumably, a todo item would need to store at least two fields: a `discription`, and a boolean `done` indicating whether the task is completed or not.

```julia
immutable TodoItem
    description::String
    done::Bool
end
```

A todo list would naturally contain a vector of `TodoItem`s and possibly a `title` field.

```julia
immutable TodoList
    title::String
    list::Vector{TodoItem}
end
```

The `TodoItem` and `TodoList` types together can represent the state of our todo app. For example,

```julia
mylist = TodoList("My todo list",
    [TodoItem("Make my first WebIO widget", false),
     TodoItem("Make a pie", false)])

```

In web framework jargon the these types together would be called the `Model` (as in [Model-View-Controller](https://en.wikipedia.org/wiki/Model_view_controller)) of the app.

Let's start building the pieces we require for a todo list UI using WebIO.


### Showing a todo item

Let's come back to our example of creating a todo list app with our newfound knowledge of how to create some output with WebIO.

WebIO defines a `render` generic function. The purpose of `render` is to define how any Julia object can be rendered to something WebIO can display. Hence, we should define how elements of our Todo app are rendered by adding [methods](http://docs.julialang.org/en/release-0.5/manual/methods/) to `render`. First, the TodoItem:

```julia
import WebIO.render

function render(todoitem::TodoItem)
    dom"div.todo-item"(
        dom"input[type=checkbox]"(checked=todoitem.done),
        todoitem.description,
        style=Dict("display" => "flex", "flex-direction" => "horizontal"),
    )
end
```

Let's see how this renders:

```julia
render(TodoItem("Make my first WebIO widget", true))
```

The render function can also be thought of as a template. An HTML version of this template might look like:

```html
<div style="display:flex; flex-direction: horizontal">
    <input type="checkbox" checked={{todoitem.done}}>
    {{todoitem.description}}
</div>
```

Second, we define how a TodoList is rendered:

```julia
function render(list::TodoList)
    dom"div"(
        dom"h2"(list.title),
        dom"div.todo-list"(
            map(render, list.items) # a vector of rendered TodoItems
        )
    )
end
```

```julia
mylist = TodoList("My todo list",
    [TodoItem("Make my first WebIO widget", false),
     TodoItem("Make a pie", false)])

render(mylist)
```

## Setting up event handlers

You can set the `events` property to a Dict mapping event names to JavaScript function (in a String).

For example,

```julia
dom"div"("show my messages",
    events=Dict(
      "click" => "function () { alert('Nice, you have no messages.'); }"
    )
)
```

## Context and communication

You can communicate between Julia and JavaScript by creating a `Context` object. Think of it as the mailbox for a subtree of a DOM, it can receive and send "commands". In the example below, we will create a counter which can be incremented and decremented. The changes to the count happen on the Julia side - this is of course an overkill and could have been done all on the JavaScript side, but imagine you are also saving the count to a database or a file on the server - you'd need the events to come to Julia and go back to the browser. Although simplistic, this example demonstrates a handful of features of Contexts.

```julia

function counter(count=0)
  withcontext(Context()) do ctx
    # ctx is the Context object

    # handle!(context, command_name) - add a handler for a command coming from JavaScript

    handle!(ctx, :change) do d
        send(ctx, :set_count, count+=d)
    end

    # handlejs!(ctx, command_name, function_string) - add a handler for a command coming in from the Julia side
    # in this case we access the element with the id "count" from ctx.dom, and set its contents to the new count

    handlejs!(ctx, :set_count, "function (ctx,msg) {ctx.dom.querySelector('#count').textContent = msg}")

    # the btn function defined below takes a label and a change value and creates a button which
    # when clicked, asks julia to change the counter by the given change value by sending the "change" command
    # recall that we have added the handler for :change using `handle` above.

    btn(label, change) = Node(:button, label,
            events=Dict(
                # an event handler on Javascript always gets two arguments: the event and the context
                # event is object passed by JavaScript into the event handler, and context is the context
                # using which you can talk to julia or access and modify contents of the context (context.dom as seen above)
                "click"=>"function (event,ctx) { WebIO.send(ctx, 'change', $change) }"
            )
        )

    # This function should return the DOM object that is watched over by the context
    # for relaying messages.

    Node(:div,
        btn("increment", 1),
        btn("decrement", -1),
        Node(:div, string(count), id="count"),
    )
  end
end

counter(1)

```

You can also create many counters, each with its own state:

```julia
Node(:div,
  map(counter, [1,2,3,4])
)
```

## CommandSets

You can add a bunch of command handlers to be available at all times on the JavaScript side. This is done by adding a field to the `WebIO.CommandSets` object.

```js
WebIO.CommandSets.MySet = {
  foo: function (ctx, data) {
    // do foo
    // WebIO.send(ctx, some_command, some_data) maybe
  },
  bar: function (ctx, data) {
    // do bar
  }
}
```

Now, these commands can be invoked by naming them as "MySet.foo". i.e. `send(ctx, "MySet.foo", foo_data)` or `send(ctx, "MySet.bar", bar_data)` on the Julia side.

### Basics.eval

Basics is a CommandSet available by default and it contains a single `Basics.eval` command. This takes some JavaScript code in string form and evaluates it. A `context` variable is defined in the evaluation environment which represents the context the command is called on. It's better to set up specific commands and call them since they have the chance of getting compiled by the JavaScript engine to be efficient wheras code run with `Basics.eval` does not.

## Custom Nodes

The `Node` type tries to be sufficiently generic so as to allow creation of custom nodes that are not necessarily DOM nodes. Here's what the Node type looks like on Julia*:

```julia
immutable Node{T}
  instanceof::T

  children::AbstractArray
  props::Associative
end
```

And the JSON lowered form looks like this:

```js
{
  "type": "node",
  "nodeType": nodetype(node.instanceof),
  "instanceArgs": JSON.lower(node.instanceof),
  "children": [...]
  "props": {...}
}
```

WebIO calls `WebIO.NodeTypes[node.nodeType].create` on the JavaScript side to create `node`. This function takes the Context and the `node` as the arguments. (if Node is not wrapped in a context, a default context is created but it won't have a counterpart on the Julia side)

The curious `instanceof` field can contain any custom type that represents what it is you're going to create. For example, DOM nodes have this set to `immutable DOM; namespace::Symbol; tag::Symbol end`. `Node(tag::Symbol)` just constructs `Node(DOM(:html, tag), ...)` as a special case.

```julia
nodetype(::DOM) = "DOM"
```
so this invokes WebIO.NodeTypes.DOM.create to create the element.

`withcontext` returns a `Node{Context}(Context(id, provider,...)...)`. and `node(::Context) = "Context"` and hence calls `WebIO.NodeTypes.Context.create`.

The motivation behind this is to:

1. Allow you to create things like [Facebook React's Components](https://facebook.github.io/react/docs/react-component.html) or [Vue components](https://vuejs.org/guide/#Composing-with-Components) or virtually any such component library (mercury, Cycle.js, riot.js, Elm are a few more examples) using the Node type.
2. Plotting packages like Plotly and Vega can define their own Node type if they wish
3. Allow Julia code to dispatch on `T` in `Node{T}` -- (my experience from making Escher says that you will need this at some point or the other)

**Future interaction with Patchwork**: Patchwork right now has its own `Elem` type which will be replaced by `WebIO.Node` as a next step. And it will expose a `Patchwork.update` command which will take a new `Node` instance and apply it by patching over an existing one. This would possibly call. `NodeTypes.MyType.patch` to give an opportunity for different Node types to apply updates according to their updation API (here is how [React does this](https://facebook.github.io/react/docs/react-component.html#setstate), for example)

`*` -- The Node type also secretly contains 2 more fields: `key` and `_descendants_count` - these are for use by [Patchwork](https://github.com/shashi/Patchwork.jl) at a higher level.

## Providers

This section is relevant to developers of web interfaces to Julia such as IJulia, Atom and Blink.

A `Provider` is such a Julia package that can set up a communication channel for WebIO.

To do this, a package must:

On the JavaScript side:

1. load the JavaScript files `assets/webio.js` and `assets/nodeTypes.js` into their browser environment
2. Add some JavaScript that sets `WebIO.sendCallback` to a function that takes a JS object and sends it to the Julia side.
3. set up a listener for messages from Julia, and call `WebIO.dispatch(message)` for every message

On the Julia side

1. Have a listener on the Julia side which listens to messages sent by `sendCallback` above and calls `dispatch(context_id::String, command::Symbol, data::Any)` - WebIO takes over from here and calls the corresponding event handlers in user code.
2. Create a provider type which represents the provider (e.g. IJuliaProvider)
3. Define `Base.send` on the provider type.
```julia
function Base.send(p::MyProvider, data)
      # figure out a way to send `data` to JavaScript
      # you can use any encoding for the data
end
```
4. Push an instance of the provider onto the provider stack using `WebIO.push_provider!(provider)`

For an example, see how it's done for IJulia at [src/ijulia_setup.jl](https://github.com/shashi/WebIO.jl/blob/cc8294d0b46551d9c5ff1b31c3dca3a6cbbbcf43/src/ijulia_setup.jl) and [assets/ijulia_setup.js](https://github.com/shashi/WebIO.jl/blob/cc8294d0b46551d9c5ff1b31c3dca3a6cbbbcf43/assets/ijulia_setup.js).

