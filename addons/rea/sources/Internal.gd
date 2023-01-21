extends Node


# Common

const EMPTY_DICTIONARY: Dictionary = {}
const EMPTY_ARRAY: Array = []
const EMPTY_INT_ARRAY: Array[ int ] = []
const EMPTY_CALLABLE_ARRAY: Array[ Callable ] = []
const EMPTY_NODE_ARRAY: Array[ Node ] = []
const NOOP: Callable = Callable()
const IGNORE: Variant = &'__rea_ignore__'
const CHILDREN_KEY: Variant = &'__rea_children_key__'
const PORTALS_KEY: Variant = &'__rea_portals_key__'


class utils:
  static func is_equal( a: Variant, b: Variant ) -> bool:
    return typeof( a ) == typeof( b ) && a == b

  static func is_ignore( value: Variant ) -> bool:
    return typeof( value ) == TYPE_STRING_NAME && value == IGNORE


# Base

const EMPTY_DESCRIPTOR_ARRAY: Array[ Descriptor ] = []
const EMPTY_ELEMENT_ARRAY: Array[ Element ] = []


class Descriptor:
  var _key: Variant
  var _portals: Array[ Descriptor ] = EMPTY_DESCRIPTOR_ARRAY

  func _is_compatible( other: Descriptor ) -> bool:
    return false

  func _make_element( parent: Element, is_portal: bool ) -> Element:
    return null

  func _use_arg( arg: RenderArg ) -> void:
    if arg.portals != null:
      self._portals = arg.portals._portals


class Element:
  var descriptor: Descriptor = null
  var is_portal: bool
  var parent: Element
  var index: int = -1
  var nodes: Array[ Node ] = EMPTY_NODE_ARRAY
  var portals: Collection = null
  var contexts: Dictionary = EMPTY_DICTIONARY

  func _init( parent: Element, is_portal: bool ) -> void:
    self.parent = parent
    self.is_portal = is_portal
    self.contexts = parent.contexts if parent != null else EMPTY_DICTIONARY

  func update_descriptor( next_descriptor: Descriptor ) -> void:
    var prev_descriptor := self.descriptor
    if next_descriptor == prev_descriptor: return
    self.descriptor = next_descriptor
    _descriptor_updated( prev_descriptor )

  func update_portals( prev_descriptor: Descriptor, next_descriptor: Descriptor ) -> void:
    var prev_descriptors := prev_descriptor._portals if prev_descriptor != null else EMPTY_DESCRIPTOR_ARRAY
    var next_descriptors := next_descriptor._portals if next_descriptor != null else EMPTY_DESCRIPTOR_ARRAY
    if next_descriptors == prev_descriptors: return
    if self.portals == null: self.portals = Collection.new( self, true )
    self.portals.update( prev_descriptors, next_descriptors )

  func _descriptor_updated( prev_descriptor: Descriptor ) -> void:
    update_portals( self.descriptor, prev_descriptor )

  func remove_portals() -> void:
    if self.portals == null: return
    self.portals.remove()
    self.portals.free()
    self.portals = null

  func remove_descriptor() -> void:
    self.descriptor = null
    self.parent = null
    self.nodes = EMPTY_NODE_ARRAY
    self.contexts = EMPTY_DICTIONARY

  func _removed() -> void:
    remove_portals()
    remove_descriptor()


class Collection extends Object:
  var parent: Element
  var is_portal: bool
  var elements: Array[ Element ] = EMPTY_ELEMENT_ARRAY
  var keys: Dictionary = EMPTY_DICTIONARY

  func _init( parent: Element, is_portal: bool ) -> void:
    self.parent = parent
    self.is_portal = is_portal

  func update( prev_descriptors: Array[ Descriptor ], next_descriptors: Array[ Descriptor ] ) -> void:
    var parent := self.parent
    var is_portal := self.is_portal
    var prev_elements := self.elements
    var next_elements := ( [] as Array[ Element ] ) if ! next_descriptors.is_empty() else EMPTY_ELEMENT_ARRAY
    var prev_keys := self.keys
    var next_keys := EMPTY_DICTIONARY
    var left_elements := ( prev_elements.duplicate() as Array[ Element ] ) if ! prev_elements.is_empty() && ! next_descriptors.is_empty() else prev_elements

    for next_index in next_descriptors.size():
      var next_descriptor := next_descriptors[ next_index ]
      if next_descriptor == null: continue
      var next_key: Variant = next_descriptor._key
      var next_element: Element = null
      if next_key != null:
        assert( ! next_keys.has( next_key ), 'Cannot have elements with same key of "%s".' % next_key )
        if next_keys.is_empty(): next_keys = {}
        next_keys[ next_key ] = next_index
        if prev_keys.has( next_key ):
          var prev_element := prev_elements[ prev_keys[ next_key ] ]
          if prev_element.descriptor._is_compatible( next_descriptor ):
            next_element = prev_element
            left_elements.erase( prev_element )
      else:
        for left_index in left_elements.size():
          var left_element := left_elements[ left_index ]
          if left_element.descriptor._key == null && left_element.descriptor._is_compatible( next_descriptor ):
            next_element = left_element
            left_elements.remove_at( left_index )
            break
      if next_element == null:
        next_element = next_descriptor._make_element( parent, is_portal )
      next_element.index = next_elements.size()
      next_element.update_descriptor( next_descriptor )
      next_elements.push_back( next_element )

    self.elements = next_elements
    self.keys = next_keys

    for left_element in left_elements:
      left_element._removed()

  func remove() -> void:
    for element in self.elements: element._removed()


# Childed

