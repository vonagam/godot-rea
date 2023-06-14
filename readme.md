<p align="center">
  <a href="https://github.com/vonagam/godot-rea">
    <img src="rea.svg" style="width: 6em" alt="Rea logo">
  </a>
</p>

# Rea

A React-like library for Godot 4.  

Includes components, virtual tree, fragments, contexts, portals, refs and hooks. 

## Api

Everything is exposed through global `rea` class. 

To install the addon you need to place `addons/rea` folder under the same name into your project addons folder and enable it in Project > Project Settings > Plugins.

Rea tries to match React's api where it makes sense but deviates to addapt to Godot's nature. 

### Components

There are two type of components - pure functional and node ones. 
Both represent a render function which receives an argument of type [`rea.Arg`](#reaarg) and outputs some [`rea.Descriptor`](#descriptors). 

Node components are attached to node instances and their render must return [`rea.NodeDescriptor`](#reanode) which will be applied to their node. 
Node's render function will be called either right after `_init` or right before `_enter_tree`. 
A node component automatically acts as a root, there is no need to call `mount` or `unmount` like in React (though there is an option for such usage with [`rea.apply`](#reaapply)). 

There are two ways to define a node component. 
By extending [`rea.Component`](#reacomponent) or by calling [`rea.component.init`](#reacomponentinit) and [`rea.component.notify`](#reacomponentnotify).

#### rea.Component

Extend `rea.Component` and define an override for `render` method:

```gdscript
extends rea.Component

func render(arg: rea.Arg) -> rea.NodeDescriptor:
  return rea.node(self)
```

`rea.Component` provides instance method `rerender`. And that's it.

#### rea.component

`rea.Component` extends `Node`, if for some reason there is a need to extend another base `rea.component` can be used. 
Simply call [`rea.component.init`]((#reacomponentinit)) and [`rea.component.notify`](#reacomponentnotify) in corresponding virtual functions like that:

```gdscript
extends Whatever # Whatever has to be a Node subclass

func _init() -> void:
  rea.component.init(self, self.render)

func _notification(what: int) -> void:
  rea.component.notify(self, what)

func render(arg: rea.Arg) -> rea.NodeDescriptor:
  return rea.node(self)
```

The render function does not have to be called `render`. 
It does not have to be a method, can be a lambda. 

##### rea.component.init

```gdscript
func init(node: Node, callable: Callable) -> void
```

Should be called in script's `_init` method. `callable` is of signature `(arg: rea.Arg) -> rea.NodeDescriptor`.

##### rea.component.notify

```gdscript
func notify(node: Node, what: int) -> void
```

Should be called in script's `_nofity` method.

##### rea.component.rerender

```gdscript
func rerender(node: Node) -> void
```

Triggers rerendering of `node`. Useful if a render function depends on changeable things which are outside of its scope.

### rea.Arg

```gdscript
class Arg:
  var ref: Callable = Callable()
  var persistent: bool = false
  var data: Variant = null
  var props: Dictionary = {}
  var signals: Dictionary = {}
  var children: rea.FragmentDescriptor = null
  var portals: rea.FragmentDescriptor = null
```

The single argument of that type will be passed to renderable components.  
An arg gets produced from an element's description.  

### Descriptors

Descriptors are used to describe intended layout. 
In React those are usually generated with jsx syntax. 
In Rea you create descriptors with helper functions that return builders with chainable methods to set corresponding attributes.

#### rea.Descriptor

This a base class for descriptors. Here are methods that can be called on all of them.  

##### rea.Descriptor#tap

```gdscript
func tap(tap: Callable)
```

Calls `tap` with the descriptor, a return value is ignored.  

##### rea.Descriptor#arg

```gdscript
func arg(arg: rea.Arg)
```

Sets relevant attributes from `arg` on the descriptor.

##### rea.Descriptor#key

```gdscript
func key(key: Variant)
```
  
Ensures that the descriptor updates are sent to the right element. Same as in React.

##### rea.Descriptor#portals

```gdscript
func portals(portals: Array[rea.Descriptor])
```

Adds nested descriptors. They may describe nodes anywhere in an actual tree. 

#### rea.NodedDescriptor

This is a base class for descriptors that represent a single node. 

##### rea.node

```gdscript
func node(node: Node) -> rea.NodeDescriptor
```

Describes a preexisting node.

##### rea.path

```gdscript
func path(path: NodePath, node: Node = null) -> rea.PathDescriptor
```

Describes a preexisting node that is searched with `get_node` at mount of the descriptor. 
`get_node` is called on first node parent of a path descriptor, or `node` if it is provided.

##### rea.type

```gdscript
func type(type: Variant, script: GDScript = null) -> rea.TypeDescriptor
```

Describes a new node created by calling constructor of `type`. 
`type` can be a native Node class (`Node`, `Control` or others) or some custom GDScript. 
To attach custom GDScript to a subtype of its parent class use `script`.

##### rea.scene

```gdscript
func scene(scene: PackedScene) -> rea.SceneDescriptor
```

Describes a new node created by instantiating `scene`.

##### rea.NodedDescriptor#children

```gdscript
func children(children: Array[rea.Descriptor])
```

Adds nested descriptors. Nodes of the descriptors will be made children of the described node and moved approprietly.

##### rea.NodedDescriptor#hollow

```gdscript
func hollow(is_hollow: bool = true)
```

By default a node element is hollow, meaning it does not have described children and does not touches its actual children. 
It can be very convinient to have a customly created node or new instantiated scene with a preexisting hierarchy that you can control with portals 
without a need to describe the full tree. The moment `children()` is called (or `arg()` with children on it) a descriptor stops being hollow. 
To ensure that nothing will be touched `hollow()` can be called.

##### rea.NodedDescriptor#props

```gdscript
func props(props: Dictionary)
func prop(key: StringName, value: Variant)
func propi(key: NodePath, value: Variant)
```

Adds `props` to already set ones.  

Before a prop is set on an actual node, the previous value of the property will be retrieved and saved. 
On element's unmount (or removal of the prop from a descriptor) that previous value will be restored. 

Use [`rea.ignore`](#reaignore) (described at the bottom) as a value to revert a prop to its before-mount value and not set it to `null`. 

If a key is `NodePath` then `set_indexed` will be used (and `get_indexed` for saving value).  

##### rea.NodedDescriptor#binds

```gdscript
func binds(signals: Dictionary)
func bind(key: StringName, callable: Callable)
```

Adds `signals` to already set ones. 

##### rea.NodedDescriptor#ref

```gdscript
func ref(ref: Callable)
```

Calls `ref` with a node on mount and `null` on umnount.

##### rea.NodedDescriptor#data

```gdscript
func data(data: Variant)
```

Sets any `data` on `rea.Arg`. For custom logic in render functions.

##### rea.NodedDescriptor#nullable

```gdscript
func nullable(is_nullable: bool = true)
```

Allows silently skipping descriptors that describe optional nodes which are expected to be null in some cases.

##### rea.NodedDescriptor#rendered

```gdscript
func rendered(is_rendered: bool = true)
```

If a described node is a Rea node component and you want to affect its render function - 
to pass things with `rea.Arg` or through sharing of context - then call this method.

If a Rea node component is mounted without it being described as `rendered()` it will act as a root and will do it's own render thing, 
but without recieving filled `rea.Arg` or sharing of context.

Only one element can call a render function of a node, so you cannot use `rendered()` on already mounted node component. 
But nothing stops same node being used by multiple elements from same or different render trees without touching rendering. 

##### rea.NodedDescriptor#persistent

```gdscript
func persistent(is_persistent: bool = true)
```

By default any node described by a descriptor will be called `queue_free()` on when corresponding element unmounts. 
Does not matter if it is in portals or children, if the node was created specifically from descriptor or if it was existing before. 

To take responsibility for node's destruction and prevent default freeing behaviour `persistent()` has to be called.

#### rea.NodesDescriptor

Describes a collection of aready existing nodes. 
Common case is to create it with [`rea.use.memo`](#reausememo) to store initial children of a node component when there is a need to work with children.

##### rea.nodes

```gdscript
func nodes() -> rea.NodesDescriptor
```

##### rea.NodesDescriptor#persistent

```gdscript
func persistent(is_persistent: bool = true)
```

Marks nodes as independent in lifecycle from the descriptor. Same as [for node](#reanodeddescriptorpersistent).

##### rea.NodesDescriptor#nodes

```gdscript
func nodes(nodes: Array[Node])
```

Sets nodes of the descriptor.

#### rea.CallableDescriptor

Describes usage of a pure functional component. It has all of [`rea.NodedDescriptor`](#reanodeddescriptor) attribute methods except `renderable()`.

##### rea.callable

```gdscript
func callable(callable: Callable) -> rea.CallableDescriptor
```

`callable` is of signature `(arg: rea.Arg) -> rea.Descriptor`. 

#### rea.FragmentDescriptor

Groups multiple descriptors as one. Usual usage cases are optimizations with `key` attribute or as a return in a function component. 
Has only basic attributes plus `children()`, `hollow()`.

##### rea.fragment

```gdscript
func fragment() -> rea.FragmentDescriptor
```

#### rea.ContextDescriptor

Sets a context for its children/portals that they can access through [`rea.use.context`](#reausecontext) hook in a render function. 
Otherwise same as [`rea.FragmentDescriptor`](#reafragmentdescriptor).

Context identifier is a custom class that has static function `get_fallback` returning a default value to be used. 

##### rea.context

```gdscript
func context(context: GDScript, value: Variant) -> rea.ContextDescriptor
```

To use a default value of context pass [`rea.ignore`](#reaignore) as a value.

### Hooks

Those correspond directly to [React ones](https://reactjs.org/docs/hooks-reference.html) of the same name. 
So comments here are mostly about differences from original ones.

#### rea.use.state

```gdscript
func state(initial_value: Variant) -> rea.use.State

class State extends RefCounted:
  value: Variant
  update: Callable # func(value: Variant) -> void
```

There is no destructuring or tuples in Godot so an object is returned.  
It has `value` property and `update` callable, same in functionality as in React.  
This is not a reference, new state object will be created for each update.  
`update` lifecylce is separate from the object, it works even after outdated state object is garbage collected.

#### rea.use.effect

```gdscript
func effect(update: Callable, deps: Array = []) -> void
```

No immediate effect analog implemented yet, only this one, deferred.

#### rea.use.context

```gdscript
func context(context: GDScript) -> Variant
```

`context` is both an identifier and a default value provider.

#### rea.use.reducer

```gdscript
func reducer(reducer: Callable, initial_value: Variant, init: Callable = Callable()) -> rea.use.Reducer

class Reducer extends RefCounted:
  value: Variant
  update: Callable # func(action: Variant) -> void
```

Same as in `state` hook returns an object with `value` and `update`. 

#### rea.use.callback

```gdscript
func callback(callback: Callable, deps: Array = []) -> Callable
```

#### rea.use.memo

```gdscript
func memo(producer: Callable, deps: Array = []) -> Variant
```

#### rea.use.ref

```gdscript
func ref(initial_value: Variant = null) -> rea.use.Ref
```

Returns object with mutable `current` property and `update` method that sets said property.  
`update` method can be passed to `ref` method of a node descriptor.

### Other

#### rea.ignore

```gdscript
const ignore: Variant
```

Means absence of a value to distringuish cases where you want to use `null` as an actual intended value.  
Can be passed to descriptor's `prop` method or `context` descriptor builder.

#### rea.noop

```gdscript
const noop: Callable
```

Empty `Callable()`, nothing more.

#### rea.is_ignore

```gdscript
func is_ignore(value: Variant) -> bool
```

Checks if `value` is a [`rea.ignore`](#reaignore).

#### rea.apply

```gdscript
func apply(element: NodeElement, descriptor: NodeDescriptor) -> NodeElement
```

To mount an element - call `apply(null, descriptor)` and save returned element.
To update a mounted element - call `apply(element, descriptor)` and save the result.
To unmount - call `apply(element, null)`.

Update may case unmount of the element and then mount of new one if a passed descriptor does not match that of a passed element. 

## Notes

Two projects that gave inspiration to try - 
[Goduz](https://github.com/andresgamboaa/goduz) and 
[ReactGD](https://github.com/ghsoares/ReactGD).