class ChildedDescriptor extends Descriptor:
  var _is_hollow: bool = true
  var _children: Array[ Descriptor ] = EMPTY_DESCRIPTOR_ARRAY

  func _set_hollow( is_hollow: bool ) -> void:
    if self._is_hollow == is_hollow: return
    self._is_hollow = is_hollow
    if is_hollow: self._children = EMPTY_DESCRIPTOR_ARRAY

  func _set_children( children: Array[ Descriptor ] ) -> void:
    self._is_hollow = false
    self._children = children

  func _use_arg( arg: RenderArg ) -> void:
    super( arg )
    if arg.children != null:
      self._is_hollow = false
      self._children = arg.children._children


class ChildedElement extends Element:
  var children: Collection = null

  func update_children( prev_descriptor: ChildedDescriptor, next_descriptor: ChildedDescriptor ) -> void:
    var prev_descriptors := prev_descriptor._children if prev_descriptor != null else EMPTY_DESCRIPTOR_ARRAY
    var next_descriptors := next_descriptor._children if next_descriptor != null else EMPTY_DESCRIPTOR_ARRAY
    if next_descriptors == prev_descriptors: return
    if self.children == null: self.children = Collection.new( self, false )
    self.children.update( prev_descriptors, next_descriptors )

  func remove_children() -> void:
    if self.children == null: return
    self.children.remove()
    self.children.free()
    self.children = null

  func _child_rerendered( child_index: int, prev_nodes: Array[ Node ], next_nodes: Array[ Node ] ) -> void:
    pass

  func _removed() -> void:
    remove_portals()
    remove_children()
    remove_descriptor()


# Proped

class PropedDescriptor extends ChildedDescriptor:
  var _props: Dictionary = EMPTY_DICTIONARY
  var _owns_props: bool = false
  var _signals: Dictionary = EMPTY_DICTIONARY
  var _owns_signals: bool = false

  func _add_props( props: Dictionary ) -> void:
    if props.is_empty(): return
    if ! self._owns_props:
      if self._props.is_empty(): self._props = props; return
      self._props = self._props.duplicate(); self._owns_props = true
    self._props.merge( props, true )

  func _add_prop( key: StringName, value: Variant ) -> void:
    if utils.is_ignore( value ) && ! self._props.has( key ): return
    if ! self._owns_props: self._props = self._props.duplicate(); self._owns_props = true
    self._props[ key ] = value

  func _add_propi( key: NodePath, value: Variant ) -> void:
    if utils.is_ignore( value ) && ! self._props.has( key ): return
    if ! self._owns_props: self._props = self._props.duplicate(); self._owns_props = true
    self._props[ key ] = value

  func _add_signals( signals: Dictionary ) -> void:
    if signals.is_empty(): return
    if ! self._owns_signals:
      if self._signals.is_empty(): self._signals = signals; return
      self._signals = self._signals.duplicate(); self._owns_signals = true
    self._signals.merge( signals, true )

  func _add_signal( key: StringName, callable: Callable ) -> void:
    if callable == NOOP && ! self._signals.has( key ): return
    if ! self._owns_signals: self._signals = self._signals.duplicate(); self._owns_signals = true
    self._signals[ key ] = callable

  func _use_arg( arg: RenderArg ) -> void:
    super( arg )
    self._add_props( arg.props )
    self._add_signals( arg.signals )


# Render

class RenderDescriptor extends PropedDescriptor:
  var _ref: Callable = NOOP
  var _data: Variant = null

  func _use_arg( arg: RenderArg ) -> void:
    super( arg )
    self._ref = arg.ref


class RenderElement extends ChildedElement:
  var render: Render
  var render_arg: RenderArg = null

  func rerender() -> void:
    if self.is_portal || self.parent == null:
      _descriptor_updated( self.descriptor )
      return
    var prev_nodes := self.nodes
    _descriptor_updated( self.descriptor )
    var next_nodes := self.nodes
    if next_nodes == prev_nodes: return
    var parent: ChildedElement = self.parent
    parent._child_rerendered( self.index, prev_nodes, next_nodes )

  func remove_render() -> void:
    if self.render == null: return
    self.render.remove()
    self.render = null
    self.render_arg = null

  func _removed() -> void:
    remove_render()
    remove_portals()
    remove_children()
    remove_descriptor()


class Render:
  var element: RenderElement
  var data: Array[ Variant ] = EMPTY_ARRAY
  var cleanups: Array[ Callable ] = EMPTY_CALLABLE_ARRAY
  var counter: int = 0
  var output: Descriptor = null

  func _init( element: RenderElement ) -> void:
    self.element = element

  func rerender_deferred() -> void:
    rerender.call_deferred( self.counter )

  func rerender( counter: int ) -> void:
    if counter != self.counter || self.element == null: return
    element.rerender()

  func remove() -> void:
    self.element = null
    for cleanup in self.cleanups: cleanup.call()
    self.cleanups = EMPTY_CALLABLE_ARRAY
    self.data = EMPTY_ARRAY
    self.output = null


class RenderArg:
  var ref: Callable = NOOP
  var persistent: bool = false
  var data: Variant = null
  var props: Dictionary = EMPTY_DICTIONARY
  var signals: Dictionary = EMPTY_DICTIONARY
  var children: FragmentDescriptor = null
  var portals: FragmentDescriptor = null


class RenderContext:
  static func get_fallback() -> Variant:
    assert( false, 'Cannot extend Component and not implement get_fallback.' )
    return null


var render: Render
var render_data_index: int
var render_is_mounted: bool

func start_render( render: Render ) -> void:
  self.render = render
  self.render_data_index = -1
  self.render_is_mounted = render.counter != 0
  render.counter += 1

func finish_render() -> void:
  self.render = null


var render_roots: Dictionary = {}

class RenderRoot:
  var element: RenderElement
  var callable: Callable
  var is_controlled: bool = false

class component:
  static func init( node: Node, callable: Callable ) -> void:
    var root := RenderRoot.new()
    root.callable = callable
    REA.render_roots[ node ] = root

  static func notify( node: Node, what: int ) -> void:
    if what == Node.NOTIFICATION_ENTER_TREE:
      var root: RenderRoot = REA.render_roots[ node ]
      if root.is_controlled || root.element != null: return
      var descriptor := NodeDescriptor.new( node ).rendered().persistent()
      var element := descriptor._make_element( null, false ) as RenderElement
      root.element = element
      element.update_descriptor( descriptor )
      return
    if what == Node.NOTIFICATION_EXIT_TREE:
      var root: RenderRoot = REA.render_roots[ node ]
      if root.is_controlled || root.element == null: return
      root.element._removed()
      root.element = null
      return
    if what == Object.NOTIFICATION_PREDELETE:
      REA.render_roots.erase( node )
      return

  static func rerender( node: Node ) -> void:
    var root: RenderRoot = REA.render_roots[ node ]
    if root.element != null: root.element.rerender()


class RenderComponent extends Node:
  func _init() -> void:
    component.init( self, self.render )

  func _notification( what: int ) -> void:
    component.notify( self, what )

  func rerender() -> void:
    component.rerender( self )

  func render( arg: RenderArg ) -> NodeDescriptor:
    assert( false, 'Cannot extend Component and not implement render.' )
    return null


# Noded

class NodedDescriptor extends RenderDescriptor:
  var _is_rendered: bool = false
  var _is_persistent: bool = false

  func _to_arg() -> RenderArg:
    var arg := RenderArg.new()
    arg.data = self._data
    arg.props = self._props
    arg.signals = self._signals
    arg.children = null if self._is_hollow else FragmentDescriptor.new().key( CHILDREN_KEY ).children( self._children )
    return arg

  func _use_arg( arg: RenderArg ) -> void:
    super( arg )
    if arg.persistent:
      self._is_persistent = true


class NodedElement extends RenderElement:
  var node: Node
  var undo_props := {}
  var offsets := EMPTY_INT_ARRAY
  var render_callable: Callable = NOOP
  var render_portals: Collection = null

  func _init( node: Node, is_rendered: bool, parent: Element, is_portal: bool ) -> void:
    super( parent, is_portal )
    self.node = node
    self.nodes = [ node ] as Array[ Node ] if node != null && ! is_portal else EMPTY_NODE_ARRAY
    if is_rendered && node != null:
      var render_root: RenderRoot = REA.render_roots[ node ]
      assert( render_root.element == null, 'Cannot use rea component render from multiple places.' )
      render_root.element = self
      render_root.is_controlled = true
      self.render = Render.new( self )
      self.render_callable = render_root.callable

  func set_prop( key: Variant, value: Variant ) -> void:
    if key is NodePath:
      self.node.set_indexed( key, value )
    else:
      self.node.set( key, value )

  func get_prop( key: Variant ) -> Variant:
    if key is NodePath:
      return self.node.get_indexed( key )
    else:
      return self.node.get( key )

  func update_props( prev_descriptor: NodedDescriptor, next_descriptor: NodedDescriptor ) -> void:
    var prev_props := prev_descriptor._props if prev_descriptor != null else EMPTY_DICTIONARY
    var next_props := next_descriptor._props if next_descriptor != null else EMPTY_DICTIONARY
    if next_props == prev_props: return
    var undo_props := self.undo_props
    var left_props := prev_props.duplicate() if ! prev_props.is_empty() && ! next_props.is_empty() else prev_props
    for key in next_props:
      var next_prop: Variant = next_props[ key ]
      if utils.is_ignore( next_prop ): continue
      if left_props.has( key ):
        var prev_prop: Variant = left_props[ key ]
        left_props.erase( key )
        if ! utils.is_equal( next_prop, prev_prop ):
          set_prop( key, next_prop )
      else:
        undo_props[ key ] = get_prop( key )
        set_prop( key, next_prop )
    for key in left_props:
      if utils.is_ignore( left_props[ key ] ): continue
      set_prop( key, undo_props[ key ] )
      undo_props.erase( key )

  func remove_props() -> void:
    for key in self.undo_props: set_prop( key, self.undo_props[ key ] )
    self.undo_props = EMPTY_DICTIONARY

  func update_signals( prev_descriptor: NodedDescriptor, next_descriptor: NodedDescriptor ) -> void:
    var prev_signals := prev_descriptor._signals if prev_descriptor != null else EMPTY_DICTIONARY
    var next_signals := next_descriptor._signals if next_descriptor != null else EMPTY_DICTIONARY
    if next_signals == prev_signals: return
    var node := self.node
    var left_signals := prev_signals.duplicate() if ! prev_signals.is_empty() && ! next_signals.is_empty() else prev_signals
    for key in next_signals:
      var next_func: Variant = next_signals[ key ]
      if next_func == null: continue
      if left_signals.has( key ):
        var prev_func: Variant = left_signals[ key ]
        left_signals.erase( key )
        if next_func != prev_func:
          if prev_func != null: node.disconnect( key, prev_func )
          if next_func != null: node.connect( key, next_func )
      else:
        if next_func != null: node.connect( key, next_func )
    for key in left_signals:
      var prev_func: Variant = left_signals[ key ]
      if prev_func != null: node.disconnect( key, prev_func )

  func remove_signals() -> void:
    var node := self.node
    var descriptor: NodedDescriptor = self.descriptor
    if descriptor == null: return
    var signals := descriptor._signals
    for key in signals: node.disconnect( key, signals[ key ] )

  func update_nodes( prev_descriptor: NodedDescriptor, next_descriptor: NodedDescriptor ) -> void:
    var prev_hollow := prev_descriptor._is_hollow if prev_descriptor != null else true
    var next_hollow := next_descriptor._is_hollow if next_descriptor != null else prev_hollow
    if next_hollow && prev_hollow: return
    var prev_children := prev_descriptor._children if prev_descriptor != null else EMPTY_DESCRIPTOR_ARRAY
    var next_children := next_descriptor._children if next_descriptor != null else EMPTY_DESCRIPTOR_ARRAY
    if next_children == prev_children && next_hollow == prev_hollow: return
    var node := self.node
    var children := self.children.elements if self.children != null else EMPTY_ELEMENT_ARRAY
    var offsets := [] as Array[ int ]
    var placing_sibling: Node = null
    var placing_index: int = 0
    for child in children:
      offsets.push_back( placing_index )
      for child_node in child.nodes:
        if child_node == null: continue
        var child_parent := child_node.get_parent()
        if child_parent == node:
          node.move_child( child_node, placing_index )
        else:
          if child_parent != null:
            child_parent.remove_child( child_node )
          if placing_sibling == null:
            node.add_child( child_node )
          else:
            placing_sibling.add_sibling( child_node )
        placing_sibling = child_node
        placing_index += 1
    offsets.push_back( placing_index )
    for left_index in range( placing_index, node.get_child_count() ):
      assert( ! prev_hollow, 'Cannot ignore preexisting children on a node. Either clear them up or use rea.nodes() to keep them.' )
      node.remove_child( node.get_child( left_index ) )
    self.offsets = offsets

  func remove_nodes() -> void:
    var node := self.node
    var descriptor: NodedDescriptor = self.descriptor
    if descriptor == null || descriptor._is_hollow: return
    for child in node.get_children(): node.remove_child( child )
    self.offsets = EMPTY_INT_ARRAY

  func update_ref( prev_descriptor: NodedDescriptor, next_descriptor: NodedDescriptor ) -> void:
    var prev_ref := prev_descriptor._ref if prev_descriptor != null else NOOP
    var next_ref := next_descriptor._ref if next_descriptor != null else NOOP
    if next_ref == prev_ref: return
    if prev_ref != NOOP: prev_ref.call( null )
    if next_ref != NOOP: next_ref.call( self.node )

  func remove_ref() -> void:
    var descriptor: NodedDescriptor = self.descriptor
    if descriptor == null || descriptor._ref == NOOP: return
    descriptor._ref.call( null )

  func update_render_portals( prev_descriptor: Descriptor, next_descriptor: Descriptor ) -> void:
    var prev_descriptors := prev_descriptor._portals if prev_descriptor != null else EMPTY_DESCRIPTOR_ARRAY
    var next_descriptors := next_descriptor._portals if next_descriptor != null else EMPTY_DESCRIPTOR_ARRAY
    if next_descriptors == prev_descriptors: return
    if self.render_portals == null: self.render_portals = Collection.new( self, true )
    self.render_portals.update( prev_descriptors, next_descriptors )

  func remove_render_portals() -> void:
    if self.render_portals == null: return
    self.render_portals.remove()
    self.render_portals.free()
    self.render_portals = null

  func _descriptor_updated( descriptor: Descriptor ) -> void:
    var node := self.node
    if node == null: return
    var prev_outer_descriptor: NodedDescriptor = descriptor
    var next_outer_descriptor: NodedDescriptor = self.descriptor
    var prev_inner_descriptor := prev_outer_descriptor
    var next_inner_descriptor := next_outer_descriptor
    var render := self.render
    if render != null:
      var render_arg := self.render_arg
      if render_arg == null || next_outer_descriptor != prev_outer_descriptor:
        render_arg = next_outer_descriptor._to_arg()
        self.render_arg = render_arg
      REA.start_render( render )
      prev_inner_descriptor = render.output
      next_inner_descriptor = self.render_callable.call( render_arg )
      REA.finish_render()
      if next_inner_descriptor == prev_inner_descriptor:
        if next_outer_descriptor != prev_outer_descriptor:
          update_portals( prev_outer_descriptor, next_outer_descriptor )
          update_ref( prev_outer_descriptor, next_outer_descriptor )
        return
      render.output = next_inner_descriptor
    update_signals( prev_inner_descriptor, next_inner_descriptor )
    update_props( prev_inner_descriptor, next_inner_descriptor )
    update_children( prev_inner_descriptor, next_inner_descriptor )
    update_nodes( prev_inner_descriptor, next_inner_descriptor )
    update_render_portals( prev_inner_descriptor, next_inner_descriptor )
    update_ref( prev_inner_descriptor, next_inner_descriptor )
    if render != null && next_outer_descriptor != prev_outer_descriptor:
      update_portals( prev_outer_descriptor, next_outer_descriptor )
      update_ref( prev_outer_descriptor, next_outer_descriptor )

  func _child_rerendered( child_index: int, prev_nodes: Array[ Node ], next_nodes: Array[ Node ] ) -> void:
    var node := self.node
    var offsets := self.offsets
    var child_offset := offsets[ child_index ]
    var placing_sibling: Node = null if child_offset == 0 else node.get_child( child_offset - 1 )
    var placing_index := child_offset
    var additions := 0
    for child_node in next_nodes:
      if child_node == null: continue
      var child_parent := child_node.get_parent()
      if child_parent == node:
        node.move_child( child_node, placing_index )
      else:
        if child_parent != null:
          child_parent.remove_child( child_node )
        if placing_sibling == null:
          node.add_child( child_node )
        else:
          placing_sibling.add_sibling( child_node )
        additions += 1
      placing_sibling = child_node
      placing_index += 1

    var prev_child_size := offsets[ child_index + 1 ] - child_offset
    var next_child_size := placing_index - child_offset
    var child_size_delta := next_child_size - prev_child_size
    if child_size_delta != 0:
      for index in range( child_index + 1, offsets.size() ):
        offsets[ index ] += child_size_delta

    for i in range( additions - child_size_delta ):
      node.remove_child( node.get_child( placing_index ) )

  func remove_render() -> void:
    var render_root: RenderRoot = REA.render_roots[ self.node ]
    render_root.element = null
    render_root.is_controlled = false
    self.descriptor = self.render.output
    super()

  func _removed() -> void:
    if self.node != null:
      var outer_descriptor: NodedDescriptor = self.descriptor
      var is_persistent := outer_descriptor._is_persistent
      remove_ref()
      remove_portals()
      if self.render != null:
        remove_render()
        remove_ref()
        remove_render_portals()
        var inner_descriptor: NodedDescriptor = self.descriptor
        is_persistent = is_persistent || ( inner_descriptor != null && inner_descriptor._is_persistent )
      remove_children()
      remove_nodes()
      if is_persistent:
        remove_props()
        remove_signals()
      else:
        self.node.queue_free()
    remove_descriptor()


# Node

class NodeDescriptor extends NodedDescriptor:
  var _node: Node

  func _init( node: Node ) -> void:
    self._node = node

  func _is_compatible( other: Descriptor ) -> bool:
    return other is NodeDescriptor && (
      other._node == self._node &&
      other._is_rendered == self._is_rendered &&
      other._is_persistent == self._is_persistent &&
      other._is_hollow == self._is_hollow
    )

  func _make_element( parent: Element, is_portal: bool ) -> Element:
    return NodeElement.new( self._node, self._is_rendered, parent, is_portal )

  # common
  func tap( tap: Callable ) -> NodeDescriptor: tap.call( self ); return self
  func arg( arg: RenderArg ) -> NodeDescriptor: _use_arg( arg ); return self
  func key( key: Variant ) -> NodeDescriptor: _key = key; return self
  func portals( portals: Array[ Descriptor ] ) -> NodeDescriptor: _portals = portals; return self
  # childed
  func children( children: Array[ Descriptor ] ) -> NodeDescriptor: _set_children( children ); return self
  func hollow( is_hollow: bool = true ) -> NodeDescriptor: _set_hollow( is_hollow ); return self
  # proped
  func props( props: Dictionary ) -> NodeDescriptor: _add_props( props ); return self
  func prop( key: StringName, value: Variant ) -> NodeDescriptor: _add_prop( key, value ); return self
  func propi( key: NodePath, value: Variant ) -> NodeDescriptor: _add_propi( key, value ); return self
  func binds( signals: Dictionary ) -> NodeDescriptor: _add_signals( signals ); return self
  func bind( key: StringName, callable: Callable ) -> NodeDescriptor: _add_signal( key, callable ); return self
  # render
  func ref( ref: Callable ) -> NodeDescriptor: _ref = ref; return self
  func data( data: Variant ) -> NodeDescriptor: _data = data; return self
  # noded
  func rendered( is_rendered: bool = true ) -> NodeDescriptor: _is_rendered = is_rendered; return self
  func persistent( is_persistent: bool = true ) -> NodeDescriptor: _is_persistent = is_persistent; return self


class NodeElement extends NodedElement:
  func _init( node: Node, is_rendered: bool, parent: Element, is_portal: bool ) -> void:
    super( node, is_rendered, parent, is_portal )


# Path

class PathDescriptor extends NodedDescriptor:
  var _path: NodePath
  var _node: Node

  func _init( path: NodePath, node: Node ) -> void:
    self._path = path
    self._node = node

  func _is_compatible( other: Descriptor ) -> bool:
    return other is PathDescriptor && (
      other._path == self._path &&
      other._node == self._node &&
      other._is_rendered == self._is_rendered &&
      other._is_persistent == self._is_persistent &&
      other._is_hollow == self._is_hollow
    )

  func _make_element( parent: Element, is_portal: bool ) -> Element:
    return PathElement.new( self._path, self._node, self._is_rendered, parent, is_portal )

  # common
  func tap( tap: Callable ) -> PathDescriptor: tap.call( self ); return self
  func arg( arg: RenderArg ) -> PathDescriptor: _use_arg( arg ); return self
  func key( key: Variant ) -> PathDescriptor: _key = key; return self
  func portals( portals: Array[ Descriptor ] ) -> PathDescriptor: _portals = portals; return self
  # childed
  func children( children: Array[ Descriptor ] ) -> PathDescriptor: _set_children( children ); return self
  func hollow( is_hollow: bool = true ) -> PathDescriptor: _set_hollow( is_hollow ); return self
  # proped
  func props( props: Dictionary ) -> PathDescriptor: _add_props( props ); return self
  func prop( key: StringName, value: Variant ) -> PathDescriptor: _add_prop( key, value ); return self
  func propi( key: NodePath, value: Variant ) -> PathDescriptor: _add_propi( key, value ); return self
  func binds( signals: Dictionary ) -> PathDescriptor: _add_signals( signals ); return self
  func bind( key: StringName, callable: Callable ) -> PathDescriptor: _add_signal( key, callable ); return self
  # render
  func ref( ref: Callable ) -> PathDescriptor: _ref = ref; return self
  func data( data: Variant ) -> PathDescriptor: _data = data; return self
  # noded
  func rendered( is_rendered: bool = true ) -> PathDescriptor: _is_rendered = is_rendered; return self
  func persistent( is_persistent: bool = true ) -> PathDescriptor: _is_persistent = is_persistent; return self


class PathElement extends NodedElement:
  func _init( path: NodePath, node: Node, is_rendered: bool, parent: Element, is_portal: bool ) -> void:
    if node == null:
      var element := parent
      while element != null:
        if element is NodedElement: node = element.node; break
        element = element.parent
    if node != null:
      node = node.get_node_or_null( path )
      if node == null: node = null # TODO: godot#62658
    super( node, is_rendered, parent, is_portal )


# Type

class TypeDescriptor extends NodedDescriptor:
  var _type: Variant
  var _script: Script

  func _init( type: Variant, script: Script ) -> void:
    self._type = type
    self._script = script

  func _is_compatible( other: Descriptor ) -> bool:
    return other is TypeDescriptor && (
      other._type == self._type &&
      other._script == self._script &&
      other._is_rendered == self._is_rendered &&
      other._is_persistent == self._is_persistent &&
      other._is_hollow == self._is_hollow
    )

  func _make_element( parent: Element, is_portal: bool ) -> Element:
    return TypeElement.new( self._type, self._script, self._is_rendered, parent, is_portal )

  # common
  func tap( tap: Callable ) -> TypeDescriptor: tap.call( self ); return self
  func arg( arg: RenderArg ) -> TypeDescriptor: _use_arg( arg ); return self
  func key( key: Variant ) -> TypeDescriptor: _key = key; return self
  func portals( portals: Array[ Descriptor ] ) -> TypeDescriptor: _portals = portals; return self
  # childed
  func children( children: Array[ Descriptor ] ) -> TypeDescriptor: _set_children( children ); return self
  func hollow( is_hollow: bool = true ) -> TypeDescriptor: _set_hollow( is_hollow ); return self
  # proped
  func props( props: Dictionary ) -> TypeDescriptor: _add_props( props ); return self
  func prop( key: StringName, value: Variant ) -> TypeDescriptor: _add_prop( key, value ); return self
  func propi( key: NodePath, value: Variant ) -> TypeDescriptor: _add_propi( key, value ); return self
  func binds( signals: Dictionary ) -> TypeDescriptor: _add_signals( signals ); return self
  func bind( key: StringName, callable: Callable ) -> TypeDescriptor: _add_signal( key, callable ); return self
  # render
  func ref( ref: Callable ) -> TypeDescriptor: _ref = ref; return self
  func data( data: Variant ) -> TypeDescriptor: _data = data; return self
  # noded
  func rendered( is_rendered: bool = true ) -> TypeDescriptor: _is_rendered = is_rendered; return self
  func persistent( is_persistent: bool = true ) -> TypeDescriptor: _is_persistent = is_persistent; return self


class TypeElement extends NodedElement:
  func _init( type: Variant, script: Script, is_rendered: bool, parent: Element, is_portal: bool ) -> void:
    var node: Node = null
    if type != null:
      node = type.new()
      if script != null:
        node.set_script( script )
    super( node, is_rendered, parent, is_portal )


# Scene

class SceneDescriptor extends NodedDescriptor:
  var _scene: PackedScene

  func _init( scene: PackedScene ) -> void:
    self._scene = scene

  func _is_compatible( other: Descriptor ) -> bool:
    return other is SceneDescriptor && (
      other._scene == self._scene &&
      other._is_rendered == self._is_rendered &&
      other._is_persistent == self._is_persistent &&
      other._is_hollow == self._is_hollow
    )

  func _make_element( parent: Element, is_portal: bool ) -> Element:
    return SceneElement.new( self._scene, self._is_rendered, parent, is_portal )

  # common
  func tap( tap: Callable ) -> SceneDescriptor: tap.call( self ); return self
  func arg( arg: RenderArg ) -> SceneDescriptor: _use_arg( arg ); return self
  func key( key: Variant ) -> SceneDescriptor: _key = key; return self
  func portals( portals: Array[ Descriptor ] ) -> SceneDescriptor: _portals = portals; return self
  # childed
  func children( children: Array[ Descriptor ] ) -> SceneDescriptor: _set_children( children ); return self
  func hollow( is_hollow: bool = true ) -> SceneDescriptor: _set_hollow( is_hollow ); return self
  # proped
  func props( props: Dictionary ) -> SceneDescriptor: _add_props( props ); return self
  func prop( key: StringName, value: Variant ) -> SceneDescriptor: _add_prop( key, value ); return self
  func propi( key: NodePath, value: Variant ) -> SceneDescriptor: _add_propi( key, value ); return self
  func binds( signals: Dictionary ) -> SceneDescriptor: _add_signals( signals ); return self
  func bind( key: StringName, callable: Callable ) -> SceneDescriptor: _add_signal( key, callable ); return self
  # render
  func ref( ref: Callable ) -> SceneDescriptor: _ref = ref; return self
  func data( data: Variant ) -> SceneDescriptor: _data = data; return self
  # noded
  func rendered( is_rendered: bool = true ) -> SceneDescriptor: _is_rendered = is_rendered; return self
  func persistent( is_persistent: bool = true ) -> SceneDescriptor: _is_persistent = is_persistent; return self


class SceneElement extends NodedElement:
  func _init( scene: PackedScene, is_rendered: bool, parent: Element, is_portal: bool ) -> void:
    super( scene.instantiate() if scene != null else null, is_rendered, parent, is_portal )


# Nodes

class NodesDescriptor extends Descriptor:
  var _is_persistent: bool = false
  var _nodes: Array[ Node ] = EMPTY_NODE_ARRAY

  func _is_compatible( other: Descriptor ) -> bool:
    return other is NodesDescriptor && (
      other._is_persistent == self._is_persistent
    )

  func _make_element( parent: Element, is_portal: bool ) -> Element:
    assert( ! is_portal, 'Cannot have rea.nodes() directly in portals.' )
    return NodesElement.new( parent, is_portal )

  func _use_arg( arg: RenderArg ) -> void:
    super( arg )
    if arg.persistent:
      self._is_persistent = true

  # common
  func tap( tap: Callable ) -> NodesDescriptor: tap.call( self ); return self
  func arg( arg: RenderArg ) -> NodesDescriptor: _use_arg( arg ); return self
  func key( key: Variant ) -> NodesDescriptor: _key = key; return self
  func portals( portals: Array[ Descriptor ] ) -> NodesDescriptor: _portals = portals; return self
  # nodes
  func persistent( is_persistent: bool = true ) -> NodesDescriptor: _is_persistent = is_persistent; return self
  func nodes( nodes: Array[ Node ] ) -> NodesDescriptor: _nodes = nodes; return self


class NodesElement extends Element:
  func _descriptor_updated( descriptor: Descriptor ) -> void:
    var next_descriptor: NodesDescriptor = self.descriptor
    var prev_nodes := self.nodes
    var next_nodes := next_descriptor._nodes
    if next_nodes == prev_nodes: return
    self.nodes = next_descriptor._nodes
    if next_descriptor._is_persistent: return
    for node in prev_nodes: if ! next_nodes.has( node ): node.queue_free()

  func remove_nodes() -> void:
    var descriptor: NodesDescriptor = self.descriptor
    if descriptor._is_persistent: return
    for node in descriptor._nodes: node.queue_free()

  func _removed() -> void:
    remove_portals()
    remove_nodes()
    remove_descriptor()


# Callable

class CallableDescriptor extends RenderDescriptor:
  var _callable: Callable
  var _is_persistent: bool = false

  func _init( callable: Callable ) -> void:
    self._callable = callable

  func _is_compatible( other: Descriptor ) -> bool:
    return other is CallableDescriptor && (
      other._callable == self._callable
    )

  func _make_element( parent: Element, is_portal: bool ) -> Element:
    return CallableElement.new( parent, is_portal )

  func _to_arg() -> RenderArg:
    var arg := RenderArg.new()
    arg.ref = self._ref
    arg.persistent = self._is_persistent
    arg.data = self._data
    arg.props = self._props
    arg.signals = self._signals
    arg.children = null if self._is_hollow else FragmentDescriptor.new().key( CHILDREN_KEY ).children( self._children )
    arg.portals = null if ! self._portals.is_empty() else FragmentDescriptor.new().key( PORTALS_KEY ).portals( self._portals )
    return arg

  func _use_arg( arg: RenderArg ) -> void:
    super( arg )
    if arg.persistent:
      self._is_persistent = true

  # common
  func tap( tap: Callable ) -> CallableDescriptor: tap.call( self ); return self
  func arg( arg: RenderArg ) -> CallableDescriptor: _use_arg( arg ); return self
  func key( key: Variant ) -> CallableDescriptor: _key = key; return self
  func portals( portals: Array[ Descriptor ] ) -> CallableDescriptor: _portals = portals; return self
  # childed
  func children( children: Array[ Descriptor ] ) -> CallableDescriptor: _set_children( children ); return self
  func hollow( is_hollow: bool = true ) -> CallableDescriptor: _set_hollow( is_hollow ); return self
  # proped
  func props( props: Dictionary ) -> CallableDescriptor: _add_props( props ); return self
  func prop( key: StringName, value: Variant ) -> CallableDescriptor: _add_prop( key, value ); return self
  func propi( key: NodePath, value: Variant ) -> CallableDescriptor: _add_propi( key, value ); return self
  func binds( signals: Dictionary ) -> CallableDescriptor: _add_signals( signals ); return self
  func bind( key: StringName, callable: Callable ) -> CallableDescriptor: _add_signal( key, callable ); return self
  # render
  func ref( ref: Callable ) -> CallableDescriptor: _ref = ref; return self
  func data( data: Variant ) -> CallableDescriptor: _data = data; return self
  # callable
  func persistent( is_persistent: bool = true ) -> CallableDescriptor: _is_persistent = is_persistent; return self


class CallableElement extends RenderElement:
  func _init( parent: Element, is_portal: bool ) -> void:
    super( parent, is_portal )
    self.render = Render.new( self )

  func _descriptor_updated( descriptor: Descriptor ) -> void:
    var prev_outer_descriptor: CallableDescriptor = descriptor
    var next_outer_descriptor: CallableDescriptor = self.descriptor
    var render := self.render
    var render_arg := self.render_arg
    if render_arg == null || next_outer_descriptor != prev_outer_descriptor:
      render_arg = next_outer_descriptor._to_arg()
      self.render_arg = render_arg
    REA.start_render( render )
    var prev_inner_descriptor := render.output
    var next_inner_descriptor: Descriptor = next_outer_descriptor._callable.call( render_arg )
    REA.finish_render()
    if next_inner_descriptor == prev_inner_descriptor: return
    render.output = next_inner_descriptor
    if prev_inner_descriptor != null && next_inner_descriptor != null:
      if utils.is_equal( next_inner_descriptor._key, prev_inner_descriptor._key ) && next_inner_descriptor._is_compatible( prev_inner_descriptor ):
        var same_element := self.children.elements[ 0 ]
        same_element.update_descriptor( next_inner_descriptor )
        self.nodes = same_element.nodes
        return
    if prev_inner_descriptor != null:
      var prev_element := self.children.elements[ 0 ]
      prev_element._removed()
      self.children.elements = EMPTY_ELEMENT_ARRAY
      self.nodes = EMPTY_NODE_ARRAY
    if next_inner_descriptor != null:
      if self.children == null: self.children = Collection.new( self, self.is_portal )
      var next_element := next_inner_descriptor._make_element( self, self.is_portal )
      next_element.update_descriptor( next_inner_descriptor )
      self.children.elements = [ next_element ]
      self.nodes = next_element.nodes

  func _child_rerendered( child_index: int, prev_nodes: Array[ Node ], next_nodes: Array[ Node ] ) -> void:
    self.nodes = next_nodes
    if self.parent == null: return
    self.parent._child_rerendered( self.index, prev_nodes, next_nodes )


# Fragment

class FragmentDescriptor extends ChildedDescriptor:
  func _is_compatible( other: Descriptor ) -> bool:
    return other is FragmentDescriptor

  func _make_element( parent: Element, is_portal: bool ) -> Element:
    return FragmentElement.new( parent, is_portal )

  # common
  func tap( tap: Callable ) -> FragmentDescriptor: tap.call( self ); return self
  func arg( arg: RenderArg ) -> FragmentDescriptor: _use_arg( arg ); return self
  func key( key: Variant ) -> FragmentDescriptor: _key = key; return self
  func portals( portals: Array[ Descriptor ] ) -> FragmentDescriptor: _portals = portals; return self
  # childed
  func children( children: Array[ Descriptor ] ) -> FragmentDescriptor: _set_children( children ); return self
  func hollow( is_hollow: bool = true ) -> FragmentDescriptor: _set_hollow( is_hollow ); return self


class FragmentElement extends ChildedElement:
  var offsets: Array[ int ] = EMPTY_INT_ARRAY

  func _init( parent: Element, is_portal: bool ) -> void:
    super( parent, is_portal )
    if is_portal: self.children = Collection.new( self, true )

  func update_nodes( prev_descriptor: ChildedDescriptor, next_descriptor: ChildedDescriptor ) -> void:
    var prev_children := prev_descriptor._children if prev_descriptor != null else EMPTY_DESCRIPTOR_ARRAY
    var next_children := next_descriptor._children if next_descriptor != null else EMPTY_DESCRIPTOR_ARRAY
    if next_children == prev_children: return
    if self.children.elements.is_empty():
      self.nodes = EMPTY_NODE_ARRAY
      self.offsets = EMPTY_INT_ARRAY
      return
    var next_nodes := [] as Array[ Node ]
    var next_offsets := [] as Array[ int ]
    var offset: int = 0
    for child in self.children.elements:
      next_nodes.append_array( child.nodes )
      next_offsets.push_back( offset )
      offset += child.nodes.size()
    self.nodes = next_nodes
    self.offsets = next_offsets

  func _descriptor_updated( descriptor: Descriptor ) -> void:
    var prev_descriptor: ChildedDescriptor = descriptor
    var next_descriptor: ChildedDescriptor = self.descriptor
    update_children( prev_descriptor, next_descriptor )
    update_nodes( prev_descriptor, next_descriptor )
    update_portals( prev_descriptor, next_descriptor )

  func _child_rerendered( child_index: int, prev_child_nodes: Array[ Node ], next_child_nodes: Array[ Node ] ) -> void:
    var offsets := self.offsets
    var child_offset := offsets[ child_index ]
    var prev_nodes := self.nodes
    var next_nodes := [] as Array[ Node ]
    next_nodes.typed_assign(
      prev_nodes.slice( 0, child_offset ) +
      next_child_nodes +
      prev_nodes.slice( child_offset + prev_child_nodes.size() )
    )
    self.nodes = next_nodes
    var offset_delta := next_child_nodes.size() - prev_child_nodes.size()
    if offset_delta != 0:
      for index in range( child_index + 1, offsets.size() ):
        offsets[ index ] += offset_delta
    if self.parent != null:
      self.parent._child_rerendered( self.index, prev_nodes, next_nodes )


# Context

class ContextDescriptor extends ChildedDescriptor:
  var _context: GDScript
  var _value: Variant

  func _init( context: GDScript, value: Variant ) -> void:
    self._context = context
    self._value = value

  func _is_compatible( other: Descriptor ) -> bool:
    return other is ContextDescriptor && (
      other._context == self._context
    )

  func _make_element( parent: Element, is_portal: bool ) -> Element:
    return ContextElement.new( self._context, self._value, parent, is_portal )

  # common
  func tap( tap: Callable ) -> ContextDescriptor: tap.call( self ); return self
  func arg( arg: RenderArg ) -> ContextDescriptor: _use_arg( arg ); return self
  func key( key: Variant ) -> ContextDescriptor: _key = key; return self
  func portals( portals: Array[ Descriptor ] ) -> ContextDescriptor: _portals = portals; return self
  # childed
  func children( children: Array[ Descriptor ] ) -> ContextDescriptor: _set_children( children ); return self
  func hollow( is_hollow: bool = true ) -> ContextDescriptor: _set_hollow( is_hollow ); return self


class ContextElement extends FragmentElement:
  var context_fallback: Variant
  var context_value: Variant
  var context_users: Array[ Render ] = []

  func _init( context: GDScript, value: Variant, parent: Element, is_portal: bool ) -> void:
    super( parent, is_portal )
    var contexts := self.contexts.duplicate()
    contexts[ context ] = self
    self.contexts = contexts
    self.context_fallback = context.get_fallback()
    self.context_value = value if ! utils.is_ignore( value ) else self.context_fallback

  func _descriptor_updated( descriptor: Descriptor ) -> void:
    var next_descriptor: ContextDescriptor = self.descriptor
    var prev_value: Variant = self.context_value
    var next_value: Variant = next_descriptor._value if ! utils.is_ignore( next_descriptor._value ) else self.context_fallback
    self.context_value = next_value
    if utils.is_equal( next_value, prev_value ) || self.context_users.is_empty(): super( descriptor ); return
    var rerender_binds := [] as Array[ Callable ]
    for context_user in self.context_users:
      rerender_binds.push_back( context_user.rerender.bind( context_user.counter ) )
    super( descriptor )
    for rerender_bind in rerender_binds:
      rerender_bind.call()

  func _removed() -> void:
    super()
    self.context_fallback = null
    self.context_value = null
    self.context_users.clear()
